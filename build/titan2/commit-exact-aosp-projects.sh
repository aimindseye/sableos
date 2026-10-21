#!/usr/bin/env bash
# AOSP project commits of already-compiled Phase13 plus Launcher HOME/product glue.
# Source-only: no builds, image, device, flash, resets, network or destructive clean.
set -euo pipefail
ANDROID="${SABLE_TB2_ANDROID_ROOT:-/srv/sable-build/workspaces/titan2-track-b/android}"
MODE="${1:---plan}"
ACK="${2:-}"
[[ "$MODE" == --plan || "$MODE" == --commit || "$MODE" == --preflight ]] || { echo 'TB2_COMMIT=HOLD_MODE'; exit 64; }
if [[ "$MODE" == --commit && "$ACK" != COMMIT_EXACT_TB2_A16_SOURCE_ONLY ]]; then
  echo 'TB2_COMMIT=HOLD_EXPLICIT_ACK'; exit 78
fi
[[ -d "$ANDROID/.repo" ]] || { echo 'TB2_COMMIT=HOLD_AOSP_MANIFEST'; exit 66; }
# Four repo-managed projects, three existing compiled native owners plus product config.
projects=(frameworks/base packages/apps/Dialer packages/apps/Launcher3 device/phh/treble)
heads=(68987f742a5c810a418465610ae6be8f789d6451 6420032cfcab41a1547bcabb0da73bb0894d2c21 a22dcd457286f15f1ab1733bd3eb14a9386e0be4 0a74b582f445afc68fbc1f24280c514354601a54)
branches=(tb2-20261021-native-systemui tb2-20261021-native-dialer tb2-20261021-launcher-recents tb2-20261021-product-graph)
files_fw=(packages/SystemUI/src/com/android/keyguard/KeyguardPinBasedInputView.java packages/SystemUI/src/com/android/keyguard/KeyguardPinBasedInputViewController.java packages/SystemUI/src/com/android/keyguard/sable/SableTitanPinKeys.java)
files_dialer=(java/com/android/dialer/app/res/values/sable_strings.xml java/com/android/dialer/app/res/xml/sound_settings.xml java/com/android/dialer/sable/SableTitanInCallKeys.java java/com/android/incallui/InCallActivity.java)
files_launcher=(AndroidManifest.xml)
files_product=(rom.mk)
paths=(
  frameworks/base/packages/SystemUI/src/com/android/keyguard/KeyguardPinBasedInputView.java
  frameworks/base/packages/SystemUI/src/com/android/keyguard/KeyguardPinBasedInputViewController.java
  frameworks/base/packages/SystemUI/src/com/android/keyguard/sable/SableTitanPinKeys.java
  packages/apps/Dialer/java/com/android/dialer/app/res/values/sable_strings.xml
  packages/apps/Dialer/java/com/android/dialer/app/res/xml/sound_settings.xml
  packages/apps/Dialer/java/com/android/dialer/sable/SableTitanInCallKeys.java
  packages/apps/Dialer/java/com/android/incallui/InCallActivity.java
  packages/apps/Launcher3/AndroidManifest.xml
  device/phh/treble/rom.mk
)
sha=(
  f13f1e9b2ce1d2ac7b763ad869bcd5fc7f7f54d15743dc0a14cd81ef63900bb1
  99d676f4a3068bff2aae95d75dcf27356dc4834d38d878591129d0dce318ff20
  c739c24c903c60530e839c834b4b6d79704ff6a136ef90156a6723ae3e1eef96
  62dc3a271dcc8193e8c4daa8dfb1dc8de98fef6a39dd8c4aa193eaf86d696a84
  e092fb6a8674e5e67f78684c62b53fd224ae256886c323fb061c5aa3b4a77c12
  39078c2bb3f1242d00d2b461649f77390ea7b810f62d87b1da9b395c6f3d1243
  f555c90b56fb3b777a4297b8d7afdb0b012f90a3e6fcd6e7accc3208eff2251c
  904faa32569da62de2f1c2ed774da2f2fc7d3920268720139ada1467cdf72c41
  a5b2f39741018eb7094a68812ce0b03fa080c07f1b2c036ca06c0ab286be1522
)
for i in "${!paths[@]}"; do
  if [[ "$MODE" == --preflight && "$i" -ge 7 ]]; then continue; fi
  p="$ANDROID/${paths[$i]}"
  [[ -f "$p" && ! -L "$p" ]] || { echo "TB2_COMMIT=HOLD_SOURCE_MISSING path=${paths[$i]}"; exit 78; }
  got="$(sha256sum "$p")"; got="${got%% *}"
  [[ "$got" == "${sha[$i]}" ]] || { echo "TB2_COMMIT=HOLD_SOURCE_DRIFT path=${paths[$i]} sha=$got"; exit 78; }
done
# Fail before the first commit if any project is not at the exact source base,
# its Git index is staged, or a target branch name is already in use.
for i in "${!projects[@]}"; do
  p="$ANDROID/${projects[$i]}"
  [[ -d "$p/.git" || -f "$p/.git" ]] || { echo "TB2_COMMIT=HOLD_NOT_GIT project=${projects[$i]}"; exit 78; }
  actual="$(git -C "$p" rev-parse HEAD)"
  [[ "$actual" == "${heads[$i]}" ]] || { echo "TB2_COMMIT=HOLD_HEAD_DRIFT project=${projects[$i]} sha=$actual"; exit 78; }
  git -C "$p" diff --cached --quiet || { echo "TB2_COMMIT=HOLD_INDEX_NOT_EMPTY project=${projects[$i]}"; exit 78; }
  if git -C "$p" show-ref --verify --quiet "refs/heads/${branches[$i]}"; then
    echo "TB2_COMMIT=HOLD_BRANCH_EXISTS project=${projects[$i]}"; exit 78
  fi
done
if [[ "$MODE" == --preflight ]]; then
  echo 'TB2_COMMIT=PREFLIGHT_NATIVE7_AND_FOUR_BASE_HEADS_PASS_NO_WRITES'
  exit 0
fi
if [[ "$MODE" == --plan ]]; then
  echo 'TB2_COMMIT=PASS_FOUR_PROJECT_EXACT_SOURCE_PREFLIGHT_NO_WRITES'
  exit 0
fi
# Explicit authorization: local branches and exact path commits only.
for i in "${!projects[@]}"; do
  p="$ANDROID/${projects[$i]}"
  case "$i" in
    0) selected=("${files_fw[@]}"); label=SystemUI ;;
    1) selected=("${files_dialer[@]}"); label=Dialer ;;
    2) selected=("${files_launcher[@]}"); label=Launcher3 ;;
    3) selected=("${files_product[@]}"); label=Product ;;
  esac
  git -C "$p" switch -c "${branches[$i]}"
  # --only prevents unrelated worktree/index changes from entering the commit.
  git -C "$p" add -- "${selected[@]}"
  git -C "$p" commit --only -m "titan2(tb2): converge $label A16 source from verified Phase13 and retained graph" -- "${selected[@]}"
  printf 'TB2_AOSP_PROJECT_COMMIT\t%s\t%s\n' "${projects[$i]}" "$(git -C "$p" rev-parse HEAD)"
done
echo 'TB2_COMMIT=PASS_4_LOCAL_AOSP_PROJECT_COMMITS_9_EXACT_FILES_NO_BUILD'
