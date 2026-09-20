plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.sableos.start.presentationcheck"
    compileSdk = 36

    defaultConfig {
        minSdk = 30
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
                "../../../../src/android/packages/apps/SableStart/src"
            )
        }
    }
}

dependencies {
    implementation(project(":design"))

    implementation(
        platform("androidx.compose:compose-bom:2026.02.01")
    )

    implementation("androidx.compose.runtime:runtime")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
