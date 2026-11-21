package at.flowzym.flex_device

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import com.microsoft.identity.client.*
import com.microsoft.identity.client.exception.MsalException
import com.microsoft.identity.client.exception.MsalUiRequiredException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/** MSAL owns tokens; only a short-lived access token crosses the channel.
 * No credentials, server responses or account identifiers are logged.
 */
internal class OneDriveAuthentication(
    private val context: Context,
    private val activity: () -> Activity?,
) {
    companion object {
        val methods = setOf("msalAccount", "msalSignIn", "msalToken", "msalSignOut")
        private val queue = OneDriveAuthQueue()
        private var application: ISingleAccountPublicClientApplication? = null
        private val scopes = listOf("https://graph.microsoft.com/Files.Read")
        private const val signature = "O/s4RU8YApv43yNF9HMVr8OKo80="
    }

    private val main = Handler(Looper.getMainLooper())
    private var attached = true

    fun close() { attached = false }

    fun perform(call: MethodCall, result: MethodChannel.Result) {
        queue.submit { done ->
            val reply = Reply(result, done)
            if (!attached && call.method != "msalSignOut") {
                reply.error("msal_cancelled")
            } else if (!registeredBuild()) {
                reply.error("msal_configuration")
            } else {
                try {
                    val current = application
                    if (current != null) run(current, call, reply)
                    else {
                        Logger.getInstance().setEnablePII(false)
                        Logger.getInstance().setEnableLogcatLog(false)
                        PublicClientApplication.createSingleAccountPublicClientApplication(
                            context,
                            R.raw.flex_msal_config,
                            object : IPublicClientApplication.ISingleAccountApplicationCreatedListener {
                                override fun onCreated(app: ISingleAccountPublicClientApplication) {
                                    main.post {
                                        application = app
                                        if (attached || call.method == "msalSignOut") run(app, call, reply)
                                        else reply.error("msal_cancelled")
                                    }
                                }
                                override fun onError(error: MsalException) = reply.failure(error)
                            },
                        )
                    }
                } catch (_: Exception) {
                    reply.error("msal_configuration")
                }
            }
        }
    }

    private fun run(app: ISingleAccountPublicClientApplication, call: MethodCall, reply: Reply) {
        val requestedScopes = if (call.argument<Boolean>("appFolder") == true) {
            scopes + "https://graph.microsoft.com/Files.ReadWrite.AppFolder"
        } else scopes
        try {
            app.getCurrentAccountAsync(object : ISingleAccountPublicClientApplication.CurrentAccountCallback {
                override fun onAccountChanged(prior: IAccount?, current: IAccount?) = Unit
                override fun onError(error: MsalException) = reply.failure(error)
                override fun onAccountLoaded(account: IAccount?) {
                    main.post {
                        try {
                            if (!attached && call.method != "msalSignOut") {
                                reply.error("msal_cancelled")
                                return@post
                            }
                            when (call.method) {
                                "msalAccount" -> reply.success(account?.let(::metadata))
                                "msalSignOut" -> {
                                    if (account == null) reply.success(null)
                                    else app.signOut(object : ISingleAccountPublicClientApplication.SignOutCallback {
                                        override fun onSignOut() = reply.success(null)
                                        override fun onError(error: MsalException) = reply.failure(error)
                                    })
                                }
                                "msalSignIn" -> signIn(app, account, reply, requestedScopes)
                                "msalToken" -> {
                                    if (account == null || account.id != call.argument<String>("accountId")) {
                                        reply.error("msal_account_changed")
                                        return@post
                                    }
                                    app.acquireTokenSilentAsync(
                                        AcquireTokenSilentParameters.Builder()
                                            .withScopes(requestedScopes)
                                            .forAccount(account)
                                            .fromAuthority(account.authority)
                                            .forceRefresh(call.argument<Boolean>("forceRefresh") == true)
                                            .withCallback(object : SilentAuthenticationCallback {
                                                override fun onSuccess(value: IAuthenticationResult) {
                                                    if (value.account.id != account.id) reply.error("msal_account_changed")
                                                    else reply.success(value.accessToken)
                                                }
                                                override fun onError(error: MsalException) = reply.failure(error)
                                            }).build(),
                                    )
                                }
                            }
                        } catch (_: Exception) {
                            reply.error("msal_unavailable")
                        }
                    }
                }
            })
        } catch (_: Exception) {
            reply.error("msal_unavailable")
        }
    }

    private fun signIn(app: ISingleAccountPublicClientApplication, account: IAccount?, reply: Reply, requestedScopes: List<String>) {
        val host = activity()
        if (host == null || host.isFinishing || host.isDestroyed) {
            reply.error("msal_no_activity")
            return
        }
        val parameters = SignInParameters.builder()
            .withActivity(host)
            .withScopes(requestedScopes)
            .withCallback(object : AuthenticationCallback {
                override fun onCancel() = reply.success(null)
                override fun onError(error: MsalException) = reply.failure(error)
                override fun onSuccess(value: IAuthenticationResult) {
                    main.post {
                        if (attached) reply.success(metadata(value.account))
                        else {
                            // A disposed Flutter engine cannot accept a new login.
                            // Finish cache cleanup before any later queued request.
                            try {
                                app.signOut(object : ISingleAccountPublicClientApplication.SignOutCallback {
                                    override fun onSignOut() = reply.error("msal_cancelled")
                                    override fun onError(error: MsalException) = reply.failure(error)
                                })
                            } catch (_: Exception) {
                                reply.error("msal_unavailable")
                            }
                        }
                    }
                }
            }).build()
        if (account == null) app.signIn(parameters) else app.signInAgain(parameters)
    }

    private fun metadata(account: IAccount) = mapOf(
        "id" to account.id,
        "username" to account.username,
    )

    @Suppress("DEPRECATION")
    private fun registeredBuild(): Boolean = try {
        val packageName = context.packageName
        if (packageName != "at.flowzym.flex_notizbuch") false
        else {
            val manager = context.packageManager
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                manager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                    .signingInfo?.apkContentsSigners.orEmpty()
            } else manager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures.orEmpty()
            signatures.any {
                Base64.encodeToString(MessageDigest.getInstance("SHA-1").digest(it.toByteArray()), Base64.NO_WRAP) == signature
            }
        }
    } catch (_: Exception) { false }

    private inner class Reply(private val result: MethodChannel.Result, private val done: () -> Unit) {
        private var finished = false
        private fun finish(block: () -> Unit) {
            main.post {
                if (!finished) {
                    finished = true
                    try { if (attached) block() } finally { done() }
                }
            }
        }
        fun success(value: Any?) = finish { result.success(value) }
        fun error(code: String) = finish { result.error(code, null, null) }
        fun failure(error: MsalException) = error(
            when {
                error is MsalUiRequiredException -> "msal_interaction_required"
                error.errorCode in setOf("no_network_connection_power_optimization", "device_network_not_available", "io_error") -> "msal_network"
                error.errorCode in setOf("invalid_client", "invalid_redirect_uri", "redirect_uri_validation_error") -> "msal_configuration"
                error.errorCode == "access_denied" -> "msal_denied"
                else -> "msal_unavailable"
            },
        )
    }
}
