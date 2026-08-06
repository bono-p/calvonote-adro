plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after Android & Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bono.calvonote"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.bono.calvonote"
        minSdk = 23          // Required by record & permission_handler
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Pour simplifier la première compilation Codemagic,
            // on utilise la debug signing config pour la release.
            // Pour une publication Google Play, remplacez par un keystore dédié.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
