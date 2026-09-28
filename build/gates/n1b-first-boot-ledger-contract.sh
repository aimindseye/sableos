#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/titan2/N1B_FIRST_BOOT_LEDGER_AND_N1B2_HANDOFF.md"

fail() {
  echo "N1B_FIRST_BOOT_LEDGER_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

require_literal() {
  local needle="$1"
  grep -Fq "$needle" "$DOC" || fail "missing marker: $needle"
}

require_file "$DOC"

require_literal "FIRST_N1B_BOOT=PASS"
require_literal "FACTORY_RESET_REQUIRED=YES_CONFIRMED"
require_literal "N1B_PRODUCT_CLOSURE=FAIL"
require_literal "N1B_DAILY_DRIVER=NO"
require_literal "NEXT_WORK=N1B2_PRODUCT_IDENTITY_AND_TITAN_PROFILE_CLOSURE"

require_literal "SYSTEM_SHA256=bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e"
require_literal "SYSTEM_A_AFTER_RESIZE_BYTES=3449815040"
require_literal "SYSTEM_A_POST_FLASH_BYTES=3180666880"
require_literal "FLASH_RESULT=PASS_SYSTEM_A_WRITTEN"

require_literal "DO_NOT_TREAT_SUPER_HEADROOM_AS_IMMEDIATELY_ALLOCATABLE=YES"
require_literal "DO_NOT_TREAT_COW_PARTITIONS_AS_DISPOSABLE_WITHOUT_SNAPSHOT_REVIEW=YES"
require_literal "SNAPSHOT_UPDATE_STATUS=none"
require_literal "USERDATA_POLICY=preserve|explicit-wipe-approved"
require_literal "LP_ACTION=direct-flash|reviewed-resize|reviewed-cow-cleanup-plus-resize"

require_literal "TITANKEY_ENUMERATED=PASS"
require_literal "TOUCHPAD_ENUMERATED=PASS"
require_literal "PRIMARY_DISPLAY=1440x1440"
require_literal "REAR_DISPLAY=410x502"
require_literal "HOME=com.android.launcher3/.uioverrides.QuickstepLauncher"
require_literal "DEVICE_NAME=TrebleDroid vanilla"

require_literal "NO_PIXEL_OR_PANTHER_FLASH_ASSUMPTIONS=YES"
require_literal "NO_IMPLICIT_USERDATA_WIPE=YES"
require_literal "NO_UNREVIEWED_COW_DELETE=YES"
require_literal "NO_UNREVIEWED_LP_RESIZE=YES"
require_literal "NO_RANDOM_VBMETA_OR_AVB_PATCHING=YES"
require_literal "NO_BOOTLOADER_RELOCK=YES"

require_literal "STOCK_IMAGES_ON_AI_G732=AVAILABLE_FOR_PRIVATE_RESTORE_AND_LOCAL_PACKAGING_IF_NEEDED"
require_literal "COMMIT_STOCK_IMAGES_TO_GIT=NO"
require_literal "PUBLIC_RELEASE_WITH_STOCK_BLOBS=NO_UNLESS_SEPARATE_LICENSE_REVIEW"
require_literal "LOCAL_HYBRID_PACKAGING_USE=YES_IF_GATED_AND_NOT_PUBLISHED"

require_literal "N1B_FIRST_BOOT_LEDGER=PASS"
require_literal "N1B2_HANDOFF_RECORDED=PASS"
require_literal "N1B2_BUILD_ALLOWED=YES_AFTER_LEDGER_MERGE"
require_literal "N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED"

echo "N1B_FIRST_BOOT_LEDGER_CONTRACT=PASS"
