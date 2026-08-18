plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ridelink_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Ito ang pagkakakilanlan ng app sa device. Pinalitan na ito ng
        // tunay na ID habang wala pang naipapamigay — kapag binago ito
        // matapos may mga naka-install, kailangang mag-uninstall muna ang
        // bawat user bago makapag-update.
        //
        // Sinadyang hindi ginalaw ang `namespace` sa itaas: doon naka-
        // resolve ang `.MainActivity` sa AndroidManifest, at nasa
        // com/example/ridelink_mobile/ pa rin ang Kotlin source.
        applicationId = "com.ridelink.app"
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
            // Debug key muna — pang-test lang sa mga kaibigan, hindi
            // pang-Play Store. Kapag lumipat tayo sa tunay na keystore,
            // kailangang mag-uninstall muna ang lahat bago mag-install
            // ulit: hindi tumatanggap ang Android ng update na iba ang
            // pirma. Mura lang ito ngayon dahil walang sinasave na data
            // ang app — walang mawawala sa uninstall.
            signingConfig = signingConfigs.getByName("debug")
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
