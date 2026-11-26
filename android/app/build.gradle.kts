import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadPropertiesFile = rootProject.file("key.properties")
val uploadProperties = Properties()
if (uploadPropertiesFile.exists()) {
    uploadPropertiesFile.inputStream().use { uploadProperties.load(it) }
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach {
        require(!uploadProperties.getProperty(it).isNullOrBlank()) {
            "android/key.properties is missing $it"
        }
    }
}

android {
    namespace = "com.ebranurozbalik.iz"
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
        applicationId = "com.ebranurozbalik.iz"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (uploadPropertiesFile.exists()) {
            create("upload") {
                storeFile = rootProject.file(uploadProperties.getProperty("storeFile"))
                storePassword = uploadProperties.getProperty("storePassword")
                keyAlias = uploadProperties.getProperty("keyAlias")
                keyPassword = uploadProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without an upload key this creates an unsigned validation build.
            // tool/build_play_release.py requires real signing before distribution.
            signingConfig = signingConfigs.findByName("upload")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

androidComponents {
    onVariants(selector().withBuildType("debug")) { variant ->
        // Preserve the existing development installation and its journal.
        variant.applicationId.set("com.example.iz")
    }
}

flutter {
    source = "../.."
}
