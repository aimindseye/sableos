plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.sableos.system.preview"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.sableos.system.preview"
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

    lint {
        // This preview module has no test sources. Production preview sources
        // remain linted; test-source lint remains disabled.
        checkTestSources = false
    }
}

androidComponents {
    beforeVariants(selector().all()) { variantBuilder ->
        // system-preview has no instrumentation-test sources. Disable creation
        // of the unused AndroidTest variant so lint cannot resolve an unrelated
        // debugAndroidTest dependency graph.
        variantBuilder.enableAndroidTest = false
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
    implementation("androidx.compose.material3:material3")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
