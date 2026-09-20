#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"

PROFILE="${1:-core}"
SABLEOS_DEVICE="${SABLEOS_DEVICE:-panther}"
SABLEOS_RELEASE_VERSION="${SABLEOS_RELEASE_VERSION:-R9}"
case "$PROFILE" in
  core|full|release) ;;
  *)
    echo "usage: bash build/local-ci/run.sh [core|full|release]" >&2
    exit 64
    ;;
esac

SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
SOURCE_DIRTY="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=normal)"
if [[ -n "$SOURCE_DIRTY" ]]; then
  echo "SABLE_LOCAL_CI=FAIL_DIRTY_SOURCE"
  printf '%s\n' "$SOURCE_DIRTY"
  exit 2
fi

EVIDENCE_ROOT="${SABLE_LOCAL_CI_EVIDENCE_ROOT:-/srv/data/sable-build/sableos/local-ci-evidence}"
CACHE_ROOT="${SABLE_LOCAL_CI_CACHE_ROOT:-/srv/data/sable-build/sableos/local-ci-cache}"
mkdir -p "$CACHE_ROOT"
RUN_ID="${SABLE_LOCAL_CI_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-${SOURCE_COMMIT:0:12}-$PROFILE}"
EVIDENCE_DIR="$EVIDENCE_ROOT/$RUN_ID"
mkdir -p "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/local-ci.log") 2>&1

echo "===== SABLE LOCAL CI ====="
echo "PROFILE=$PROFILE"
echo "SABLEOS_DEVICE=$SABLEOS_DEVICE"
echo "SABLEOS_RELEASE_VERSION=$SABLEOS_RELEASE_VERSION"
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "CACHE_ROOT=$CACHE_ROOT"
echo "GITHUB_ACTIONS_EXECUTION=DISABLED"
echo "SELF_HOSTED_ACTIONS_RUNNER=DISABLED"
echo "LOCAL_DIRECT_EXECUTION=YES"
echo "NETWORK_FETCH_AUTHORIZED=${SABLE_LOCAL_CI_ALLOW_NETWORK:-NO}"

if [[ "${SABLE_LOCAL_CI_ALLOW_NETWORK:-NO}" == YES ]]; then
  GRADLE_NETWORK_ARGS=()
  CARGO_NETWORK_ARGS=()
else
  GRADLE_NETWORK_ARGS=(--offline)
  CARGO_NETWORK_ARGS=(--offline)
fi

stage() {
  local name="$1"
  shift
  echo
  echo "===== $name ====="
  "$@"
  echo "SABLE_LOCAL_CI_STAGE_$name=PASS"
}

run_policy() {
  python3 "$ROOT/build/check-ci-policy.py"
  python3 "$ROOT/build/check-runner-policy.py"
  python3 "$ROOT/build/install-pinned-tool.py" --validate-lock
  bash "$ROOT/build/check-repo-layout.sh"
  bash "$ROOT/build/host/verify-r8-host-tools.sh"
}

run_static() {
  local shell_count=0
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    bash -n "$ROOT/$script"
    shell_count=$((shell_count + 1))
  done < <(
    git -C "$ROOT" ls-files -- \
      '.githooks/pre-push' \
      'apps/r8/*.sh' \
      'apps/r8/**/*.sh' \
      'build/*.sh' \
      'build/host/*.sh' \
      'build/macos/*.sh' \
      'build/panther/*.sh' \
      'build/deploy/*.sh' \
      'build/devices/*.sh' \
      'build/gates/*.sh' \
      'tests/sablestart/host/*.sh' \
      'tests/sablestart/device/*.sh' \
      'tests/launcher3/device/*.sh'
  )
  echo "SABLE_LOCAL_CI_ACTIVE_SHELL_SYNTAX_COUNT=$shell_count"

  local python_count=0
  while IFS= read -r py; do
    [[ -n "$py" ]] || continue
    python3 -m py_compile "$ROOT/$py"
    python_count=$((python_count + 1))
  done < <(
    git -C "$ROOT" ls-files -- \
      'apps/r8/*.py' \
      'apps/r8/**/*.py' \
      'build/*.py' \
      'build/deploy/*.py' \
      'build/gates/*.py' \
      'patches/android-17-grapheneos-2026081300/*.py'
  )
  echo "SABLE_LOCAL_CI_ACTIVE_PYTHON_SYNTAX_COUNT=$python_count"

  # tools/validation/** is a byte-preserved historical evidence archive, not
  # the maintained CI execution surface. Its SHA-bound artifacts are not
  # rewritten or syntax-qualified as current tooling.

  for applicator in "$ROOT"/patches/android-17-grapheneos-2026081300/apply_*.py; do
    [[ -f "$applicator" ]] || continue
    if grep -Fq -- '--self-test' "$applicator"; then
      python3 "$applicator" --self-test
    fi
  done

  bash "$ROOT/build/gates/r8-build-driver-contract.sh"
  bash "$ROOT/build/gates/sable-pipeline-contract.sh"
  bash "$ROOT/build/gates/r8-no-stale-product-code.sh"
  python3 "$ROOT/build/gates/r9-sablestart-design-contract.py" --self-test
  python3 "$ROOT/build/gates/r9-sablestart-design-contract.py"
  python3 "$ROOT/build/gates/r9-launcher3-foundation-contract.py" --self-test
  python3 "$ROOT/build/gates/r9-launcher3-foundation-contract.py"
  python3 "$ROOT/build/gates/r9-launcher-visual-review-contract.py"
  python3 "$ROOT/build/gates/r9-launcher-visual-acceptance.py"
}

run_rust() {
  export CARGO_HOME="$SABLE_CARGO_HOME"
  export RUSTUP_HOME="$SABLE_RUSTUP_HOME"
  export PATH="$SABLE_RUST_TOOLCHAIN_ROOT/bin:$PATH"

  (
    cd "$ROOT/apps/r8/rust"
    "$SABLE_CARGO" fmt --all -- --check
    "$SABLE_CARGO" clippy "${CARGO_NETWORK_ARGS[@]}" --locked --workspace --all-targets --all-features -- -D warnings
    "$SABLE_CARGO" test "${CARGO_NETWORK_ARGS[@]}" --locked --workspace --all-targets
    "$SABLE_CARGO" metadata "${CARGO_NETWORK_ARGS[@]}" --locked --no-deps --format-version 1       > "$EVIDENCE_DIR/r8-rust-metadata.json"
    "$SABLE_CARGO" tree "${CARGO_NETWORK_ARGS[@]}" --locked       > "$EVIDENCE_DIR/r8-rust-dependency-tree.txt"
  )
}

run_android() {
  export ANDROID_HOME="$SABLE_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
  export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
  export JAVA_HOME="$SABLE_JDK17"
  export PATH="$JAVA_HOME/bin:$PATH"

  (
    cd "$ROOT/apps/r8/android"
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       :design:testDebugUnitTest       :hub:testDebugUnitTest       :sablestart-presentation-check:compileDebugKotlin       :sablestart-visual-review:assembleDebug       :calculator:assembleDebug       :games:assembleSudokuDebug       :games:assembleMinesweeperDebug       :games:assembleGame2048Debug       :media:assembleDebug       :hub:assembleDebug       :design:lintDebug       :calculator:lintDebug       :convert:lintDebug       :games:lintSudokuDebug       :games:lintMinesweeperDebug       :games:lintGame2048Debug       :media:lintDebug       :hub:lintDebug       :sablestart-presentation-check:lintDebug       :sablestart-visual-review:lintDebug       --stacktrace --console=plain --no-daemon
  )
}

verify_shared_security_tools() {
  python3 "$ROOT/build/install-pinned-tool.py" --verify-dir "$SABLE_SECURITY_BIN"

  local installed_components
  installed_components="$("$SABLE_RUSTUP" component list --installed --toolchain "$SABLE_RUST_TOOLCHAIN")"
  grep -Eq '^llvm-tools(-|$)' <<<"$installed_components" || {
    echo "SABLE_LOCAL_CI=FAIL_RUST_LLVM_TOOLS_MISSING"
    return 1
  }
  grep -Eq '^rust-src($|-)' <<<"$installed_components" || {
    echo "SABLE_LOCAL_CI=FAIL_RUST_SRC_MISSING"
    return 1
  }

  [[ -d "$SABLE_MOBSFSCAN_SOURCE/.git" ]] || {
    echo "SABLE_LOCAL_CI=FAIL_MOBSFSCAN_SOURCE path=$SABLE_MOBSFSCAN_SOURCE"
    return 1
  }
  [[ "$(git -C "$SABLE_MOBSFSCAN_SOURCE" rev-parse HEAD)" == "$SABLE_MOBSFSCAN_COMMIT" ]] || {
    echo "SABLE_LOCAL_CI=FAIL_MOBSFSCAN_COMMIT"
    return 1
  }
  [[ -x "$SABLE_MOBSFSCAN" ]] || {
    echo "SABLE_LOCAL_CI=FAIL_MOBSFSCAN_EXEC path=$SABLE_MOBSFSCAN"
    return 1
  }
  "$SABLE_MOBSFSCAN" --version 2>&1 | grep -Fq "$SABLE_MOBSFSCAN_VERSION" || {
    echo "SABLE_LOCAL_CI=FAIL_MOBSFSCAN_VERSION"
    return 1
  }

  echo "SABLE_LOCAL_CI_SHARED_SECURITY_TOOLS=PASS"
}

run_quality() {
  export ANDROID_HOME="$SABLE_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
  export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
  export JAVA_HOME="$SABLE_JDK17"
  export PATH="$JAVA_HOME/bin:$PATH"

  (
    cd "$ROOT/apps/r8/android"
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       :design:detekt       :calculator:detekt       :convert:detekt       :games:detekt       :media:detekt       :hub:detekt       :design:ktlintCheck       :calculator:ktlintCheck       :convert:ktlintCheck       :games:ktlintCheck       :media:ktlintCheck       :hub:ktlintCheck       :design:koverXmlReportDebug       :design:koverHtmlReportDebug       --stacktrace --console=plain --no-daemon
  )

  verify_shared_security_tools
  (
    cd "$ROOT/apps/r8/rust"
    export PATH="$SABLE_SECURITY_BIN:$SABLE_RUST_TOOLCHAIN_ROOT/bin:$SABLE_CARGO_HOME/bin:$PATH"
    export CARGO_LLVM_COV_SETUP=no
    export RUSTUP_TOOLCHAIN="$SABLE_RUST_TOOLCHAIN"
    "$SABLE_CARGO" llvm-cov "${CARGO_NETWORK_ARGS[@]}"       --workspace --locked --lcov       --output-path "$EVIDENCE_DIR/rust-coverage.lcov"
    test -s "$EVIDENCE_DIR/rust-coverage.lcov"
  )
}

need_tool() {
  local tool="$1"
  command -v "$tool" >/dev/null 2>&1 || {
    echo "SABLE_LOCAL_CI_REQUIRED_TOOL_MISSING=$tool"
    return 1
  }
}

run_security() {
  export CARGO_HOME="$SABLE_CARGO_HOME"
  export RUSTUP_HOME="$SABLE_RUSTUP_HOME"
  export PATH="$SABLE_SECURITY_BIN:$SABLE_RUST_TOOLCHAIN_ROOT/bin:$SABLE_CARGO_HOME/bin:$PATH"
  verify_shared_security_tools

  (
    cd "$ROOT/apps/r8/rust"
    "$SABLE_CARGO" audit --deny warnings
    "$SABLE_CARGO" deny check advisories bans sources
  )

  gitleaks_report="$EVIDENCE_DIR/gitleaks-results.json"
  rm -f "$gitleaks_report"
  set +e
  "$SABLE_GITLEAKS" git \
    --config "$ROOT/.gitleaks.toml" \
    --log-opts="--all" \
    --redact \
    --no-banner \
    --report-format json \
    --report-path "$gitleaks_report" \
    "$ROOT"
  gitleaks_rc=$?
  set -e

  python3 - "$gitleaks_report" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if not path.exists():
    print("GITLEAKS_REPORT=ABSENT")
    raise SystemExit(0)

findings = json.loads(path.read_text(encoding="utf-8"))
print(f"GITLEAKS_FINDING_COUNT={len(findings)}")
for item in findings:
    print(
        "GITLEAKS_FINDING "
        f"rule={item.get('RuleID', 'UNKNOWN')} "
        f"file={item.get('File', 'UNKNOWN')} "
        f"commit={item.get('Commit', 'UNKNOWN')} "
        f"line={item.get('StartLine', 'UNKNOWN')}"
    )
PY

  if [[ "$gitleaks_rc" -ne 0 ]]; then
    echo "SABLE_GITLEAKS=FAIL report=$gitleaks_report"
    return "$gitleaks_rc"
  fi
  echo "SABLE_GITLEAKS=PASS report=$gitleaks_report"

  "$SABLE_MOBSFSCAN"     "$ROOT/apps/r8/android"     --sarif     --output "$EVIDENCE_DIR/mobsfscan-results.sarif"     --type android     --no-fail
  test -s "$EVIDENCE_DIR/mobsfscan-results.sarif"
}

run_apk_seal() {
  local aapt2="$SABLE_ANDROID_SDK/build-tools/$SABLE_ANDROID_BUILD_TOOLS_VERSION/aapt2"
  [[ -x "$aapt2" ]] || {
    echo "SABLE_LOCAL_CI=FAIL_AAPT2 path=$aapt2"
    return 1
  }

  local apks=(
    "$ROOT/apps/r8/android/calculator/build/outputs/apk/debug/calculator-debug.apk"
    "$ROOT/apps/r8/android/games/build/outputs/apk/sudoku/debug/games-sudoku-debug.apk"
    "$ROOT/apps/r8/android/games/build/outputs/apk/minesweeper/debug/games-minesweeper-debug.apk"
    "$ROOT/apps/r8/android/games/build/outputs/apk/game2048/debug/games-game2048-debug.apk"
    "$ROOT/apps/r8/android/media/build/outputs/apk/debug/media-debug.apk"
    "$ROOT/apps/r8/android/hub/build/outputs/apk/debug/hub-debug.apk"
  )

  : > "$EVIDENCE_DIR/R8_APK_SEALS.txt"
  for apk in "${apks[@]}"; do
    [[ -f "$apk" ]] || {
      echo "SABLE_LOCAL_CI=FAIL_APK_MISSING path=$apk"
      return 1
    }
    echo "===== $apk =====" | tee -a "$EVIDENCE_DIR/R8_APK_SEALS.txt"
    sha256sum "$apk" | tee -a "$EVIDENCE_DIR/R8_APK_SEALS.txt"
    "$aapt2" dump badging "$apk"       | grep -E '^(package:|application-label:)'       | tee -a "$EVIDENCE_DIR/R8_APK_SEALS.txt"
    "$aapt2" dump permissions "$apk"       | tee -a "$EVIDENCE_DIR/R8_APK_SEALS.txt"
  done

  test "$(grep -c '^===== ' "$EVIDENCE_DIR/R8_APK_SEALS.txt")" -eq 6
  for pkg in     org.sableos.calculator     org.sableos.media     org.sableos.sudoku     org.sableos.minesweeper     org.sableos.game2048     org.sableos.hub
  do
    grep -q "name='$pkg'" "$EVIDENCE_DIR/R8_APK_SEALS.txt"
  done
}

run_supply_chain() {
  python3 "$ROOT/build/check-gradle-supply-chain.py"     --manifest "$EVIDENCE_DIR/INFRA3_GRADLE_STATE.json"
  python3 "$ROOT/build/generate-supply-chain-evidence.py"     --out "$EVIDENCE_DIR/SABLE_SUPPLY_CHAIN_EVIDENCE.json"     --rust-sbom "$EVIDENCE_DIR/SABLE_R8_RUST_SBOM.cdx.json"     --artifact-glob 'apps/r8/android/*/build/outputs/apk/debug/*.apk'     --artifact-glob 'apps/r8/android/*/build/outputs/apk/*/debug/*.apk'
  (
    cd "$EVIDENCE_DIR"
    sha256sum       SABLE_SUPPLY_CHAIN_EVIDENCE.json       SABLE_R8_RUST_SBOM.cdx.json       > SABLE_SUPPLY_CHAIN_EVIDENCE.sha256
  )
}

clone_pinned() {
  local repo_url="$1"
  local commit="$2"
  local dest="$3"

  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" remote set-url origin "$repo_url"
  else
    [[ "${SABLE_LOCAL_CI_ALLOW_NETWORK:-NO}" == YES ]] || {
      echo "SABLE_LOCAL_CI=FAIL_NETWORK_REQUIRED dest=$dest"
      return 1
    }
    git clone --no-tags --filter=blob:none "$repo_url" "$dest"
  fi

  if ! git -C "$dest" cat-file -e "$commit^{commit}" 2>/dev/null; then
    [[ "${SABLE_LOCAL_CI_ALLOW_NETWORK:-NO}" == YES ]] || {
      echo "SABLE_LOCAL_CI=FAIL_PIN_NOT_CACHED commit=$commit dest=$dest"
      return 1
    }
    git -C "$dest" fetch --depth=1 origin "$commit"
  fi

  git -C "$dest" checkout --detach "$commit"
  git -C "$dest" reset --hard "$commit"
  git -C "$dest" clean -ffd
  test "$(git -C "$dest" rev-parse HEAD)" = "$commit"
}

run_textreader() {
  source "$ROOT/apps/r8/textreader/upstream.env"
  local work="$CACHE_ROOT/vaachak-textreader"
  mkdir -p "$CACHE_ROOT"
  clone_pinned "$VAACHAK_TEXTREADER_REPOSITORY" "$VAACHAK_TEXTREADER_COMMIT" "$work"

  export JAVA_HOME="$SABLE_JDK17"
  export ANDROID_HOME="$SABLE_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
  export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
  (
    cd "$work"
    chmod +x gradlew
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       testDebugUnitTest lintDebug assembleDebug       --stacktrace --console=plain --no-daemon --no-configuration-cache

    manifest=app/src/main/AndroidManifest.xml
    main=app/src/main/java/org/vaachak/textreader/MainActivity.kt
    shared=app/src/main/java/org/vaachak/textreader/SharedComponents.kt
    util=app/src/main/java/org/vaachak/textreader/TextReaderUtil.kt

    grep -q 'android.permission.CAMERA' "$manifest"
    grep -q 'android.hardware.camera.*required="false"' "$manifest"
    grep -q 'android.permission.INTERNET' "$manifest"
    grep -q 'android.intent.action.SEND' "$manifest"
    grep -q 'android.intent.action.PROCESS_TEXT' "$manifest"
    grep -q 'ActivityResultContracts.OpenDocument' "$main"
    grep -q 'TextToSpeech' "$main"
    grep -q 'CreateDocument("audio/wav")' "$main"
    grep -q 'TextRecognition.getClient' "$main"
    grep -q 'downloadModelIfNeeded' "$shared"
    ! grep -q '^import android\.' "$util"

    find app/build/outputs/apk/debug -type f -name '*.apk'       -print -exec sha256sum {} \; > "$EVIDENCE_DIR/textreader-apk-seal.txt"
  )
}

run_reader() {
  source "$ROOT/apps/r8/reader/upstream.env"
  source "$ROOT/apps/r8/textreader/upstream.env"
  local reader="$CACHE_ROOT/vaachak-reader"
  local text="$CACHE_ROOT/vaachak-textreader-reader"
  mkdir -p "$CACHE_ROOT"

  clone_pinned "$VAACHAK_REPOSITORY" "$VAACHAK_COMMIT" "$reader"
  clone_pinned "$VAACHAK_TEXTREADER_REPOSITORY" "$VAACHAK_TEXTREADER_COMMIT" "$text"

  python3 "$ROOT/apps/r8/reader/apply_sable_flavor.py" "$reader" "$text"

  export JAVA_HOME="$SABLE_JDK21"
  export ANDROID_HOME="$SABLE_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
  export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
  (
    cd "$reader"
    chmod +x gradlew
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       :core:testDebugUnitTest       :leisure:testSableDebugUnitTest       :leisure:lintSableDebug       :leisure:processSableDebugMainManifest       :leisure:assembleSableDebug       --stacktrace --console=plain --no-daemon --no-configuration-cache

    python3 "$ROOT/build/verify-reader-manifest.py" leisure/build/intermediates
    find leisure/build/outputs/apk/sable/debug -type f -name '*.apk'       -print -exec sha256sum {} \; > "$EVIDENCE_DIR/reader-apk-seal.txt"
  )
}

run_mail() {
  source "$ROOT/apps/r8/mail/upstream.env"
  local work="$CACHE_ROOT/sable-mail"
  mkdir -p "$CACHE_ROOT"
  clone_pinned "$THUNDERBIRD_REPOSITORY" "$THUNDERBIRD_COMMIT" "$work"

  python3 "$ROOT/apps/r8/mail/apply_sable_flavor.py" "$work"
  python3 "$ROOT/apps/r8/mail/verify_sable_mail.py" "$work"

  export JAVA_HOME="$SABLE_JDK21"
  export ANDROID_HOME="$SABLE_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
  export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
  (
    cd "$work"
    chmod +x gradlew

    ./gradlew "${GRADLE_NETWORK_ARGS[@]}" \
      :feature:account:setup:compileReleaseKotlin \
      :feature:onboarding:main:compileReleaseKotlin \
      :feature:launcher:compileReleaseKotlin \
      --stacktrace --console=plain --no-daemon
    echo "SABLE_MAIL_COMPOSED_NAVIGATION_COMPILE=PASS"

    ./gradlew "${GRADLE_NETWORK_ARGS[@]}" \
      :app-thunderbird:lintFossRelease \
      --stacktrace --console=plain --no-daemon

    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       :app-thunderbird:dependencies       --configuration fossReleaseRuntimeClasspath       --console=plain --no-daemon       | tee "$EVIDENCE_DIR/SABLE_MAIL_RUNTIME_DEPENDENCIES.txt"

    if grep -E       'feature:thundermail|feature:funding:(link|googleplay)|feature:telemetry:glean|feature:onboarding:migration:thunderbird|feature:migration:launcher:thunderbird|backend:demo|autodiscovery:demo'       "$EVIDENCE_DIR/SABLE_MAIL_RUNTIME_DEPENDENCIES.txt"
    then
      echo "SABLE_MAIL_STALE_RUNTIME_DEPENDENCY=FAIL"
      return 1
    fi

    for expected in \
      'feature:funding:noop' \
      'feature:telemetry:noop' \
      'feature:onboarding:migration:noop' \
      'feature:migration:launcher:noop'
    do
      grep -Fq "$expected" "$EVIDENCE_DIR/SABLE_MAIL_RUNTIME_DEPENDENCIES.txt" || {
        echo "SABLE_MAIL_EXPECTED_RUNTIME_DEPENDENCY=FAIL missing=$expected"
        return 1
      }
    done
    echo "SABLE_MAIL_STALE_RUNTIME_DEPENDENCY=PASS_ABSENT"
    echo "SABLE_MAIL_EXPECTED_RUNTIME_DEPENDENCY=PASS"

    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       :app-thunderbird:assembleFossRelease -Pci=true       --stacktrace --console=plain --no-daemon
  )

  mapfile -t apks < <(
    find "$work/app-thunderbird/build/outputs/apk/foss/release"       -maxdepth 1 -type f -name '*.apk' -print | sort
  )
  test "${#apks[@]}" -eq 1
  APKANALYZER="$SABLE_APKANALYZER" \
    python3 "$ROOT/apps/r8/mail/verify_sable_mail.py" "$work" "${apks[0]}"
  sha256sum "${apks[0]}" > "$EVIDENCE_DIR/SABLE_MAIL_APK_SHA256.txt"
}

write_attestation() {
  local attestation="$EVIDENCE_DIR/LOCAL_CI_ATTESTATION.txt"
  {
    echo "SABLE_LOCAL_CI=PASS"
    echo "PROFILE=$PROFILE"
    echo "SOURCE_COMMIT=$SOURCE_COMMIT"
    echo "RUN_ID=$RUN_ID"
    echo "EVIDENCE_DIR=$EVIDENCE_DIR"
    echo "COMPLETED_AT_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$attestation"
  sha256sum "$attestation" > "$attestation.sha256"

  if [[ "$PROFILE" == full || "$PROFILE" == release ]]; then
    local git_dir
    git_dir="$(git -C "$ROOT" rev-parse --git-dir)"
    [[ "$git_dir" = /* ]] || git_dir="$ROOT/$git_dir"
    mkdir -p "$git_dir/sable-local-ci"
    cp "$attestation" "$git_dir/sable-local-ci/$SOURCE_COMMIT.pass"
  fi
}

stage POLICY run_policy
stage STATIC run_static
stage RUST run_rust
stage ANDROID run_android
stage APK_SEAL run_apk_seal
stage QUALITY run_quality
stage SUPPLY_CHAIN run_supply_chain

if [[ "$PROFILE" == full || "$PROFILE" == release ]]; then
  stage SECURITY run_security
  stage TEXTREADER run_textreader
  stage READER run_reader
  stage MAIL run_mail
fi

if [[ "$PROFILE" == release ]]; then
  echo
  echo "===== DEVICE RELEASE CANDIDATE ====="
  if [[ "$SABLEOS_DEVICE" != panther ]]; then
    echo "SABLE_LOCAL_CI_STAGE_RELEASE=BLOCKED_UNQUALIFIED_DEVICE device=$SABLEOS_DEVICE"
    exit 78
  fi
  SABLEOS_RELEASE_VERSION="$SABLEOS_RELEASE_VERSION" \
  EXPECTED_SOURCE_COMMIT="$SOURCE_COMMIT" \
  SOURCE_MUTATION_AUTHORIZED=YES \
  BUILD_AUTHORIZED=YES \
    bash "$ROOT/build/panther/run-r8-release-candidate.sh"
  echo "SABLE_LOCAL_CI_STAGE_RELEASE=PASS"
fi

write_attestation

echo
echo "SABLE_LOCAL_CI=PASS"
echo "PROFILE=$PROFILE"
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
