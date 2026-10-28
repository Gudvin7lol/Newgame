plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Stable release identity is supplied only by secure CI environment variables.
// Without it, development APKs remain explicitly DEBUG-key signed.
val zamerKeystoreFile = System.getenv("ZAMER_RELEASE_KEYSTORE_FILE")
val zamerKeystorePassword = System.getenv("ZAMER_RELEASE_STORE_PASSWORD")
val zamerKeyAlias = System.getenv("ZAMER_RELEASE_KEY_ALIAS")
val zamerKeyPassword = System.getenv("ZAMER_RELEASE_KEY_PASSWORD")
val stableSigning = listOf(
    zamerKeystoreFile, zamerKeystorePassword, zamerKeyAlias, zamerKeyPassword
).all { !it.isNullOrBlank() }

android {
    signingConfigs {
        if (stableSigning) {
            create("zamerStableRelease") {
                storeFile = file(zamerKeystoreFile!!)
                storePassword = zamerKeystorePassword
                keyAlias = zamerKeyAlias
                keyPassword = zamerKeyPassword
            }
        }
    }
    namespace = "ru.zamer.zamer_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ru.zamer.zamer_app"
        // Non-stable CI APKs run beside the installed user app.
        manifestPlaceholders["zamerAppLabel"] =
            if (stableSigning) "Замер" else "Замер • тест"
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

    buildTypes {
        release {
            if (!stableSigning) {
                // Keep the main app/data untouched when the runner debug
                // key changes between CI builds.
                applicationIdSuffix = ".preview"
            }
            // Stable signed APKs support in-place updates when versionCode
            // increases and the same signing key is kept. Ephemeral runner
            // debug signing is fallback ONLY for installation tests.
            signingConfig = if (stableSigning) {
                signingConfigs.getByName("zamerStableRelease")
            } else {
                signingConfigs.getByName("debug")
            }
            // Alpha builds prioritize reliable on-device verification over APK size.
            isMinifyEnabled = false
            isShrinkResources = false
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
