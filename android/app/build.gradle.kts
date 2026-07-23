plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // The release build signs with the debug key (see buildTypes below), so the
    // debug keystore decides whether testers can install over their existing
    // app. Gradle normally picks it up from the machine's own ~/.android, which
    // on a CI runner means a freshly generated key and a signature testers'
    // devices reject. Pointing at an explicit keystore keeps CI builds signed
    // with the same key as local ones. Unset locally, so nothing changes there.
    val debugKeystoreOverride: String? = System.getenv("FORDITVA_DEBUG_KEYSTORE")

    // Google Play rejects debug-signed uploads, so the Play build (the .aab)
    // signs with a dedicated upload key instead. When these env vars are unset
    // (every local build and the sideload-APK CI job) release keeps signing
    // with the debug key, so nothing about tester APKs changes.
    val uploadKeystore: String? = System.getenv("FORDITVA_UPLOAD_KEYSTORE")

    signingConfigs {
        getByName("debug") {
            if (debugKeystoreOverride != null) {
                storeFile = file(debugKeystoreOverride)
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
        create("upload") {
            if (uploadKeystore != null) {
                storeFile = file(uploadKeystore)
                storePassword = System.getenv("FORDITVA_UPLOAD_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("FORDITVA_UPLOAD_KEY_ALIAS")
                keyPassword = System.getenv("FORDITVA_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    namespace = "com.example.forditva"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Public Play Store identity, permanent once published. Google rejects
        // com.example.* (Markus/Kayode chose hu.wirinungarn.forditva, 2026-07-23).
        // The internal `namespace` below stays as the original code package.
        applicationId = "hu.wirinungarn.forditva"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use the upload key when it is provided (the Play .aab build),
            // otherwise the debug key so sideload APKs and `flutter run
            // --release` keep working unchanged.
            signingConfig =
                if (uploadKeystore != null) signingConfigs.getByName("upload")
                else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
