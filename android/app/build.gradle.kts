import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        try {
            load(FileInputStream(localPropertiesFile))
        } catch (e: Exception) {
            println("Warning: Failed to load local.properties file: ${e.message}")
        }
    }
}

android {
    namespace = "com.kugorang.cherryrecorder"
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
        applicationId = "com.kugorang.cherryrecorder"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 매니페스트 플레이스홀더 설정은 Flavor 블록으로 이동
        // manifestPlaceholders["mapsApiKey"] = mapsApiKey 
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Flavor Dimension 추가
    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev" 
            resValue("string", "app_name", "체리 레코더 Dev")
            // Dev Flavor용 API 키 설정 (local.properties 사용)
            val devApiKey = localProperties.getProperty("maps.apiKey.dev") ?: run {
                println("\nWARNING: maps.apiKey.dev not found in local.properties.")
                "YOUR_DEV_KEY_PLACEHOLDER" // 대체 값
            }
            manifestPlaceholders["mapsApiKey"] = devApiKey
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "체리 레코더")
            // Prod Flavor용 API 키 설정 (local.properties 사용)
             val prodApiKey = localProperties.getProperty("maps.apiKey.prod") ?: run {
                println("\nWARNING: maps.apiKey.prod not found in local.properties.")
                "YOUR_PROD_KEY_PLACEHOLDER" // 대체 값
            }
            manifestPlaceholders["mapsApiKey"] = prodApiKey
        }
    }
}

flutter {
    source = "../.."
}