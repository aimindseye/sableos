# PR #342 — A1V actual service-context HOLD and A1W exact two-file SELinux correction handoff

**Date:** 2026-10-14. **PR status:** open/draft/unmerged. **User request:** next deliverable, prior SableOS chats/PR/repos reviewed first, syntax and performance validated. **Scope:** isolated Titan 2 A1 Android 16 and the already successfully built host-only image. **No device, super, fastboot, flash or production release authorization.**

## Actual ai-g732 A1V outcome — do not overstate

- A1V outer ZIP, 7 member checksums, Python/Bash syntax and 17/17 hermetic tests: PASS.
- Real pinned `system.img`: SHA256 **`82ceeaf2a96ff4aaf29f684cf91e04a97e15d7ab1955d1e9c3394e244c116762`**, byte length **`3210473472`**: PASS. A1U previously built **180378/180378** steps in **02:37:15**; original A1T rc1 remains preserved, subsequent A1U rc0 remains preserved.
- **15 required PRODUCT_OUT files were present, regular, and SHA256-computed/checked PASS**: C3B five Sable APKs, C1 IMS APK, both Mediatek JARs, three XMLs, bootclasspath protobuf, cellular-MVP marker, compiled property_contexts and compiled service_contexts.
- A1V **STOPPED** at `compiled_service_contexts_missing_slot1`. Built `system_ext_service_contexts`: **861 bytes**, SHA256 `834e74ac701a3cd56dbcc8861060e383fda9f7d73ff8778bbd2e940502369b1b`. A1V returned **`HOLD_NOT_FULLY_VERIFIED`**, `image_members={}`. As it short-circuited there, **actual image-internal hashes, APK identities, IMS shared-UID and platform-signing equality remain NOT EXECUTED** by A1V; DO NOT claim fully qualified.
- This is **not** the operator-declared nonblocking Ubuntu `nsjail` or `mkdir: '/system': Permission denied` host diagnostic.

## Confirmed source composition gap, not another unknown graph issue

Prior SableOS engineering chats show A1K staged C1 product MK/marker, A1L staged C1 `property_contexts`, and A1P staged derived `property.te`. None staged C1 `service_contexts` or `radio.te`. Canonical main branch `product/titan2/n1i-c1/sepolicy/system_ext/private/` consists of `property_contexts` plus:

1. `radio.te`: exact Git blob SHA1 `29ea19317187ac6c0b096eaaf281f3a1f87128c1`, full SHA256 `bdb8b7668aa4509ea4ce32d9a410279684fd86189d2d133d39f2f822cca4d2fd`, 298 bytes.
2. `service_contexts`: exact Git blob SHA1 `97042a421548ea3a2a5200cc009b06595c3c7583`, full SHA256 `ee5d81d2ce6a25b4e8260ad49fe076e917959de00ea95840369f80ba7e915e5c`, 2357 bytes. Includes both `vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/slot1` and `.../slot2` mappings.

Canonical C1 makefile `product/titan2/n1i-c1/sable-titan2-n1i-c1.mk` already declares `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += vendor/sable/titan2/n1i-c1/sepolicy/system_ext/private`. Do not edit the makefile or directly patch compiled output. The source omission is the best-supported explanation for A1V's actual HOLD; host compilation of both newly staged files and complete renewed A1V verification remain unproven.

## A1W V1 sealed deliverable, NOT YET EXECUTED ON ai-g732

Archive `N1F_P342_A1W_EXACT_C1_SELINUX_INCREMENTAL_SYSTEMIMAGE_V1.zip`, size **19061 bytes**, SHA256 **`1f8613ca0859606816833e1aa2d5dedef10dd82a3a0e95686cf0d710c06e3541`**. 11 ZIP entries (10 SHA-sealed plus `SHA256SUMS.txt`). Python `n1f_p342_a1w_exact_policy_v1.py` SHA256 `f991bf3bcec9089625a2311148ed7c6cb1c0c0c627c4eb1458475fe2b6e99ae4`; Bash `n1f_p342_a1w_one_command_v1.sh` SHA256 `b2c364f447b13e06a8b1e607b677c6c77a4be0217acfc61a62232f0640fe94ac`. Source blobs are included in ZIP with BOTH exact blob and SHA checks, no network needed.

Read-only entrypoint after outer SHA and fresh unzip:

```bash
bash ./n1f_p342_a1w_one_command_v1.sh --preflight
```

This checks pre-existing source paths absent, original receipts including preserved incomplete A1S, prior A1T failed rc1 / A1U successful rc0, original full image SHA/size, C1 makefile policy dir, previously staged property files, and canonical bundled source blobs. It makes no new A1 evidence, no source/build writes.

A **SEPARATELY EXPLICIT TWO-FILE SOURCE-MUTATION + INCREMENTAL HOST-BUILD AUTHORIZATION** is required before running the following *gated future action*; the user's current request for a deliverable is not treated as automatic authorization to change source:

```bash
bash ./n1f_p342_a1w_one_command_v1.sh --apply \
  --authorize-a1w-two-canonical-policy-files-and-incremental-host-image
```

That one-use action first reserves `.A1W_C1_EXACT_POLICY_INCREMENTAL_SYSTEMIMAGE_V1`, then copies original image to `PRE_A1W_SYSTEM_IMG.img` using `cp --reflink=auto --sparse=always` (not a hardlink), independently verifies exact old SHA and 3210473472 bytes **BEFORE any source write**, then O_EXCL/no-follow creates **only** canonical `radio.te` and `service_contexts`. Snapshot can require full 3.21GB copy/disk if filesystem cannot reflink. On snapshot failure, preserve incomplete one-use evidence and no source writes. Reuses existing A1T out to run **one** `make -j8 systemimage` with `set -eo pipefail` inside Android shell; stores own log, rc, then requires BOTH compiled IMS slot mappings and changed image SHA to report **`A1W_IMAGE_BUILD=PASS_HOST_ONLY_POLICY_UPDATED`**. Preserves old A1T/A1U/A1S evidence, original incomplete marker, and no out-a1. No clean/clobber, stock extraction, Git, repo sync, TrebleApp rebuild, network fetch, device, super, reboot, or flash. Failures remain one-use with no automatic retry/cleanup.

Successful A1W is NOT device readiness. The original A1V image SHA is obsolete after A1W image changes; must use an updated pinned **full read-only postbuild verification** on new bytes, and separate G1/G2/G3 policy before any flash request.

## Syntax, regression, performance QA

- Local ZIP CRC PASS, all **10/10 SHA256 manifest entries PASS** on exact archive, Python AST and compile **3/3 PASS**, Bash `bash -n` PASS.
- **26/26 hermetic tests PASS under umask077 and umask022**, including **fresh extracted sealed ZIP 26/26 both umasks**.
- Tests include complete synthetic preflight/image pins/receipts, nofollow parent and leaf, wrong policy/receipt, source hash tampering, all-or-nothing snapshot before source mutation, exact exclusive two-file staging/no rerun; 4 real Bash-wrapper end-to-end simulations, success+rc7 failure under both umasks. Both hardcoded A1 paths rewritten in tested executable copies, assert original production A1 paths absent; tests NEVER invoke real production `main(stage)` or build. Corrects A1S historical non-hermetic test weakness.
- Synthetic preflight (tiny image, 101 iterations): median **0.6185 ms**, p95 **0.9613 ms**. Synthetic ~4MiB file hash (30 iterations): median **2.6293 ms**, p95 **2.9047 ms**. **Not** an actual ai-g732 3.21GB snapshot, full-systemimage rebuild, or I/O performance benchmark.
- **A1W REAL HOST NOT EXECUTED**, no new policy-staged/built image asserted.

```text
A1U_BUILD=ACTUAL_PASS_3210473472_SHA_82ceeaf2
A1V_TREE_MEMBERS=ACTUAL_PASS_15
A1V_SELINUX_SERVICE_SLOT1=ACTUAL_FAIL
A1V_IMAGE_INTERNAL=NOT_EXECUTED
A1W_LOCAL=PASS_ARCHIVE_SHA10_AST3_BASH_TEST26_BOTH_UMASKS
A1W_REAL=NOT_EXECUTED_NO_SOURCE_MUTATION
IMAGE_DEVICE_FLASH_READY=NO
```
