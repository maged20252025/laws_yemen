plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "com.example.laws_yemen"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    // تحميل ملف key.properties
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        println("✅ Loaded keystore properties from: ${keystorePropertiesFile.absolutePath}")
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    } else {
        println("❌ key.properties not found at: ${keystorePropertiesFile.absolutePath}")
    }

    defaultConfig {
        applicationId = "com.example.laws_yemen"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyAliasValue = keystoreProperties["keyAlias"] as String?
            val keyPasswordValue = keystoreProperties["keyPassword"] as String?
            val storeFilePath = keystoreProperties["storeFile"] as String?
            val storePasswordValue = keystoreProperties["storePassword"] as String?

            if (storeFilePath != null && storeFilePath.isNotEmpty()) {
                val absolutePath = rootProject.file(storeFilePath)
                if (absolutePath.exists()) {
                    storeFile = absolutePath
                    println("✅ Using keystore file: ${absolutePath.absolutePath}")
                } else {
                    println("❌ Keystore file not found at: ${absolutePath.absolutePath}")
                }
            } else {
                println("❌ storeFile path missing from key.properties")
            }

            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
            storePassword = storePasswordValue
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // تحديث مكتبة desugar إلى الإصدار الجديد
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
