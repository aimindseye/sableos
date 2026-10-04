#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"
source "$ROOT/build/console.sh"
sable_console_capture_color

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

sable_checkpoint_info "Local CI profile=$PROFILE source=$SOURCE_COMMIT"
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

stage_failure_scan() {
  local name="$1"
  local start_line="$2"
  local log="$EVIDENCE_DIR/local-ci.log"
  local failures

  [[ -f "$log" ]] || return 0

  failures="$(
    tail -n +"$start_line" "$log" \
      | grep -nE \
          'BUILD FAILED|FAILURE: Build failed|Execution failed for task|> Task .* FAILED|Compilation failed|MaxIssuesReached|Analysis failed with [0-9]+ weighted issues' \
      || true
  )"

  if [[ -n "$failures" ]]; then
    echo "SABLE_LOCAL_CI_STAGE_${name}_LOG_SCAN=FAIL"
    printf '%s\n' "$failures"
    return 1
  fi

  echo "SABLE_LOCAL_CI_STAGE_${name}_LOG_SCAN=PASS"
}

stage() {
  local name="$1"
  shift
  local stage_start_line=1
  local log="$EVIDENCE_DIR/local-ci.log"

  if [[ -f "$log" ]]; then
    stage_start_line="$(($(wc -l < "$log") + 1))"
  fi

  echo
  echo "===== $name ====="
  if "$@"; then
    if ! stage_failure_scan "$name" "$stage_start_line"; then
      local scan_rc=$?
      echo "SABLE_LOCAL_CI_STAGE_$name=FAIL rc=$scan_rc"
      sable_checkpoint_fail "CI stage $name"
      return "$scan_rc"
    fi
    echo "SABLE_LOCAL_CI_STAGE_$name=PASS"
    sable_checkpoint_pass "CI stage $name"
  else
    local rc=$?
    echo "SABLE_LOCAL_CI_STAGE_$name=FAIL rc=$rc"
    sable_checkpoint_fail "CI stage $name"
    return "$rc"
  fi
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
      'tests/launcher3/device/*.sh' \
      'tests/titan2/n1i-b/*.sh' \
      'tests/titan2/n1i-b/lib/*.sh'
  )
  echo "SABLE_LOCAL_CI_ACTIVE_SHELL_SYNTAX_COUNT=$shell_count"

  mapfile -t python_files < <(
    git -C "$ROOT" ls-files -- \
      'apps/r8/*.py' \
      'apps/r8/**/*.py' \
      'build/*.py' \
      'build/deploy/*.py' \
      'build/gates/*.py' \
      'patches/android-17-grapheneos-2026081300/*.py' \
      'tests/titan2/n1i-b/*.py' \
      'tests/titan2/n1i-b/lib/*.py'
  )
  local python_count="${#python_files[@]}"

  python3 - "$ROOT" "${python_files[@]}" <<'PY'
import pathlib
import sys
import tokenize

root = pathlib.Path(sys.argv[1])
failures: list[str] = []

for rel in sys.argv[2:]:
    path = root / rel
    try:
        with tokenize.open(path) as source_file:
            source = source_file.read()
        compile(source, str(path), "exec", dont_inherit=True)
    except (OSError, SyntaxError, UnicodeError) as exc:
        failures.append(f"{rel}: {exc}")

if failures:
    print("SABLE_LOCAL_CI_PYTHON_SYNTAX=FAIL")
    for failure in failures:
        print(f"PYTHON_SYNTAX_FAILURE={failure}")
    raise SystemExit(1)

print("SABLE_LOCAL_CI_PYTHON_SYNTAX=PASS")
PY
  echo "SABLE_LOCAL_CI_ACTIVE_PYTHON_SYNTAX_COUNT=$python_count"

  # tools/validation/** is a byte-preserved historical evidence archive, not
  # the maintained CI execution surface. Its SHA-bound artifacts are not
  # rewritten or syntax-qualified as current tooling.

  local applicator_self_test_failures=0
  for applicator in "$ROOT"/patches/android-17-grapheneos-2026081300/apply_*.py; do
    [[ -f "$applicator" ]] || continue
    if grep -Fq -- '--self-test' "$applicator"; then
      if ! python3 "$applicator" --self-test; then
        echo "SABLE_LOCAL_CI_APPLICATOR_SELF_TEST_FAILURE=$applicator"
        applicator_self_test_failures=$((applicator_self_test_failures + 1))
      fi
    fi
  done
  if [[ "$applicator_self_test_failures" -ne 0 ]]; then
    echo "SABLE_LOCAL_CI_APPLICATOR_SELF_TESTS=FAIL count=$applicator_self_test_failures"
    return 1
  fi
  echo "SABLE_LOCAL_CI_APPLICATOR_SELF_TESTS=PASS"

  local static_contract_failures=0
  local -a static_contract_failure_names=()

  run_static_contract() {
    local name="$1"
    shift
    if ! "$@"; then
      echo "SABLE_LOCAL_CI_STATIC_CONTRACT_FAILURE=$name"
      static_contract_failure_names+=("$name")
      static_contract_failures=$((static_contract_failures + 1))
    fi
  }

  run_static_contract sable-pipeline \
    bash "$ROOT/build/gates/sable-pipeline-contract.sh"
  run_static_contract n1d-local-ci-scope \
    bash "$ROOT/build/gates/n1d-local-ci-scope-contract.sh"

  if [[ "$SABLEOS_DEVICE" == panther && "$SABLEOS_RELEASE_VERSION" == R9 ]]; then
    run_static_contract r8-build-driver \
      bash "$ROOT/build/gates/r8-build-driver-contract.sh"
    run_static_contract r9-physical-remediation \
      python3 "$ROOT/build/gates/r9-physical-remediation-contract.py"
    run_static_contract r9-system-cohesion \
      python3 "$ROOT/build/gates/r9-system-cohesion-contract.py"
    run_static_contract r9-physical-ux-closure \
      python3 "$ROOT/build/gates/r9-physical-ux-closure-contract.py"
    echo "SABLE_LOCAL_CI_PANTHER_R9_STATIC_CONTRACTS=PASS_EXECUTED"
  else
    echo "SABLE_LOCAL_CI_PANTHER_R9_STATIC_CONTRACTS=SKIP device=$SABLEOS_DEVICE release=$SABLEOS_RELEASE_VERSION"
  fi

  if [[ "$SABLEOS_DEVICE" == titan2 && "${SABLEOS_RELEASE_VERSION^^}" == N1B2 ]]; then
    run_static_contract n1b2-canonical-ci \
      bash "$ROOT/build/gates/n1b2-canonical-ci-contract.sh"
    echo "SABLE_LOCAL_CI_TITAN2_N1B2_STATIC_CONTRACTS=PASS_EXECUTED"
  else
    echo "SABLE_LOCAL_CI_TITAN2_N1B2_STATIC_CONTRACTS=SKIP device=$SABLEOS_DEVICE release=$SABLEOS_RELEASE_VERSION"
  fi

  run_static_contract r9-textreader-standalone \
    python3 "$ROOT/build/gates/r9-textreader-standalone-contract.py"
  run_static_contract r9-sms-mms-blocking \
    python3 "$ROOT/build/gates/r9-sms-mms-blocking-contract.py"
  run_static_contract r9-first-party-app-icon \
    python3 "$ROOT/build/gates/r9-first-party-app-icon-contract.py"
  run_static_contract r9-media-flow \
    python3 "$ROOT/build/gates/r9-media-flow-contract.py"
  run_static_contract r9-messages-native-first \
    python3 "$ROOT/build/gates/r9-messages-native-first-contract.py"
  run_static_contract r9-messages-local-conversation \
    python3 "$ROOT/build/gates/r9-messages-local-conversation-contract.py"
  run_static_contract r9-standalone-messages-quality \
    python3 "$ROOT/build/gates/r9-standalone-messages-quality-contract.py"
  run_static_contract r9-messages-source-style \
    python3 "$ROOT/build/gates/r9-messages-source-style.py"
  run_static_contract r8-no-stale-product-code \
    env R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED=NO \
      bash "$ROOT/build/gates/r8-no-stale-product-code.sh"
  run_static_contract r9-sablestart-design-self-test \
    python3 "$ROOT/build/gates/r9-sablestart-design-contract.py" --self-test
  run_static_contract r9-sablestart-design \
    python3 "$ROOT/build/gates/r9-sablestart-design-contract.py"
  if [[ "$SABLEOS_DEVICE" == panther && "$SABLEOS_RELEASE_VERSION" == R9 ]]; then
    run_static_contract r9-launcher3-foundation-self-test \
      python3 "$ROOT/build/gates/r9-launcher3-foundation-contract.py" --self-test
    run_static_contract r9-launcher3-foundation \
      python3 "$ROOT/build/gates/r9-launcher3-foundation-contract.py"
  else
    echo "SABLE_LOCAL_CI_R9_LAUNCHER3_FOUNDATION=SKIP device=$SABLEOS_DEVICE release=$SABLEOS_RELEASE_VERSION"
  fi

  if [[ "$static_contract_failures" -ne 0 ]]; then
    local failure_csv
    failure_csv="$(IFS=,; printf '%s' "${static_contract_failure_names[*]}")"
    echo "SABLE_LOCAL_CI_STATIC_CONTRACT_FAILURE_NAMES=$failure_csv"
    echo "SABLE_LOCAL_CI_STATIC_CONTRACTS=FAIL count=$static_contract_failures"
    return 1
  fi
  echo "SABLE_LOCAL_CI_STATIC_CONTRACTS=PASS"
}

run_titan2_n1b2_evidence() {
  local ndk_llvm_bin="$SABLE_ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
  local toolchain_log="$EVIDENCE_DIR/N1I_B_TOOLCHAIN.env"
  local selftest_log="$EVIDENCE_DIR/N1I_B_SELFTEST.log"
  local selftest_table="$EVIDENCE_DIR/N1I_B_SELFTEST_CASES.tsv"
  local tool

  echo "DEVICE_CONTACT_AUTHORIZED=NO"
  echo "ADB_COMMANDS_RUN=NO_REAL_DEVICE"
  echo "FASTBOOT_COMMANDS_RUN=NO"
  echo "FLASH_AUTHORIZED=NO"
  echo "TITAN_CELLULAR_MUTATION_AUTHORIZED=NO"
  echo "NETWORK_FETCH_AUTHORIZED=NO"

  for tool in \
    "$SABLE_JDK17/bin/java" \
    "$SABLE_JDK17/bin/javac" \
    "$SABLE_ANDROID_BUILD_TOOLS/d8" \
    "$SABLE_ANDROID_BUILD_TOOLS/dexdump" \
    "$ndk_llvm_bin/clang" \
    "$ndk_llvm_bin/ld.lld" \
    "$ndk_llvm_bin/llvm-objcopy" \
    "$ndk_llvm_bin/llvm-readelf"
  do
    [[ -x "$tool" ]] || {
      echo "TITAN2_N1B2_EVIDENCE_TOOLCHAIN=FAIL_MISSING path=$tool"
      return 1
    }
  done

  export JAVA_HOME="$SABLE_JDK17"
  export ANDROID_HOME="$SABLE_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
  export PATH="$SABLE_ANDROID_BUILD_TOOLS:$ndk_llvm_bin:$JAVA_HOME/bin:$PATH"

  # Official CI is deliberately pinned to the Sable-managed toolchain. An invalid
  # explicit dx path makes the helper choose D8 instead of a host or workspace dx.
  export N1I_TOOL_DX="$EVIDENCE_DIR/NO_LEGACY_DX"
  export N1I_TOOL_JAVA="$SABLE_JDK17/bin/java"
  export N1I_TOOL_JAVAC="$SABLE_JDK17/bin/javac"
  export N1I_TOOL_D8="$SABLE_ANDROID_BUILD_TOOLS/d8"
  export N1I_TOOL_DEXDUMP="$SABLE_ANDROID_BUILD_TOOLS/dexdump"
  export N1I_TOOL_CLANG="$ndk_llvm_bin/clang"
  export N1I_TOOL_LD_LLD="$ndk_llvm_bin/ld.lld"
  export N1I_TOOL_LLVM_OBJCOPY="$ndk_llvm_bin/llvm-objcopy"
  export N1I_TOOL_READELF="$ndk_llvm_bin/llvm-readelf"

  python3 "$ROOT/tests/titan2/n1i-b/lib/toolchain.py" | tee "$toolchain_log"

  grep -Fxq 'N1I_B_TOOL_DEX_COMPILER_KIND=d8' "$toolchain_log" || {
    echo "TITAN2_N1B2_EVIDENCE_TOOLCHAIN=FAIL_DEX_COMPILER"
    return 1
  }
  for expected in \
    "N1I_B_TOOL_D8=$SABLE_ANDROID_BUILD_TOOLS/d8" \
    "N1I_B_TOOL_DEXDUMP=$SABLE_ANDROID_BUILD_TOOLS/dexdump" \
    "N1I_B_TOOL_JAVA=$SABLE_JDK17/bin/java" \
    "N1I_B_TOOL_JAVAC=$SABLE_JDK17/bin/javac" \
    "N1I_B_TOOL_CLANG=$ndk_llvm_bin/clang" \
    "N1I_B_TOOL_LD_LLD=$ndk_llvm_bin/ld.lld" \
    "N1I_B_TOOL_LLVM_OBJCOPY=$ndk_llvm_bin/llvm-objcopy" \
    "N1I_B_TOOL_READELF=$ndk_llvm_bin/llvm-readelf"
  do
    grep -Fxq "$expected" "$toolchain_log" || {
      echo "TITAN2_N1B2_EVIDENCE_TOOLCHAIN=FAIL_UNPINNED expected=$expected"
      return 1
    }
  done
  echo "TITAN2_N1B2_EVIDENCE_TOOLCHAIN=PASS_CANONICAL"

  set +e
  bash "$ROOT/tests/titan2/n1i-b/run-selftests.sh" --table "$selftest_table" \
    2>&1 | tee "$selftest_log"
  local selftest_rc=${PIPESTATUS[0]}
  set -e

  [[ "$selftest_rc" -eq 0 ]] || {
    echo "TITAN2_N1B2_EVIDENCE_SELFTESTS=FAIL rc=$selftest_rc"
    return "$selftest_rc"
  }

  for marker in \
    'READ_ONLY_GUARD_TESTS=PASS' \
    'SANITIZER_FIXTURE_TESTS=PASS' \
    'TIMELINE_B0_APN_TESTS=PASS' \
    'N1I_STATIC_DEXDUMP_ORACLE=PASS' \
    'MEMBER_RESOLVER_TESTS=PASS' \
    'NATIVE_DATAFLOW_TESTS=PASS' \
    'REVERSE_CENSUS_TESTS=PASS' \
    'EVIDENCE_LEDGER_TESTS=PASS' \
    'SELFTEST_FAILED=0' \
    'SELFTEST=PASS'
  do
    grep -Fxq "$marker" "$selftest_log" || {
      echo "TITAN2_N1B2_EVIDENCE_SELFTESTS=FAIL_MISSING marker=$marker"
      return 1
    }
  done
  grep -Eq '^SELFTEST_CASES=[1-9][0-9]*$' "$selftest_log" || {
    echo "TITAN2_N1B2_EVIDENCE_SELFTESTS=FAIL_CASE_COUNT"
    return 1
  }

  echo "TITAN2_N1B2_EVIDENCE_SELFTESTS=PASS"
  echo "TITAN2_N1B2_IMPORT_AUTHORIZED=NO"
  echo "TITAN2_N1B2_DEVICE_MUTATION_AUTHORIZED=NO"
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
  export CARGO_HOME="$SABLE_CARGO_HOME"
  export RUSTUP_HOME="$SABLE_RUSTUP_HOME"
  export CARGO="$SABLE_CARGO"
  export RUSTC="$SABLE_RUSTC"
  export PATH="$SABLE_RUST_TOOLCHAIN_ROOT/bin:$SABLE_CARGO_HOME/bin:$JAVA_HOME/bin:$PATH"

  (
    cd "$ROOT/apps/r8/android"
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       :design:testDebugUnitTest       :hub:testDebugUnitTest       :messages:testDebugUnitTest       :sablestart-presentation-check:compileDebugKotlin        :calculator:assembleDebug       :games:assembleSudokuDebug       :games:assembleMinesweeperDebug       :games:assembleGame2048Debug       :media:assembleDebug       :hub:assembleDebug       :messages:assembleDebug       :weather:assembleDebug       :calendar:assembleDebug       :design:lintDebug       :calculator:lintDebug       :convert:lintDebug       :games:lintSudokuDebug       :games:lintMinesweeperDebug       :games:lintGame2048Debug       :media:lintDebug       :hub:lintDebug       :messages:lintDebug       :weather:lintDebug       :calendar:lintDebug       :sablestart-presentation-check:lintDebug        --stacktrace --console=plain --no-daemon
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

  local android_quality_rc=0
  (
    set -euo pipefail
    cd "$ROOT/apps/r8/android"
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       :design:detekt       :calculator:detekt       :convert:detekt       :games:detekt       :media:detekt       :hub:detekt       :messages:detekt       :weather:detekt       :calendar:detekt       :design:ktlintCheck       :calculator:ktlintCheck       :convert:ktlintCheck       :games:ktlintCheck       :media:ktlintCheck       :hub:ktlintCheck       :messages:ktlintCheck       :weather:ktlintCheck       :calendar:ktlintCheck       :design:koverXmlReportDebug       :design:koverHtmlReportDebug       --stacktrace --console=plain --no-daemon
  ) || android_quality_rc=$?

  if [[ "$android_quality_rc" -ne 0 ]]; then
    echo "SABLE_LOCAL_CI_QUALITY_ANDROID=FAIL rc=$android_quality_rc"
    return "$android_quality_rc"
  fi
  echo "SABLE_LOCAL_CI_QUALITY_ANDROID=PASS"

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
    "$ROOT/apps/r8/android/weather/build/outputs/apk/debug/weather-debug.apk"
    "$ROOT/apps/r8/android/calendar/build/outputs/apk/debug/calendar-debug.apk"
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

  test "$(grep -c '^===== ' "$EVIDENCE_DIR/R8_APK_SEALS.txt")" -eq 8
  for pkg in     org.sableos.calculator     org.sableos.media     org.sableos.sudoku     org.sableos.minesweeper     org.sableos.game2048     org.sableos.hub     org.sableos.weather     org.sableos.calendar
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

  python3 "$ROOT/apps/r8/textreader/apply_sable_flavor.py" "$work"
  python3 "$ROOT/apps/r8/textreader/verify_sable_textreader.py" "$work"

  export JAVA_HOME="$SABLE_JDK17"
  export ANDROID_HOME="$SABLE_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
  export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
  (
    cd "$work"
    chmod +x gradlew
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}" \
      testDebugUnitTest \
      lintDebug \
      assembleDebug \
      --stacktrace --console=plain --no-daemon --no-configuration-cache

    mapfile -t apks < <(
      find app/build/outputs/apk/debug \
        -maxdepth 1 -type f -name 'SableTextReader-*.apk' -print | sort
    )
    [[ "${#apks[@]}" -eq 1 ]] || {
      echo "SABLE_TEXT_READER_APK=FAIL_COUNT count=${#apks[@]}"
      return 1
    }

    APKANALYZER="$SABLE_APKANALYZER" \
      python3 "$ROOT/apps/r8/textreader/verify_sable_textreader.py" \
        "$work" "${apks[0]}"
    sha256sum "${apks[0]}" > "$EVIDENCE_DIR/textreader-apk-seal.txt"
  )
}

run_reader() {
  source "$ROOT/apps/r8/reader/upstream.env"
  local reader="$CACHE_ROOT/vaachak-reader"
  mkdir -p "$CACHE_ROOT"

  clone_pinned "$VAACHAK_REPOSITORY" "$VAACHAK_COMMIT" "$reader"

  python3 "$ROOT/apps/r8/reader/apply_sable_flavor.py" "$reader"

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

if [[ "$SABLEOS_DEVICE" == titan2 && "${SABLEOS_RELEASE_VERSION^^}" == N1B2 ]]; then
  stage TITAN2_N1B2_EVIDENCE run_titan2_n1b2_evidence
else
  echo "SABLE_LOCAL_CI_TITAN2_N1B2_EVIDENCE=SKIP device=$SABLEOS_DEVICE release=$SABLEOS_RELEASE_VERSION"
fi

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
  echo "===== SOURCE-BOUND VISUAL ACCEPTANCE ====="
  python3 "$ROOT/build/gates/r9-launcher-visual-acceptance.py"
  echo "SABLE_LOCAL_CI_STAGE_VISUAL_ACCEPTANCE=PASS"

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
sable_checkpoint_pass "Local CI $PROFILE complete for $SOURCE_COMMIT"
 "$selftest_log" || {
    echo "TITAN2_N1B2_EVIDENCE_SELFTESTS=FAIL_CASE_COUNT"
    return 1
  }

  echo "TITAN2_N1B2_EVIDENCE_SELFTESTS=PASS"
  echo "TITAN2_N1B2_IMPORT_AUTHORIZED=NO"
  echo "TITAN2_N1B2_DEVICE_MUTATION_AUTHORIZED=NO"
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
  export CARGO_HOME="$SABLE_CARGO_HOME"
  export RUSTUP_HOME="$SABLE_RUSTUP_HOME"
  export CARGO="$SABLE_CARGO"
  export RUSTC="$SABLE_RUSTC"
  export PATH="$SABLE_RUST_TOOLCHAIN_ROOT/bin:$SABLE_CARGO_HOME/bin:$JAVA_HOME/bin:$PATH"

  (
    cd "$ROOT/apps/r8/android"
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       :design:testDebugUnitTest       :hub:testDebugUnitTest       :messages:testDebugUnitTest       :sablestart-presentation-check:compileDebugKotlin        :calculator:assembleDebug       :games:assembleSudokuDebug       :games:assembleMinesweeperDebug       :games:assembleGame2048Debug       :media:assembleDebug       :hub:assembleDebug       :messages:assembleDebug       :weather:assembleDebug       :calendar:assembleDebug       :design:lintDebug       :calculator:lintDebug       :convert:lintDebug       :games:lintSudokuDebug       :games:lintMinesweeperDebug       :games:lintGame2048Debug       :media:lintDebug       :hub:lintDebug       :messages:lintDebug       :weather:lintDebug       :calendar:lintDebug       :sablestart-presentation-check:lintDebug        --stacktrace --console=plain --no-daemon
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

  local android_quality_rc=0
  (
    set -euo pipefail
    cd "$ROOT/apps/r8/android"
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}"       :design:detekt       :calculator:detekt       :convert:detekt       :games:detekt       :media:detekt       :hub:detekt       :messages:detekt       :weather:detekt       :calendar:detekt       :design:ktlintCheck       :calculator:ktlintCheck       :convert:ktlintCheck       :games:ktlintCheck       :media:ktlintCheck       :hub:ktlintCheck       :messages:ktlintCheck       :weather:ktlintCheck       :calendar:ktlintCheck       :design:koverXmlReportDebug       :design:koverHtmlReportDebug       --stacktrace --console=plain --no-daemon
  ) || android_quality_rc=$?

  if [[ "$android_quality_rc" -ne 0 ]]; then
    echo "SABLE_LOCAL_CI_QUALITY_ANDROID=FAIL rc=$android_quality_rc"
    return "$android_quality_rc"
  fi
  echo "SABLE_LOCAL_CI_QUALITY_ANDROID=PASS"

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
    "$ROOT/apps/r8/android/weather/build/outputs/apk/debug/weather-debug.apk"
    "$ROOT/apps/r8/android/calendar/build/outputs/apk/debug/calendar-debug.apk"
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

  test "$(grep -c '^===== ' "$EVIDENCE_DIR/R8_APK_SEALS.txt")" -eq 8
  for pkg in     org.sableos.calculator     org.sableos.media     org.sableos.sudoku     org.sableos.minesweeper     org.sableos.game2048     org.sableos.hub     org.sableos.weather     org.sableos.calendar
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

  python3 "$ROOT/apps/r8/textreader/apply_sable_flavor.py" "$work"
  python3 "$ROOT/apps/r8/textreader/verify_sable_textreader.py" "$work"

  export JAVA_HOME="$SABLE_JDK17"
  export ANDROID_HOME="$SABLE_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
  export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
  (
    cd "$work"
    chmod +x gradlew
    ./gradlew "${GRADLE_NETWORK_ARGS[@]}" \
      testDebugUnitTest \
      lintDebug \
      assembleDebug \
      --stacktrace --console=plain --no-daemon --no-configuration-cache

    mapfile -t apks < <(
      find app/build/outputs/apk/debug \
        -maxdepth 1 -type f -name 'SableTextReader-*.apk' -print | sort
    )
    [[ "${#apks[@]}" -eq 1 ]] || {
      echo "SABLE_TEXT_READER_APK=FAIL_COUNT count=${#apks[@]}"
      return 1
    }

    APKANALYZER="$SABLE_APKANALYZER" \
      python3 "$ROOT/apps/r8/textreader/verify_sable_textreader.py" \
        "$work" "${apks[0]}"
    sha256sum "${apks[0]}" > "$EVIDENCE_DIR/textreader-apk-seal.txt"
  )
}

run_reader() {
  source "$ROOT/apps/r8/reader/upstream.env"
  local reader="$CACHE_ROOT/vaachak-reader"
  mkdir -p "$CACHE_ROOT"

  clone_pinned "$VAACHAK_REPOSITORY" "$VAACHAK_COMMIT" "$reader"

  python3 "$ROOT/apps/r8/reader/apply_sable_flavor.py" "$reader"

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
  echo "===== SOURCE-BOUND VISUAL ACCEPTANCE ====="
  python3 "$ROOT/build/gates/r9-launcher-visual-acceptance.py"
  echo "SABLE_LOCAL_CI_STAGE_VISUAL_ACCEPTANCE=PASS"

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
sable_checkpoint_pass "Local CI $PROFILE complete for $SOURCE_COMMIT"
