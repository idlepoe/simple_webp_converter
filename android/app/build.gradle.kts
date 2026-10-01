plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val environmentKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val useEnvironmentSigning = !environmentKeystorePath.isNullOrBlank()
val hasReleaseSigning = useEnvironmentSigning || keystorePropertiesFile.exists()
if (System.getenv("REQUIRE_RELEASE_SIGNING") == "true" && !hasReleaseSigning) {
    error("Release signing is required. Configure Android signing secrets.")
}
fun signingValue(environmentName: String, propertyName: String): String =
    (if (useEnvironmentSigning) System.getenv(environmentName) else keystoreProperties.getProperty(propertyName))
        ?.takeIf { it.isNotBlank() }
        ?: error("Missing release signing value: $propertyName")

android {
    namespace = "com.jylee.simple_webp_converter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jylee.simple_webp_converter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias")
                keyPassword = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")
                storeFile = file(signingValue("ANDROID_KEYSTORE_PATH", "storeFile"))
                storePassword = signingValue("ANDROID_STORE_PASSWORD", "storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Keep local release builds installable when no private release key is configured.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = false
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
