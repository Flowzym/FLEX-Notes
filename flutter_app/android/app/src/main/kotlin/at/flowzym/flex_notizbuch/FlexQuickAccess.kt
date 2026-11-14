package at.flowzym.flex_notizbuch

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Stores navigation only; no pupil, document or authentication data. */
class FlexQuickAccess(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "at.flowzym.flex_notizbuch/quick_access")
    private val preferences = context.getSharedPreferences("quick_access", Context.MODE_PRIVATE)

    init {
        channel.setMethodCallHandler { call, reply ->
            when (call.method) {
                "take" -> {
                    val target = preferences.getString("target", null)
                    preferences.edit().remove("target").commit()
                    reply.success(target?.takeIf { it in targets })
                }
                "pinWidget" -> {
                    val manager = AppWidgetManager.getInstance(context)
                    val supported =
                        Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported
                    reply.success(
                        supported &&
                            manager.requestPinAppWidget(
                                ComponentName(context, FlexWidget::class.java),
                                null,
                                null,
                            )
                    )
                }
                else -> reply.notImplemented()
            }
        }
    }

    fun accept(intent: Intent?) {
        if (intent?.action != ACTION) return
        val target = intent.getStringExtra("target")
        intent.removeExtra("target")
        intent.action = Intent.ACTION_MAIN
        if (target !in targets) return
        preferences.edit().putString("target", target).commit()
        channel.invokeMethod("changed", null)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val ACTION = "at.flowzym.flex_notizbuch.QUICK_ACCESS"
        val targets = setOf("notes", "calendar", "scan", "homework")
    }
}

class FlexWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.flex_widget)
            val actions =
                listOf(
                    R.id.quick_notes to "notes",
                    R.id.quick_calendar to "calendar",
                    R.id.quick_scan to "scan",
                    R.id.quick_homework to "homework",
                )
            for ((index, action) in actions.withIndex()) {
                val intent =
                    Intent(context, MainActivity::class.java).apply {
                        this.action = FlexQuickAccess.ACTION
                        putExtra("target", action.second)
                        flags =
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                views.setOnClickPendingIntent(
                    action.first,
                    PendingIntent.getActivity(
                        context,
                        index,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            manager.updateAppWidget(id, views)
        }
    }
}
