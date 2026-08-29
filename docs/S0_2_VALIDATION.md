# S0.2 Android 14 source-sync validation

Status: **PASS**

## Baseline

- Device: Google Pixel 4a (5G), codename `bramble`
- AOSP tag: `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Product: `aosp_bramble`
- Output directory reserved for S0: `out_s0`

## Transition evidence

The Android 12/B2 workspace was frozen before retagging, including the pinned manifest, repo status, tracked local diffs, untracked-file inventory, complete `device/sable` source snapshot, local Git state, and B2 evidence hashes.

The live Android-12 `device/sable` nested Git repository was moved outside the AOSP worktree before retag/sync and remains preserved under `/srv/data/sableos_source_hold/`.

Rebuildable Android-12 output trees (`out`, `out_b1`, `out_b11`, `out_b2`) were removed only after the freeze verified cleanly. The `.repo` object store was retained and reused for the Android-14 sync.

## Sync gate

Observed:

- `S0_2_REPO_SYNC_RC=0`
- `S0_2_REPO_SYNC_GATE=PASS`
- `S0_2_ANDROID14_SYNC=PASS`

## Identity gate

Observed after sync:

- `TARGET_PRODUCT=aosp_bramble`
- `OUT_DIR=out_s0`
- `BUILD_ID=UP1A.231105.001.B2`
- `S0_2_PRODUCT_GATE=PASS`
- `S0_2_BUILD_ID_GATE=PASS`
- `S0_2_VANILLA_SABLE_ABSENT=PASS`
- `S0_2_HELD_SABLE_REPO=PASS`
- `S0_2_ANDROID14_SYNC_VERIFY=PASS`

The Android-14 worktree is therefore a vanilla bramble baseline with Sable source intentionally absent until the vanilla S0.0 build/boot baseline is established.

## Storage after sync

- AOSP bramble workspace: approximately 238 GiB
- `/srv/data` available space: approximately 541 GiB

## Next gate

S0.3 installs the matching official Google and Qualcomm proprietary binaries for `UP1A.231105.001.B2`, then performs a completely vanilla Android-14 `aosp_bramble-userdebug` build. No Sable source is restored before that gate passes.
