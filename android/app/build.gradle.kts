import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.gecko.komodo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.gecko.komodo"
        // dynamic_app_icon_flutter_plus requires minSdk 24+
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile =
                (keystoreProperties["storeFile"] as String?)?.let { path ->
                    rootProject.file(path)
                }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Flutter copies the release APK to outputs/flutter-apk/app-release.apk.
// After that, also publish a dated artifact: komodo-yyyyMMdd-HHmmss.apk
afterEvaluate {
    tasks.named("assembleRelease").configure {
        doLast {
            val apkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
            val source = apkDir.resolve("app-release.apk")
            if (!source.exists()) {
                return@doLast
            }

            val timestamp =
                SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
            val datedName = "komodo-$timestamp.apk"

            apkDir.listFiles()
                ?.filter { file ->
                    file.name.startsWith("komodo-") &&
                        (file.name.endsWith(".apk") || file.name.endsWith(".apk.sha1"))
                }
                ?.forEach { it.delete() }

            val destination = apkDir.resolve(datedName)
            source.copyTo(destination, overwrite = true)

            val sourceSha1 = apkDir.resolve("app-release.apk.sha1")
            if (sourceSha1.exists()) {
                sourceSha1.copyTo(apkDir.resolve("$datedName.sha1"), overwrite = true)
            }

            logger.lifecycle("Release APK also available at: ${destination.path}")
        }
    }
}
