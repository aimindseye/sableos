#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT/build/config/r8-release.env"
source "$ROOT/build/config/r8-host-tools.env"

SOURCE_MUTATION_AUTHORIZED="${SOURCE_MUTATION_AUTHORIZED:-NO}"
BUILD_AUTHORIZED="${BUILD_AUTHORIZED:-NO}"
EXPECTED_SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-}"
SABLE_QUALIFICATION_ONLY="${SABLE_QUALIFICATION_ONLY:-NO}"

case "$SABLE_QUALIFICATION_ONLY" in
    YES|NO) ;;
    *)
        echo "R8_RELEASE_CANDIDATE=FAIL_QUALIFICATION_MODE value=$SABLE_QUALIFICATION_ONLY"
        exit 4
        ;;
esac

if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "R8_RELEASE_CANDIDATE=REFUSED_SOURCE_MUTATION_NOT_AUTHORIZED"
    exit 2
fi
if [[ "$BUILD_AUTHORIZED" != YES ]]; then
    echo "R8_RELEASE_CANDIDATE=REFUSED_BUILD_NOT_AUTHORIZED"
    exit 3
fi
if [[ ! "$EXPECTED_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    echo "R8_RELEASE_CANDIDATE=FAIL_EXPECTED_SOURCE_COMMIT"
    exit 4
fi

REPO="$SABLEOS_REPO"
WS="$SABLEOS_UPSTREAM"
STAMP="$(date +%Y%m%d_%H%M%S)"
EVIDENCE="$SABLE_R8_EVIDENCE_ROOT/$STAMP"
BUNDLE="$SABLE_R8_ARTIFACT_ROOT/$STAMP"
WORK="$SABLE_R8_APP_WORK_ROOT/$STAMP"
if [[ "$SABLE_QUALIFICATION_ONLY" == YES ]]; then
    # Module-only WS7 qualification must reuse the canonical warmed Panther
    # graph. A fresh source-specific OUT turns a focused Launcher/SystemUI/
    # Settings compile into a cold framework/API-stub rebuild.
    R9_FULL_OUT_DIR="${SABLE_R9_QUAL_OUT_DIR:-$SABLE_R8_OUT_DIR}"
    BUILD_REQUIRE_FRESH_OUT=NO
else
    # Full release-candidate builds keep the source-bound fresh-output
    # causality rule used for WS8 / physical acceptance.
    R9_FULL_OUT_DIR="${SABLE_R9_FULL_OUT_DIR:-out_sable_r9_full_${EXPECTED_SOURCE_COMMIT:0:12}}"
    BUILD_REQUIRE_FRESH_OUT=YES
fi
if [[ "$R9_FULL_OUT_DIR" == /* ]]; then
    R9_FULL_OUT_ABS="$R9_FULL_OUT_DIR"
else
    R9_FULL_OUT_ABS="$WS/$R9_FULL_OUT_DIR"
fi

mkdir -p "$EVIDENCE" "$BUNDLE" "$WORK"
exec > >(tee -a "$EVIDENCE/release-candidate-driver.log") 2>&1

echo "===== SABLEOS R8 RELEASE-CANDIDATE DRIVER ====="
echo "SABLEOS_RELEASE_VERSION=$SABLEOS_RELEASE_VERSION"
echo "SABLEOS_BUILD_PROFILE_VERSION=$SABLEOS_BUILD_PROFILE_VERSION"
echo "SOURCE_MUTATION_AUTHORIZED=YES"
echo "WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=YES"
echo "BUILD_AUTHORIZED=YES"
echo "CLEAN_AUTHORIZED=NO"
echo "CLOBBER_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REPO=$REPO"
echo "WORKSPACE=$WS"
echo "EXPECTED_SOURCE_COMMIT=$EXPECTED_SOURCE_COMMIT"
echo "EVIDENCE=$EVIDENCE"
echo "BUNDLE=$BUNDLE"
echo "R9_FULL_OUT_DIR=$R9_FULL_OUT_DIR"
echo "R9_FULL_OUT_ABS=$R9_FULL_OUT_ABS"
echo "SABLE_QUALIFICATION_ONLY=$SABLE_QUALIFICATION_ONLY"
echo "BUILD_REQUIRE_FRESH_OUT=$BUILD_REQUIRE_FRESH_OUT"

[[ -d "$REPO/.git" ]] || {
    echo "R8_REPO=FAIL path=$REPO"
    exit 5
}
[[ -d "$WS/.repo" ]] || {
    echo "R8_ANDROID_WORKSPACE=FAIL path=$WS"
    exit 6
}

actual_source="$(git -C "$REPO" rev-parse HEAD)"
[[ "$actual_source" == "$EXPECTED_SOURCE_COMMIT" ]] || {
    echo "R8_SOURCE_IDENTITY=FAIL expected=$EXPECTED_SOURCE_COMMIT actual=$actual_source"
    exit 7
}

if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
    echo "R8_TRACKED_SOURCE_CLEAN=FAIL"
    git -C "$REPO" status --short
    exit 8
fi

if [[ "$SABLE_QUALIFICATION_ONLY" == YES ]]; then
    if [[ ! -d "$R9_FULL_OUT_ABS/target/product/panther" ]]; then
        echo "R9_MODULE_QUALIFICATION_WARM_OUT=FAIL_PRODUCT_TREE path=$R9_FULL_OUT_ABS"
        echo "R8_RELEASE_CANDIDATE=FAIL"
        exit 8
    fi

    warm_graph=NO
    [[ -f "$R9_FULL_OUT_ABS/build.ninja" ]] && warm_graph=YES
    [[ -f "$R9_FULL_OUT_ABS/soong/build.ninja" ]] && warm_graph=YES
    compgen -G "$R9_FULL_OUT_ABS/build-*panther*.ninja" >/dev/null && warm_graph=YES
    compgen -G "$R9_FULL_OUT_ABS/combined-*panther*.ninja" >/dev/null && warm_graph=YES

    if [[ "$warm_graph" != YES ]]; then
        echo "R9_MODULE_QUALIFICATION_WARM_OUT=FAIL_NINJA_GRAPH path=$R9_FULL_OUT_ABS"
        echo "R8_RELEASE_CANDIDATE=FAIL"
        exit 8
    fi

    echo "R9_MODULE_QUALIFICATION_WARM_OUT=PASS path=$R9_FULL_OUT_ABS"
    echo "R9_RELEASE_CANDIDATE_FRESH_OUT=NOT_REQUIRED_MODULE_QUALIFICATION"
else
    if [[ -e "$R9_FULL_OUT_ABS" ]]; then
        echo "R9_RELEASE_CANDIDATE_FRESH_OUT=FAIL_PRESENT path=$R9_FULL_OUT_ABS"
        echo "R8_RELEASE_CANDIDATE=FAIL"
        exit 8
    fi
    echo "R9_RELEASE_CANDIDATE_FRESH_OUT=PASS_ABSENT path=$R9_FULL_OUT_ABS"
fi

echo
echo "===== RETIRE OBSOLETE GRADLE MODULE RESIDUE ====="

SOURCE_MUTATION_AUTHORIZED=YES \
    bash "$ROOT/build/panther/retire-r8-obsolete-gradle-residue.sh" \
    | tee "$EVIDENCE/obsolete-gradle-residue.log"

grep -Fxq 'R8_OBSOLETE_GRADLE_RESIDUE=PASS' \
    "$EVIDENCE/obsolete-gradle-residue.log"

echo
echo "===== CANONICAL HOST-TOOL GATE ====="
bash "$ROOT/build/host/verify-r8-host-tools.sh"

source "$ROOT/apps/r8/reader/upstream.env"
source "$ROOT/apps/r8/textreader/upstream.env"
source "$ROOT/apps/r8/mail/upstream.env"

for spec in     "$SABLE_R8_READER_CACHE:$VAACHAK_COMMIT:R8_READER_PIN"     "$SABLE_R8_TEXTREADER_CACHE:$VAACHAK_TEXTREADER_COMMIT:R8_TEXTREADER_PIN"     "$SABLE_R8_MAIL_CACHE:$THUNDERBIRD_COMMIT:R8_MAIL_PIN"
do
    IFS=: read -r checkout commit marker <<<"$spec"
    [[ -d "$checkout/.git" ]] || {
        echo "$marker=FAIL_MISSING path=$checkout"
        exit 9
    }
    actual="$(git -C "$checkout" rev-parse HEAD)"
    [[ "$actual" == "$commit" ]] || {
        echo "$marker=FAIL expected=$commit actual=$actual"
        exit 10
    }
    echo "$marker=PASS commit=$actual"
done

BASE_PATH="$PATH"
export ANDROID_HOME="$SABLE_ANDROID_SDK"
export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
export ANDROID_NDK_HOME="$SABLE_ANDROID_SDK/ndk/$SABLE_ANDROID_NDK_VERSION"
export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
export CARGO_HOME="$SABLE_CARGO_HOME"
export RUSTUP_HOME="$SABLE_RUSTUP_HOME"
export CARGO="$SABLE_CARGO"
export RUSTC="$SABLE_RUSTC"
export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"

echo
echo "===== FIRST-PARTY R8 APPLICATIONS ====="

export JAVA_HOME="$SABLE_JDK17"
export PATH="$JAVA_HOME/bin:$SABLE_CARGO_HOME/bin:$SABLE_RUST_TOOLCHAIN_ROOT/bin:$SABLE_ANDROID_SDK/platform-tools:$SABLE_ANDROID_SDK/cmdline-tools/latest/bin:$BASE_PATH"

"$JAVA_HOME/bin/java" -version
"$RUSTC" --version
"$CARGO" --version

echo
echo "===== FIRST-PARTY RUST WORKSPACE TESTS ====="

"$CARGO" test \
    --locked \
    --manifest-path "$REPO/apps/r8/rust/Cargo.toml" \
    --workspace \
    2>&1 | tee "$EVIDENCE/first-party-rust-tests.log"

echo "R9_FIRST_PARTY_RUST_TESTS=PASS"

cd "$REPO/apps/r8/android"
./gradlew     --offline     :design:testDebugUnitTest     :calculator:assembleDebug     :games:assembleSudokuDebug     :games:assembleMinesweeperDebug     :games:assembleGame2048Debug     :media:assembleDebug     :hub:testDebugUnitTest     :hub:assembleDebug     :weather:assembleDebug     :calendar:assembleDebug     --stacktrace     --console=plain     --no-daemon     2>&1 | tee "$EVIDENCE/first-party-build.log"

FIRST_PARTY_SDK_XML_WARNING_COUNT="$(
    grep -Fc 'Warning: SDK processing. This version only understands SDK XML versions up to 3'         "$EVIDENCE/first-party-build.log" || true
)"
echo "R9_FIRST_PARTY_SDK_XML_WARNING_COUNT=$FIRST_PARTY_SDK_XML_WARNING_COUNT"

echo "R8_FIRST_PARTY_ANDROID_BUILD=PASS"
echo "R9_SABLE_WEATHER_ANDROID_BUILD=PASS"

echo
echo "===== SABLE TEXT READER ====="

git clone --no-hardlinks "$SABLE_R8_TEXTREADER_CACHE" "$WORK/textreader"
git -C "$WORK/textreader" checkout --detach "$VAACHAK_TEXTREADER_COMMIT"

python3 "$REPO/apps/r8/textreader/apply_sable_flavor.py" "$WORK/textreader"
python3 "$REPO/apps/r8/textreader/verify_sable_textreader.py" "$WORK/textreader"

(
    cd "$WORK/textreader"
    ./gradlew \
        --offline \
        testDebugUnitTest \
        lintDebug \
        assembleDebug \
        --stacktrace \
        --console=plain \
        --no-daemon \
        --no-configuration-cache
) 2>&1 | tee "$EVIDENCE/textreader-build.log"

mapfile -t textreader_apks < <(
    find "$WORK/textreader/app/build/outputs/apk/debug" \
        -maxdepth 1 -type f -name 'SableTextReader-*.apk' -print | sort
)
[[ "${#textreader_apks[@]}" -eq 1 ]] || {
    echo "R9_SABLE_TEXT_READER_APK=FAIL_COUNT count=${#textreader_apks[@]}"
    exit 11
}
SABLE_TEXTREADER_APK="${textreader_apks[0]}"
APKANALYZER="$SABLE_APKANALYZER" \
    python3 "$REPO/apps/r8/textreader/verify_sable_textreader.py" \
        "$WORK/textreader" "$SABLE_TEXTREADER_APK"
sha256sum "$SABLE_TEXTREADER_APK"
echo "R9_SABLE_TEXT_READER_BUILD=PASS"

echo
echo "===== SABLE READER ====="

export JAVA_HOME="$SABLE_JDK21"
export PATH="$JAVA_HOME/bin:$SABLE_CARGO_HOME/bin:$SABLE_RUST_TOOLCHAIN_ROOT/bin:$SABLE_ANDROID_SDK/platform-tools:$SABLE_ANDROID_SDK/cmdline-tools/latest/bin:$BASE_PATH"

git clone --no-hardlinks "$SABLE_R8_READER_CACHE" "$WORK/reader"
git -C "$WORK/reader" checkout --detach "$VAACHAK_COMMIT"

python3 "$REPO/apps/r8/reader/apply_sable_flavor.py" "$WORK/reader"

(
    cd "$WORK/reader"
    ./gradlew         --offline         :leisure:assembleSableDebug         --stacktrace         --console=plain         --no-daemon         --no-configuration-cache
) 2>&1 | tee "$EVIDENCE/reader-build.log"

mapfile -t reader_apks < <(
    find "$WORK/reader/leisure/build/outputs/apk/sable/debug"         -type f -name '*.apk' -print | sort
)
[[ "${#reader_apks[@]}" -eq 1 ]] || {
    echo "R8_READER_APK=FAIL_COUNT count=${#reader_apks[@]}"
    exit 11
}
SABLE_READER_APK="${reader_apks[0]}"
sha256sum "$SABLE_READER_APK"

READER_KOTLIN_WARNING_COUNT="$(
    grep -Ec '^w: file://' "$EVIDENCE/reader-build.log" || true
)"
READER_NATIVE_STRIP_WARNING_COUNT="$(
    grep -Fc 'Unable to strip the following libraries' "$EVIDENCE/reader-build.log" || true
)"
READER_SDK_XML_WARNING_COUNT="$(
    grep -Fc 'Warning: SDK processing. This version only understands SDK XML versions up to 3'         "$EVIDENCE/reader-build.log" || true
)"

echo "R9_READER_KOTLIN_WARNING_COUNT=$READER_KOTLIN_WARNING_COUNT"
echo "R9_READER_NATIVE_STRIP_WARNING_COUNT=$READER_NATIVE_STRIP_WARNING_COUNT"
echo "R9_READER_SDK_XML_WARNING_COUNT=$READER_SDK_XML_WARNING_COUNT"
if [[ "$READER_KOTLIN_WARNING_COUNT" -gt 0 ]]; then
    echo "===== R9 READER REMAINING KOTLIN WARNINGS ====="
    grep -E '^w: file://' "$EVIDENCE/reader-build.log" || true
fi
echo "R8_SABLE_READER_BUILD=PASS"

echo
echo "===== SABLE MAIL ====="

git clone --no-hardlinks "$SABLE_R8_MAIL_CACHE" "$WORK/mail"
git -C "$WORK/mail" checkout --detach "$THUNDERBIRD_COMMIT"

python3 "$REPO/apps/r8/mail/apply_sable_flavor.py" "$WORK/mail"
python3 "$REPO/apps/r8/mail/verify_sable_mail.py" "$WORK/mail"

(
    cd "$WORK/mail"
    ./gradlew         --offline         :app-thunderbird:assembleFossRelease         -Pci=true         --stacktrace         --console=plain         --warning-mode all         --no-daemon
) 2>&1 | tee "$EVIDENCE/mail-build.log"

mapfile -t mail_apks < <(
    find "$WORK/mail/app-thunderbird/build/outputs/apk/foss/release"         -maxdepth 1 -type f -name '*.apk' -print | sort
)
[[ "${#mail_apks[@]}" -eq 1 ]] || {
    echo "R8_MAIL_APK=FAIL_COUNT count=${#mail_apks[@]}"
    exit 12
}
SABLE_MAIL_APK="${mail_apks[0]}"

python3 "$REPO/apps/r8/mail/verify_sable_mail.py"     "$WORK/mail"     "$SABLE_MAIL_APK"
sha256sum "$SABLE_MAIL_APK"

MAIL_GRADLE_DEPRECATION_SUMMARY_COUNT="$(
    grep -Fc 'Deprecated Gradle features were used in this build'         "$EVIDENCE/mail-build.log" || true
)"
MAIL_GRADLE_DEPRECATION_DETAIL_COUNT="$(
    grep -Eic 'deprecated|deprecation' "$EVIDENCE/mail-build.log" || true
)"
echo "R9_MAIL_GRADLE_DEPRECATION_SUMMARY_COUNT=$MAIL_GRADLE_DEPRECATION_SUMMARY_COUNT"
echo "R9_MAIL_GRADLE_DEPRECATION_DETAIL_COUNT=$MAIL_GRADLE_DEPRECATION_DETAIL_COUNT"
if [[ "$MAIL_GRADLE_DEPRECATION_DETAIL_COUNT" -eq 0 ]]; then
    echo "R9_MAIL_GRADLE_DEPRECATIONS=PASS_ZERO"
else
    echo "R9_MAIL_GRADLE_DEPRECATIONS=DEFERRED_UPSTREAM_BUILD_TOOLING_OFFLINE_CACHE_PRESERVED count=$MAIL_GRADLE_DEPRECATION_DETAIL_COUNT"
fi
if [[ "$MAIL_GRADLE_DEPRECATION_DETAIL_COUNT" -gt 0 ]]; then
    echo "===== R9 MAIL GRADLE DEPRECATION DETAILS ====="
    grep -Ei 'deprecated|deprecation' "$EVIDENCE/mail-build.log" | head -n 80 || true
fi
echo "R8_SABLE_MAIL_BUILD=PASS"

echo
echo "===== SOURCE-BOUND ELEVEN-APK BUNDLE ====="

cd "$REPO"
SABLE_TEXTREADER_APK="$SABLE_TEXTREADER_APK" SABLE_READER_APK="$SABLE_READER_APK" SABLE_MAIL_APK="$SABLE_MAIL_APK" APKANALYZER="$SABLE_APKANALYZER"     bash "$REPO/apps/r8/export-panther-app-bundle.sh" "$BUNDLE"

[[ "$(tr -d '[:space:]' < "$BUNDLE/SABLEOS_SOURCE_COMMIT.txt")" == "$EXPECTED_SOURCE_COMMIT" ]] || {
    echo "R8_APP_BUNDLE_SOURCE=FAIL"
    exit 13
}
echo "R9_SOURCE_BOUND_ELEVEN_APK_FREEZE=PASS"

echo
echo "===== R8 WORKSPACE / PRODUCT PREPARATION ====="

SOURCE_MUTATION_AUTHORIZED=YES SABLEOS_ROOT="$SABLE_BUILD_ROOT" SABLEOS_REPO="$REPO" SABLEOS_UPSTREAM="$WS" R8_APP_BUNDLE="$BUNDLE"     bash "$REPO/build/panther/prepare-r8-final-ui.sh"

echo
echo "===== FINAL PRODUCT COMPOSITION ====="

SABLE_QUALIFICATION_ONLY="$SABLE_QUALIFICATION_ONLY" \
WS="$WS" SABLEOS_UPSTREAM="$WS" \
    bash "$REPO/build/gates/r8-final-product-composition.sh" \
    | tee "$EVIDENCE/product-composition.log"

grep -Fxq 'R8_FINAL_UI_PRODUCT_COMPOSITION=PASS'     "$EVIDENCE/product-composition.log"
if [[ "$SABLE_QUALIFICATION_ONLY" == YES ]]; then
    echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZATION=NOT_REQUIRED_FOR_MODULE_QUALIFICATION"
else
    grep -Fxq 'NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES' \
        "$EVIDENCE/product-composition.log"
fi

echo "R8_PREBUILD_PRODUCT_CLOSURE=PASS"

echo
echo "===== FINAL PANTHER BUILD ====="

export PATH="$BASE_PATH"
unset JAVA_HOME
unset ANDROID_HOME
unset ANDROID_SDK_ROOT
unset ANDROID_NDK_HOME
unset ANDROID_NDK_ROOT
unset CARGO
unset RUSTC
unset CARGO_HOME
unset RUSTUP_HOME
unset GRADLE_USER_HOME

if [[ "$SABLE_QUALIFICATION_ONLY" == YES ]]; then
    BUILD_STAGE=modules
else
    BUILD_STAGE=full
fi

BUILD_AUTHORIZED=YES \
REQUIRE_FRESH_OUT="$BUILD_REQUIRE_FRESH_OUT" \
SABLE_BUILD_STAGE="$BUILD_STAGE" \
SABLEOS_ROOT="$SABLE_BUILD_ROOT" \
SABLEOS_REPO="$REPO" \
SABLEOS_UPSTREAM="$WS" \
WS="$WS" \
OUT_DIR="$R9_FULL_OUT_DIR" \
JOBS=8 \
EVIDENCE_DIR="$EVIDENCE" \
    bash "$REPO/build/panther/build-r8-final-ui.sh"

if [[ "$SABLE_QUALIFICATION_ONLY" == YES ]]; then
    echo
    echo "===== R9 PRE-FULL-BUILD QUALIFICATION RESULT ====="
    echo "SOURCE=$EXPECTED_SOURCE_COMMIT"
    echo "BUNDLE=$BUNDLE"
    echo "EVIDENCE=$EVIDENCE"
    echo "OUT_DIR=$R9_FULL_OUT_ABS"
    echo "R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS"
    echo "R8_RELEASE_CANDIDATE=NOT_RUN"
    echo "R9_FRESH_FULL_BUILD=NOT_PROVEN"
    exit 0
fi

echo
echo "===== R8 RELEASE-CANDIDATE RESULT ====="
echo "R8_RELEASE_CANDIDATE=PASS"
echo "SOURCE=$EXPECTED_SOURCE_COMMIT"
echo "BUNDLE=$BUNDLE"
echo "EVIDENCE=$EVIDENCE"
echo "OUT_DIR=$R9_FULL_OUT_ABS"
echo "R9_FRESH_FULL_BUILD=PASS"

if [[ "${SABLE_AUTO_REGISTER_ARTIFACT:-NO}" == YES ]]; then
    echo
    echo "===== STANDARD RELEASE ARTIFACT REGISTRATION ====="
    TARGET_FILES="$R9_FULL_OUT_ABS/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target_files.zip"
    ANDROID_INFO="$R9_FULL_OUT_ABS/target/product/panther/android-info.txt"
    [[ -f "$TARGET_FILES" ]] || {
        echo "SABLE_RELEASE_ARTIFACT_REGISTER=FAIL_TARGET_FILES_MISSING"
        exit 80
    }
    [[ -f "$ANDROID_INFO" ]] || {
        echo "SABLE_RELEASE_ARTIFACT_REGISTER=FAIL_ANDROID_INFO_MISSING"
        exit 80
    }
    TARGET_FILES_SHA256="$(sha256sum "$TARGET_FILES" | awk '{print $1}')"

    bash "$ROOT/build/sable.sh" panther "$SABLEOS_RELEASE_VERSION" register-artifact \
        --build-source "$EXPECTED_SOURCE_COMMIT" \
        --target-files "$TARGET_FILES" \
        --sha256 "$TARGET_FILES_SHA256" \
        --android-info "$ANDROID_INFO" \
        --out-dir "$R9_FULL_OUT_ABS" \
        --build-evidence-dir "$EVIDENCE"

    echo "SABLE_RELEASE_ARTIFACT_REGISTER=PASS"
fi
