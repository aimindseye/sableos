plugins {
    id("com.android.application") version "8.13.2" apply false
    id("com.android.library") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.3.10" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.10" apply false
}

val rustRoot = layout.projectDirectory.dir("../rust")
val rustTargetTriple = "aarch64-linux-android"
val rustNdkVersion = "30.0.16248370"
val rustAndroidApi = 30
val rustTargetDir = layout.buildDirectory.dir("rust-jni-target")

val cargoExecutable = providers.environmentVariable("CARGO")
    .orElse(
        providers.environmentVariable("CARGO_HOME")
            .map { "$it/bin/cargo" }
    )
    .orElse("cargo")

val androidSdkRoot = providers.environmentVariable("ANDROID_SDK_ROOT")
    .orElse(providers.environmentVariable("ANDROID_HOME"))

val buildRustJniArm64 = tasks.register<Exec>("buildRustJniArm64") {
    group = "build"
    description = "Build Sable R8 JNI libraries for Android arm64-v8a"

    workingDir(rustRoot.asFile)

    inputs.files(
        fileTree(rustRoot.asFile) {
            include("Cargo.toml")
            include("Cargo.lock")
            include("crates/**/*.toml")
            include("crates/**/*.rs")
        }
    )

    listOf(
        "libsable_calculator_jni.so",
        "libsable_convert_jni.so",
        "libsable_games_jni.so",
    ).forEach { library ->
        outputs.file(
            rustTargetDir.map {
                it.file("$rustTargetTriple/release/$library")
            }
        )
    }

    doFirst {
        val sdkRoot = androidSdkRoot.orNull
            ?: throw GradleException(
                "ANDROID_SDK_ROOT or ANDROID_HOME must be set"
            )

        val linker = file(
            "$sdkRoot/ndk/$rustNdkVersion/" +
                "toolchains/llvm/prebuilt/linux-x86_64/bin/" +
                "aarch64-linux-android${rustAndroidApi}-clang"
        )

        if (!linker.canExecute()) {
            throw GradleException(
                "Pinned Android NDK linker is unavailable: $linker"
            )
        }

        environment(
            "CARGO_TARGET_DIR",
            rustTargetDir.get().asFile.absolutePath,
        )

        environment(
            "CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER",
            linker.absolutePath,
        )

        executable = cargoExecutable.get()

        args(
            "build",
            "--locked",
            "--release",
            "--target",
            rustTargetTriple,
            "-p",
            "sable-calculator-jni",
            "-p",
            "sable-convert-jni",
            "-p",
            "sable-games-jni",
        )
    }
}

fun registerRustJniStage(
    taskName: String,
    projectPath: String,
    libraryName: String,
) {
    tasks.register<Copy>(taskName) {
        group = "build"
        description = "Stage $libraryName for $projectPath"

        dependsOn(buildRustJniArm64)

        from(
            rustTargetDir.map {
                it.file("$rustTargetTriple/release/$libraryName")
            }
        )

        into(
            project(projectPath)
                .layout
                .buildDirectory
                .dir("generated/rustJni/arm64-v8a")
        )
    }
}

registerRustJniStage(
    "stageCalculatorRustJni",
    ":calculator",
    "libsable_calculator_jni.so",
)

registerRustJniStage(
    "stageConvertRustJni",
    ":convert",
    "libsable_convert_jni.so",
)

registerRustJniStage(
    "stageGamesRustJni",
    ":games",
    "libsable_games_jni.so",
)
