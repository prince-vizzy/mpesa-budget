plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mpesa_tracker"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.example.mpesa_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // 🔴 REQUIRED
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        // 🔴 Force Kotlin to Java 17
        jvmToolchain(17)
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // 🔴 REQUIRED
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Provides the Theme.AppCompat parent the launch theme needs for local_auth.
    implementation("androidx.appcompat:appcompat:1.7.0")
}

flutter {
    source = "../.."
}
