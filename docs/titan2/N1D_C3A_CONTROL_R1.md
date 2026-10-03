# Titan 2 N1D C3A Restless/Treble reproduction control

Status: **control build + V01.00.14 physical boot complete; non-release**

Date: 2026-10-01

## Purpose

C3A answers one question: can Sable reproduce the public functional Android 16
RestlessOS/TrebleDroid build topology that previously built successfully?

C3A is not the SableOS product baseline.

## Exact control topology

```text
sealed GrapheneOS 2026061600 base (1,033 projects)
  - exact Restless remove.xml set (54 projects)
  = 979 retained Graphene projects
  + 12 pinned public TrebleDroid/PHH companion projects
  = 991 managed C3A projects
  + RestlessOS 16.0.0-202606230923 recipe
  + exact ordered control patch tiers:
      trebledroid          198
      trebledroid-staging  121
      rom                    29
      personal               17
      release-builds           4
                           ----
                            369
  + configs/rom/rom.mk-equivalent
  + device/phh/treble/generate.sh rom
  + treble_app/build.sh release under canonical SABLE_JDK17
  + lunch treble_arm64_bvN-bp4a-user
  + make systemimage
```

The private Restless vendor repository is excluded. Pixel GSans is also
excluded because the release manifest used a mutable source revision and the
content is optional font/branding data.

C3A is therefore a **public functional reproduction**, not a bit-identical
Restless source tree. The 54 removed Graphene working trees are archived
reversibly under `/srv/sable-build/artifacts/titan2/n1d-c3a-retired-graphene/`. Pixel GSans is also
excluded because the release did not provide an immutable source pin for that
non-functional branding/font input. C3A is therefore classified as:

```text
N1D_C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION
```

It reproduces the public functional source/build graph, not a bit-identical
Restless release tree.

## Source-graph fidelity

Restless copied both `configs/manifests/default.xml` and
`configs/manifests/remove.xml` before sync. All 54 remove-project entries are
present in the sealed Graphene manifest. C3A reproduces those removals
reversibly: the existing clean working trees are archived under
`/srv/sable-build/artifacts/titan2/n1d-c3a-retired-graphene/`, never deleted.

The managed graph is sealed at 991 projects.

## Why C3A exists

The retired handcrafted product repeatedly reached Soong graph generation and
failed because its AOSP `aosp_system_image` dependency set did not match the
Graphene source graph. Restless's known-good recipe already solved that source
composition problem.

C3A therefore removes build-topology guesswork. It gives C3B a known reference
for each subsequent compatibility decision.

## Cellular expectation

C3A is **not expected to prove cellular correctness**.

Earlier Titan 2 Restless/Treble-derived runtime evidence showed that LTE attach
and a WWAN data call could succeed and later drop. High-signal suspects remained
MTK network-indication integration and IMS/QNS/IWLAN interaction.

Therefore:

```text
C3A_BUILD_SUCCESS != CELLULAR_PASS
C3A_BUILD_SUCCESS != SABLE_RELEASE_BASELINE
```

No cellular fix is inferred from reproducing Restless.

## Security boundary

The 369 patches are control inputs only.

```text
N1D_C3A_FULL_RESTLESS_PATCH_STACK_ALLOWED=YES_CONTROL_ONLY
N1D_C3A_RELEASE_ELIGIBLE=NO
N1D_C3A_DEVICE_CONTACT_AUTHORIZED=NO
N1D_C3A_FLASH_AUTHORIZED=NO
```

The generated PHH/Treble runtime is not trusted as Sable security policy.

## Outputs

C3A parse output:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3a-td-parse/
```

C3A build output:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3a-td/
```

C3A evidence:

```text
/srv/sable-build/evidence/titan2/n1d-c3a-trebledroid-*/
```

## Successful control-build evidence

The canonical build host completed the C3A `systemimage` target successfully on
2026-10-01. The sealed result is:

```text
EVIDENCE_DIR=/srv/sable-build/evidence/titan2/n1d-c3a-trebledroid-build/20261001T214611Z-trebledroid-systemimage
SYSTEM_IMG=/srv/sable-build/workspaces/titan2-n1d/out-c3a-td/target/product/tdgsi_arm64_ab/system.img
SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
SYSTEM_BYTES=3146977280
N1D_C3A_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT
N1D_C3A_TREBLEDROID_SYSTEMIMAGE=PASS
N1D_C3_RELEASE_ELIGIBLE=NO
```

Repository evidence is recorded in
`build/titan2/n1d-c3a-control-evidence.env` and guarded by
`build/gates/n1d-c3a-control-evidence-contract.sh`.

This satisfies the evidence prerequisite for a separate C3B transition change.
It does not authorize device contact, flash, signing, OTA generation, or release.

## TrebleApp Java boundary

The pinned TrebleApp control source uses Android Gradle Plugin 7.4.2 with the
Gradle 7.5 wrapper and its upstream build script prefers Java 17 when available.
C3A therefore runs only the TrebleApp prebuild under the canonical
`SABLE_JDK17` host tool. The surrounding AOSP Android 16 build remains free to
use its source-tree JDK selected by `envsetup.sh`.

A failed TrebleApp-only attempt may be resumed without deleting the C3A output
tree only through the explicit `--resume-failed-c3-build` path. That path is
accepted only when sealed prior evidence proves the previous attempt reached
TrebleApp, did not pass TrebleApp, never reached `make systemimage`, and left
no system image, target-files, or OTA artifact.

Because the pinned TrebleApp SDK layout keeps SDK-manager state inside the
repository, a failed Gradle dependency/bootstrap pass may leave that project
dirty even when no app source changed. Resume verification therefore permits
exactly one additional dirty project, `treble_app`, and only two SDK-residue
classes: a modification to tracked binary metadata `sdk/.knownPackages` whose
committed baseline blob remains the pinned upstream blob
`7b27183be84845e00318dbbd3aeb60b5d291216b`, plus untracked regular files
directly under `sdk/licenses/`. Any other tracked modification, nested license
path, symlink, or other untracked path fails verification.

## Host-layout compatibility boundary

The canonical C3A output directory is intentionally outside the Android source
tree. The Android 16 Soong `ci_tests/test_package` implementation in the pinned
GrapheneOS source assumes host install paths can be represented relative to the
product output. With an absolute out-of-tree `OUT_DIR`, host test outputs can
remain absolute and fail Soong path validation before the system image graph is
generated.

C3A carries exactly two Sable-owned build-environment compatibility patches:

```text
patches/android-16-n1d-trebledroid/host-layout/
  0001-soong-ci-tests-skip-out-of-tree-host-paths.patch
  0002-soong-dexpreopt-gen-support-out-of-tree-product-packages.patch
```

Neither patch is part of the 369 Restless control patches and neither changes
runtime Android behavior. Patch 0001 adds the out-of-tree `OUT_DIR` guard used
by the known Soong test-package fix. After that correction, the C3A build
advanced to action 171584/180790 (94%) and exposed a second path-model mismatch:
`dexpreopt_gen` received an absolute
`.../TrebleApp_intermediates/product_packages.txt` path but wrapped it with
`android.PathForTesting()`, which only accepts safe source-relative paths.

Patch 0002 keeps Soong path validation intact. It first proves
`product_packages.txt` is inside the configured `OUT_DIR`, converts the path
to an `OUT_DIR`-relative path with `filepath.Rel`, rejects any path escaping
through `..`, and then represents the file with `android.PathForOutput()`.

The first serialized form of patch 0002 had incorrect unified-diff hunk counts
(`-187,8 +187,18`) and was rejected by `git apply --check` before source
mutation. The corrected hunk is `-207,6 +207,16`. It applies to pinned
GrapheneOS blob `8033b48e5cfcc2cb2f64037aca44c129f54a969b` and produces the
same intended post-patch blob
`7024841edac715a9bd3a81af92c42da0b302e1f0`; therefore this is a
patch-serialization correction, not a semantic source change.

Application requires the explicit
`--authorize-host-layout-source-mutation` build-driver authorization. The
driver and verifier pin each patch blob, each GrapheneOS base-file blob, and
each exact expected post-patch blob. Verification requires `build/soong` to
have exactly two dirty files:
`ci_tests/ci_test_package_zip.go` and
`dexpreopt/dexpreopt_gen/dexpreopt_gen.go`. Any byte difference from either
expected post-patch blob fails closed.

A build that reached `make systemimage` but failed before producing the
final `PRODUCT_OUT/system.img` is classified as
`FAILED_SYSTEMIMAGE_PRE_ARTIFACT`. Intermediate files named `system.img`
under other output subtrees do not constitute a completed system-image
artifact. Resume uses the sealed prior `product-out.txt` to identify the exact
final image path and rejects the resume if that file already exists. Target-files archives and actual OTA package outputs remain prohibited. Normal
system payload files such as `otacerts.zip` are not OTA packages and do not
block resume. The driver reports the number of `otacerts.zip` payloads seen
for audit visibility and prints the exact path of any packaging candidate before
failing.



## Physical V01.00.14 result

The exact C3A system image was flashed to `system_a` on the current Titan 2
V01.00.14 vendor/firmware baseline. Fastboot reported a successful implicit
logical resize from 2,994,388,992 bytes to 3,146,977,280 bytes, all twelve
sparse writes completed successfully, slot `a` was retained, snapshot state
remained `none`, and no vbmeta, boot-chain, whole-super, COW or userdata
mutation was performed.

The device reached Android successfully. Cellular runtime evidence established
home registration on 310260, LTE service, working data, NR availability and
EN-DC availability with Android reporting NR_NSA. A later transient radio state
loss was recoverable by one airplane-mode cycle, after which home LTE + NR_NSA
registration returned. This radio-stability issue is tracked separately.

```text
C3A_V010014_SYSTEM_FLASH=PASS
C3A_V010014_ANDROID_BOOT=PASS
C3A_V010014_VOICE_REGISTRATION=PASS
C3A_V010014_DATA_REGISTRATION=PASS
C3A_V010014_NR_NSA_CAPABILITY=PASS
C3A_V010014_RADIO_POSTBOOT_STABILITY=ISSUE_RECOVERABLE_BY_RADIO_CYCLE
C3A_V010014_COMPATIBILITY_BASELINE=PASS
```

The boot result supersedes the former assumption that C3A was build-only
control evidence. C3A remains non-release and is now the compatibility baseline
for the narrow N1F five-Sable-app isolation.

## Exit criterion

**Satisfied.** The pinned 991-project public functional graph and control recipe
produced and sealed a `treble_arm64_bvN-bp4a-user` `system.img` with SHA-256
`4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16`.

That result is now the comparison evidence for C3B. It does not authorize a
flash or make C3A a SableOS release baseline.
