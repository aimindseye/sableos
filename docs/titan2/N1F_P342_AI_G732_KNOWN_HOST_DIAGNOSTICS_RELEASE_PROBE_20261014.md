# PR #342 — ai-g732 Ubuntu host diagnostic classification and confirmed A1 release probe

**Date:** 2026-10-14 (America/New_York)
**Authority:** operator-provided actual ai-g732 terminal output and repeated successful historical SableOS build experience. Scoped to the Titan 2 A1 engineering lane and this build host; not an assertion that all messages with similar words are safe.

## Actual release result

After A1P 12 source payload/policy leaves PASS, A1Q three Git alternate object stores PASS independent, A1R 61 generated product leaves PASS and its `m -j4 nothing` Android graph subprocess returned exit code zero, A1S one-use attempt remained historically incomplete because its **own** Bash `set -u` launcher failed before `lunch` (`build/envsetup.sh: line 26: TOP: unbound variable`). A separately executed, non-mutating host-only shell release probe used `set -eo pipefail`, confirmed the A1S incomplete receipt/marker/absent out-a1, and executed Android `envsetup.sh` and `lunch` in the existing A1R config-only out tree.

**Actual ai-g732 output:**

```text
===== CONFIRM PRESERVED A1S STATE =====
A1S_PRESERVED_STATE=PASS
===== VERIFY ANDROID SHELL RELEASE — NO IMAGE BUILD =====
11:06:43 Build sandboxing disabled due to nsjail error.
mkdir: '/system': Permission denied
mkdir: '/system': Permission denied
TARGET_PRODUCT=treble_arm64_bvN
TARGET_RELEASE=bp4a
TARGET_BUILD_VARIANT=user
A1_RELEASE_PROBE=PASS_NO_IMAGE_BUILD
```

**Finding:** The real post-`lunch` shell variables equal the three exact required engineering targets. The previously empty `get_build_var TARGET_RELEASE` in A1R is not a real release mismatch. This independent probe resolves the shell release identity question. **Do not rewrite the original A1S receipt as PASS**; it truthfully remains `INCOMPLETE_A1S_PRESERVE_RELEASE_EVIDENCE`. The standalone probe is independent evidence, not a replacement/cleanup of consumed one-use A1S state.

## Known non-blocking ai-g732 Ubuntu host messages — retain but do not fail on these alone

The operator explicitly confirms these exact lines appear during earlier successful SableOS builds on this Ubuntu host, without preventing correct compilation. Record these as **KNOWN_HOST_DIAGNOSTIC_NONBLOCKING**, **only when the surrounding command reaches its independently required successful completion**:

```text
Build sandboxing disabled due to nsjail error.
mkdir: '/system': Permission denied
```

The `mkdir` line may occur more than once. Keep the lines in logs for provenance; do not classify them as a new blocker, source deficiency, missing output, reason to reinstall tooling, or new A1 prebuild gate. **Do not modify the host to suppress diagnostics.**

### Important safety and scope

- This is a **message-specific** classification, not permission to ignore other warnings/errors or actual failing exit statuses.
- The lack of build sandboxing must remain visible as a host-environment security limitation; the operator's successful-build precedent makes it nonblocking for this **Titan 2 host engineering qualification**, not proof of full sandbox enforcement or production hardening.
- If the Android command fails, required product variables differ, a required module is absent, generated output is missing/incorrect, SELinux/image checks fail, or any network/device/flash/partition side effect occurs, **FAIL or HOLD** as usual. Do not filter those problems based on the presence of these known lines.
- This Titan 2-specific exception is **not** permission to override other device/lane security gates. For example, the existing `build/panther/build-r8-final-ui.sh` explicitly treats the nsjail line as fatal for that separate product; do not silently change Panther policy.
- Preserve `.A1_INCOMPLETE_DO_NOT_BUILD`, all A1P/A1Q/A1R receipts, A1S historical incomplete receipt, and absence of `out-a1` until a separately authorized and qualified host-only image build driver deliberately stages output.
- The successful graph and shell probe qualify **consideration of a controlled host-only engineering `systemimage` build**, not completion of an image, production release, or authorization to contact/reboot/flash Titan 2 hardware.

## Updated engineering status

```text
A1P_SOURCE_PAYLOAD_AND_POLICY=ACTUAL_PASS_12
A1Q_GIT_OBJECT_INDEPENDENCE=ACTUAL_PASS_3
A1R_GENERATED_PRODUCT=ACTUAL_PASS_61
A1R_ANDROID_M_NOTHING=PASS_EXIT_0
A1S_ORIGINAL_ONE_USE_RECEIPT=INCOMPLETE_HISTORICAL_PRESERVE
INDEPENDENT_A1_RELEASE_PROBE=PASS_PRODUCT_RELEASE_VARIANT
AI_G732_NSJAIL_LINE=NONBLOCKING_KNOWN_HOST_DIAGNOSTIC
AI_G732_MKDIR_SYSTEM_PERMISSION_LINE=NONBLOCKING_KNOWN_HOST_DIAGNOSTIC
ANDROID_SYSTEMIMAGE=NOT_EXECUTED
DEVICE=NO SUPER=NO FLASH=NO
```
