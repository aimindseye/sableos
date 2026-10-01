# Titan 2 N1D C3A Restless/Treble reproduction control

Status: **control-build phase; non-release; no device contact**

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


## Exit criterion

C3A is complete when the pinned 991-project public functional graph and control
recipe produce and seal a `treble_arm64_bvN-bp4a-user` `system.img`.

That result becomes comparison evidence for C3B. It does not authorize a flash.
