# N1I-D1R4-CW1 compiled milestone (engineering checkpoint)

Date: 2026-10-11. Status: **PASS_COMPILED_AND_DEX_DEFINITIONS / LINKAGE_AND_SEMANTICS_UNPROVEN**. Draft-only; not a production release or authorization to flash.

## Observed ai-g732 results (operator-reported)
- Isolated build: `CW1_BUILD_RC=0`, `CW1_COMPILE=PASS`.
- DEX verification: `CW1_DEX=PASS_EXACT_DEX_DEFINITIONS_SEMANTICS_UNPROVEN`, `CW1_VERIFY=PASS`.
- Expected CW1 methods: protected `GsmCdmaCallTracker.handleCallWaitingInfo(CdmaCallWaitingNotification)`, protected call-waiting factory `onCreateGsmCdmaConnection(...)`, private `notifyCallWaitingInfo(...)`, and the `GsmCdmaConnection` call-waiting constructor.
- Original C3B telephony worktree was clean and both source file pins matched before staging. Build conducted in independent checkout using Bubblewrap with an isolated network namespace.
- Protected N1D/C3B source preservation was qualified in earlier tests; final full-workspace audit is **not included** in this checkpoint.

## Provenance pins
- Original `GsmCdmaCallTracker.java` SHA-256: `a57fbf4a4584b766a2b5eeab0dd88f0bf64ef644b2aec059ceb49bb8dee18ee8`
- Original `GsmCdmaConnection.java` SHA-256: `026f9dd8f4661265e8ae19a85a492901bdd250850796f7472b1de2b2ffa4b6cf`
- CW1 45-line two-file patch SHA-256: `4d2ad6b567ca725e8cc45c0362cdd788e3425c668592241aa4da007aa019635d`
- Original patch: `/srv/data/sable-build/evidence/titan2/n1i-d1r4-callwaiting-preview-v2/D1R4_CALLWAITING_SOURCE_PREVIEW.patch`
- Staged patched sources: `/srv/data/sable-build/evidence/titan2/n1i-d1r4-cw1-compile-handoff-v1/patched-source-only/`
- Source workspace: `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android`
- Lunch target: `sable_titan2-bp4a-userdebug`; module: `telephony-common`
- Build output: `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android/out_cw1`
- DEX jar: `out_cw1/soong/.intermediates/frameworks/opt/telephony/telephony-common/android_common/dex/telephony-common.jar`
- Build log: `/srv/data/sable-build/evidence/titan2/n1i-d1r4-cw1-compile-v2/BUILD.log`
- Build result: `/srv/data/sable-build/evidence/titan2/n1i-d1r4-cw1-compile-v2/BUILD_RESULT.json`
- DEX report: `/srv/data/sable-build/evidence/titan2/n1i-d1r4-cw1-compile-v2/dex-verify/SUMMARY.json`

**The compiled jar, raw build log, original patch, and DEX report are NOT embedded in this GitHub checkpoint.** They remain on ai-g732. Their post-build SHA-256 values have not been independently collected through this GitHub operation. Do not interpret this document as evidence that these bytes were uploaded to GitHub.

## ABI boundary
- Previously recorded D1R2 inventory: 172 unique ABI gaps (9 classes, 142 methods, 21 fields) against the candidate Android 16 framework. CW1 is one bounded repair, **not closure of all 172 gaps**.
- Method definitions exist in the rebuilt DEX; exact stock MediaTek consumer `invoke-super` accessibility and hierarchy validation are **PENDING**.
- No semantics or runtime telephony/IMS evidence is claimed.
- Device contact, reboot, and flash remain **NOT AUTHORIZED** by this checkpoint.

## Next gates
1. Produce a reproducible `SHA256SUMS`/manifest directly on ai-g732 for the patch, source versions, DEX JAR, result JSON and log; record source commits and artifact sizes.
2. Verify the exact stock `MtkGsmCdmaCallTracker` consumer `invoke-super` against compiled method access, superclass chain and class duplication; negative regression tests.
3. In parallel, compare [AtlasOS Titan 2](https://github.com/Abyss-c0re/atlasos) IMS and incoming-call changes with stock firmware and SableOS. Do not import patches or recovery scripts unreviewed.
4. Carry out runtime calling/IMS/SIM tests only under new device/flash authority.

## Publication policy
Do not merge this checkpoint as production readiness; no proprietary OEM binaries or full Android build outputs in source control. Preserve `out_cw1` for incremental builds; do not run clean/clobber.
