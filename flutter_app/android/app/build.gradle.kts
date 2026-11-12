import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// CI may compile without the private key. Distributable releases must use the
// permanent certificate; there is deliberately no debug-signing fallback.
val unsignedRelease = providers.gradleProperty("flexUnsignedRelease")
    .map { it.toBooleanStrict() }.getOrElse(false)
val signingFile = if (unsignedRelease) null else providers
    .environmentVariable("FLEX_SIGNING_PROPERTIES").orNull?.let { file(it) }
val releaseRequested = gradle.startParameter.taskNames.any {
    val name = it.substringAfterLast(':').lowercase()
    name.contains("release") || name in setOf("build", "assemble", "bundle")
}
if (releaseRequested && !unsignedRelease && signingFile == null) {
    throw GradleException(
        "FLEX release signing requires FLEX_SIGNING_PROPERTIES. " +
            "Use -PflexUnsignedRelease=true only for a non-installable CI build."
    )
}
val releaseSigning = signingFile?.let { config ->
    require(config.isFile) { "FLEX signing configuration not found." }
    Properties().apply { config.inputStream().use { load(it) } }
}
fun signingValue(name: String): String = releaseSigning?.getProperty(name)
    ?.takeIf { it.isNotBlank() }
    ?: throw GradleException("FLEX signing configuration is missing $name.")
val releaseStore: File? = signingFile?.let { config ->
    val path = File(signingValue("storeFile"))
    val store = if (path.isAbsolute) path else config.parentFile.resolve(path.path)
    require(store.isFile) { "FLEX release keystore not found." }
    val keyStore = KeyStore.getInstance(store, signingValue("storePassword").toCharArray())
    val alias = signingValue("keyAlias")
    require(keyStore.isKeyEntry(alias)) { "FLEX signing alias is not a private key." }
    val certificate = keyStore.getCertificate(alias)
    val digest = MessageDigest.getInstance("SHA-256").digest(certificate.encoded)
        .joinToString("") { "%02x".format(it) }
    val expected = rootProject.file("release-certificate.sha256").readText().trim()
    require(digest == expected) { "FLEX release keystore does not match the permanent certificate." }
    store
}

android {
    namespace = "at.flowzym.flex_notizbuch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Separate from the old FLEX Test app, which keeps its existing data.
        applicationId = "at.flowzym.flex_notizbuch"
        manifestPlaceholders["flexAppLabel"] = "FLEX"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStore != null) {
            create("permanentRelease") {
                storeFile = releaseStore
                storePassword = signingValue("storePassword")
                keyAlias = signingValue("keyAlias")
                keyPassword = signingValue("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
            manifestPlaceholders["flexAppLabel"] = "FLEX Dev"
        }
        release {
            signingConfig = if (releaseStore == null) null else signingConfigs.getByName("permanentRelease")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.1")
}

flutter {
    source = "../.."
}
