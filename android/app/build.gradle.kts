import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (local) or the BOXPILOT_KEYSTORE_* environment
// variables (CI). Without either, release builds use the debug key.
val keyProperties = Properties().apply {
    rootProject.file("key.properties").takeIf { it.isFile }?.inputStream()?.use { load(it) }
}
fun signingValue(name: String, env: String): String? =
    keyProperties.getProperty(name) ?: System.getenv(env)

android {
    namespace = "io.github.billblueinnit.boxpilot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "io.github.billblueinnit.boxpilot"
        // Android 10: DnsResolver and connection-owner lookups for the VPN.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        val storeFile = signingValue("storeFile", "BOXPILOT_KEYSTORE_FILE")
        if (storeFile != null) {
            create("release") {
                this.storeFile = file(storeFile)
                storePassword = signingValue("storePassword", "BOXPILOT_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "BOXPILOT_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "BOXPILOT_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        jniLibs {
            // libbox and the Rust bridge are loaded straight from the APK.
            useLegacyPackaging = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // sing-box, built by scripts/build_libbox.sh.
    implementation(files("libs/libbox.aar"))
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}

flutter {
    source = "../.."
}
