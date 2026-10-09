plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.kreen.kreen_judge_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.kreen.kreen_judge_mobile"
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
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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

// Named copies of every APK / App Bundle build: "KREEN Judge v<versionName>.apk"
// (+ " (<abi>)" for --split-per-abi, " debug"/" profile" for non-release).
// Flutter's own app-*.apk / app-*.aab stay untouched — the flutter tool looks
// for those names. APKs land next to Flutter's in build/app/outputs/flutter-apk/,
// bundles next to app-release.aab in build/app/outputs/bundle/release/.
afterEvaluate {
    val appName = "KREEN Judge v${android.defaultConfig.versionName ?: "0.0.0"}"
    val outputs = layout.buildDirectory.get().dir("outputs").asFile
    for (type in listOf("debug", "profile", "release")) {
        val task = type.replaceFirstChar { it.uppercase() }
        val suffix = if (type == "release") "" else " $type"
        tasks.findByName("assemble$task")?.doLast {
            val target = File(outputs, "flutter-apk").apply { mkdirs() }
            File(outputs, "apk/$type").listFiles { f -> f.extension == "apk" }?.forEach { apk ->
                val abi = apk.nameWithoutExtension.removePrefix("app-").removeSuffix(type).removeSuffix("-")
                val name = "$appName$suffix${if (abi.isEmpty()) "" else " ($abi)"}.apk"
                apk.copyTo(File(target, name), overwrite = true)
                println("✓ Built ${File(target, name)}")
            }
        }
        tasks.findByName("bundle$task")?.doLast {
            File(outputs, "bundle/$type").listFiles { f -> f.extension == "aab" }?.forEach { aab ->
                val named = File(aab.parentFile, "$appName$suffix.aab")
                aab.copyTo(named, overwrite = true)
                println("✓ Built $named")
            }
        }
    }
}
