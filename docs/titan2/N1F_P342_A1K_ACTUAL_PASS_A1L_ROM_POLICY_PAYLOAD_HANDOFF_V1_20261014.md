# PR342 A1K actual source-stage PASS; A1L ROM / C1 policy and bounded payload review V1

Date: 2026-10-14. Documentation only. User explicitly authorized a host-only Android image build, **not** device, super, reboot or flash. Technical build readiness remains blocked. No image build run.

## A1K actual ai-g732 completed

User-reported JSON `PASS_A1K_FIVE_STATIC_C1_C3B_MARKER_SOURCE_FILES_STAGED_NOT_BUILD_READY`, `created_count=5` and four ancestor directories. Exactly `vendor/sable/titan2/c3b/{Android.bp,sable-titan2-apps.mk}`, `vendor/sable/titan2/n1i-c1/{Android.bp,sable-titan2-n1i-c1.mk,titan2-cellular-mvp}` staged into selected A1. Marker source SHA256 `13ea9199448fb91a85b6fb5806090c6bb7a1201dfb93ae5342c8aa0488551d2f`. C1 proprietary payloads NOT_STAGED, five C3B APKs NOT_STAGED, product graph NOT_EVALUATED; build=false, device=false, flash=false, super=false. **A1K is complete. Do not reapply.** A1F original Oct03 manifest scaffold, A1H R1/B1 POST and A1J PHH POST retained.

## Verified canonical reuse

Existing `build/titan2/run-n1i-c1-cellular-isolation.sh` main lines 377-382 has an exact two-line marker + `$(call inherit-product, vendor/sable/titan2/n1i-c1/sable-titan2-n1i-c1.mk)` append for `device/phh/treble/rom.mk`. Its original old combined executor runs offline app builds and huge stock image extraction, **modifies historical donor workspace**, and thus is **NOT** a selected-A1 or build-only executor. It generates C1 `property.te` from extracted `system_ext_sepolicy.cil`, stages stock APK/two JARs/three XMLs and 5 unsigned app APKs, and performs full image compilation; do not call unchanged.

Canonical 9-line `product/titan2/n1i-c1/sepolicy/system_ext/private/property_contexts` Git blob `2e76792f31a414c7f63af80259e2b092c3c888ae` is the next owner to stage after source approval. `property.te` is still not independently derived/qualified. A1 selected original `rom.mk` PRE SHA256 `ab0ec737342d41d562816fce73e8694e35ce32e09db74c12ea115efa3619d592` established in actual A1I; selected A1K five files exact SHA pins are hardcoded in A1L.

## A1L V1 external package

`N1F_P342_A1L_ROM_C1_POLICY_PAYLOAD_ADMISSION_V1.zip` **SHA256 `4abd5f0c169db5e0b3db74d96d4c0ac53c501f4073e569a6fd3e70be46a0da67`**, **23,903 bytes**. Main Python SHA256 `b4a6be4cb4b70d99f99e5fea1932f754ca6a3f88433e38df6399a777585226c5`. Reused A1D source unchanged SHA256 `6b91d290e165acced0048a76a1d85de7e37044ce4cb1f3e718923a3739099777`. ZIP CRC PASS, **9/9 inner SHA256** PASS; Python AST/compile 4/4, Bash syntax PASS. **88/88 combined A1D + A1L synthetic regressions PASS** under both `umask 077` (0.159s) and `022` (0.168s), fresh exact ZIP under `umask 077` **88/88 PASS** (0.161s), zero-I/O plan PASS. **A1L actual ai-g732 read-only inspection and optional source write NOT EXECUTED**.

A1L no-write plan, optional `inspect --authorize-a1l-readonly-source-payload-review` scans exact A1 R1/B1/PHH/skip_mount and five A1K file hashes, no-build marker/evidence/out/.repo guards, original `rom.mk` PRE pin; canonical property_contexts source exact Git blob. It also inspects only **12 named optional retained M4 file candidates**: 6 C1 stock-derived original input paths (IMS APK stock SHA256 `30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539`, two JARs SHA `511b674b...` / `bb5769a0...`, three unpinned XMLs), five C3B APK type-only file paths, and property.te type-only. APK max 64MiB, JAR 8MiB, XML 1MiB; oversize candidate records HOLD without content read; no listing or stock image extraction. **M4 candidate existence or pinned hash is not stock provenance or approval to copy into A1**. Absence does not fail exact A1 source preview. No Git/repo, build, source mutation, or device operation.

On operator **real read-only preview PASS** and independent review only, optional `apply --authorize-a1l-exact-rom-policy-source-writes` rechecks identities, creates one-use receipt/ROM original and predicted backup, atomically replaces **only original A1 `device/phh/treble/rom.mk`** with historic reviewed C1 inheritance, and creates only source `vendor/sable/titan2/n1i-c1/sepolicy/system_ext/private/property_contexts` (plus 3 necessary parent dirs). It preserves ROM original file mode, no-build marker and absent out-a1; STOP on partial without retry/rollback/cleanup. Status always `NOT_BUILD_READY`. A1L wrapper never calls apply. No permit to stage proprietary payloads, replace C1 SELinux property.te without stock attribution, create `.repo`, remove marker, or begin `systemimage`.

### Next

Operator: verify ZIP SHA, extract fresh temp, run `bash ./n1f_p342_a1l_validate_then_inspect_v1.sh` for 88 regression tests, plan, and actual bounded read-only report. Return actual JSON for stage approval and candidate selection. After source-only stage, qualified artifacts must still be provided for 3 pinned IMS binaries plus 3 XMLs, 5 Sable APKs with build-snapshot manifest, generated property.te; `.repo`/Git object closure and evaluated product graph; then dedicated **isolated build-only** executor. Original 369-patch/TrebleApp, effective G1/G2/G3 and PHH marker boot-time visibility remain to be tested.

```text
A1K_ACTUAL_HOST=PASS_FIVE_STATIC_C1_C3B_MARKER_FILES
A1L_ASSISTANT_QA=PASS_ZIP_SHA9_AST4_BASH_TESTS88
A1L_ACTUAL_HOST=NOT_EXECUTED
A1L_SOURCE_WRITES=NOT_EXECUTED
IMAGE_BUILD_AUTHORIZED_HOST_ONLY=YES
BUILD_READY=NO IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

PR342 remains open, draft, and unmerged.