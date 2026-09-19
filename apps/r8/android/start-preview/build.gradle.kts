plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.sableos.start.preview"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.sableos.start.preview"
        minSdk = 30
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            )
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDirs(
                "src/main/java",
                "../../../../src/android/packages/apps/SableStart/src/com/sable/start/ui",
                "../../../../src/android/packages/apps/SableStart/src/com/sable/start/live",
                "../../../../src/android/packages/apps/SableStart/src/com/sable/start/model",
                "../../../../src/android/packages/apps/SableStart/src/com/sable/start/platform",
            )
        }
    }
}

dependencies {
    implementation(project(":design"))

    implementation(
        platform("androidx.compose:compose-bom:2026.02.01")
    )

    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.material3:material3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
