import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Llave propia para firmar la APK de las tablets. Los datos están en
// android/key.properties, que NUNCA se sube a GitHub (ver .gitignore).
// Si el archivo no existe, se firma con la llave de depuración como antes,
// para no bloquear a quien compile sin la llave.
val llaveProps = Properties()
val archivoLlave = rootProject.file("key.properties")
val hayLlave = archivoLlave.exists()
if (hayLlave) {
    llaveProps.load(FileInputStream(archivoLlave))
}

android {
    namespace = "com.example.apolo_udes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.apolo_udes"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayLlave) {
            create("release") {
                keyAlias = llaveProps["keyAlias"] as String
                keyPassword = llaveProps["keyPassword"] as String
                storeFile = file(llaveProps["storeFile"] as String)
                storePassword = llaveProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hayLlave) {
                signingConfigs.getByName("release")
            } else {
                println("AVISO: no hay android/key.properties; la APK se firma con la llave de depuración.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
