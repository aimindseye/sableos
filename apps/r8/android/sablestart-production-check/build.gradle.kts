plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.sableos.start"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.sableos.start.cicheck"
        minSdk = 30
        targetSdk = 36
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
            manifest.srcFile(
                "../../../../src/android/packages/apps/SableStart/AndroidManifest.xml"
            )
            java.srcDirs(
                "../../../../src/android/packages/apps/SableStart/src"
            )
            res.srcDirs(
                "../../../../src/android/packages/apps/SableStart/res"
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
    implementation("androidx.compose.runtime:runtime")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
