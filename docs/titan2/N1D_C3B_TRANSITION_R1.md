# Titan 2 N1D C3B E1 engineering transition

Status: **E1 active on review branch; source/build qualification required; no device contact**

Date: 2026-10-02

## Purpose

E1 consumes the sealed C3A control evidence and activates a separate C3B
engineering lane.

C3A proved the public Restless/TrebleDroid Android 16 build topology. C3B does
not inherit the Restless source-graph removals or patch stack.

~~~text
C3A control
    -> sealed comparison evidence

C3B E1
    -> clean pinned GrapheneOS base
    -> minimal pinned Treble scaffold
    -> exact Sable hardening of pinned PHH base
    -> zero Restless runtime patches
    -> generated userdebug systemimage only

C3B E2
    -> Sable product identity
    -> Sable source-module admission
    -> Launcher3-hosted Sable Start
    -> product/partition ownership
~~~

E1 is not a release or flash transition.

## C3A prerequisite

E1 is bound to the sealed C3A image evidence:

~~~text
N1D_C3A_CONTROL_EVIDENCE_STATUS=PASS_SYSTEMIMAGE
N1D_C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE
~~~

## Separate workspace

C3B does not attempt to roll back the C3A-mutated Android tree.

~~~text
/srv/sable-build/workspaces/titan2-n1d-c3b/
    android/
    out-c3b-engineering/
~~~

This keeps C3A's 991-project graph, 369 control patches and generated/build
residue isolated as evidence.

## Source graph

Exact Graphene base:

~~~text
tag:              2026061600
manifest commit:  5d82aa9610855bc0b43b9eb7ca4470d30455cfeb
projects:         1033
removals:         0
~~~

E1 adds five pinned scaffold projects:

~~~text
device/phh/treble
prebuilts/vndk/v28
prebuilts/vndk/v29
vendor/interfaces
vendor/lptools
~~~

Expected managed graph:

~~~text
1033 + 5 = 1038
~~~

The C3A 54-project Restless removal set is not inherited.

C3A additions dropped from E1 by default:

~~~text
packages/apps/QcRilAm
prebuilts/vndk/v30
treble_app
vendor/apn
vendor/hardware_overlay
vendor/magisk
vendor/vndk-tests
~~~

vendor/magisk is forbidden by the C3B security boundary. Other dropped
components can be reconsidered only from concrete C3B failure evidence.

## Runtime patch boundary

~~~text
N1D_C3B_C3A_CONTROL_PATCH_STACK_INHERITED=NO
N1D_C3B_RESTLESS_PATCH_COUNT=0
N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0
~~~

Later compatibility admission requires:

~~~text
reproduce failure
-> identify smallest relevant change
-> review security/runtime impact
-> explicit admission
-> rebuild
-> evidence
~~~

## Exact PHH base hardening

The pinned Treble generator is retained, but its base.mk is not accepted
unchanged as Sable runtime/security policy.

E1 applies:

~~~text
build/titan2/apply-n1d-c3b-phh-base-hardening.py
~~~

against exactly:

~~~text
device/phh/treble commit
39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed

base.mk input blob
a29e402009d449150f1216e5d517ec0c9b36bfbd

base.mk expected hardened blob
58edfb8713e9a1392daaf5bbf0d07778efd6d669

hardening applicator blob
9fdfeb59ab7826615e8c0a44ea105dfc4b7e0679

security transforms
14
~~~

The transform removes:

- PHH private sepolicy and generic external hardware-overlay inheritance;
- ro.adb.secure=0;
- default persist.sys.usb.config=adb;
- PHH rw-system, boot/data and property-handler hooks;
- TWRP/busybox payloads;
- SELINUX_IGNORE_NEVERALLOWS := true;
- PHH MTK SMS helper;
- resetprop/securize/PHH OTA/remove-telephony payloads;
- PHH adbd override;
- TrebleApp privileged permission/sysconfig payloads;
- PHH remote-debug payloads;
- QcRilAm;
- Samsung boot helper and PHH MTK in-call helper.

E1 retains Iwlan, QualifiedNetworksService, and required VNDK compatibility
support for the first build baseline.

The hardening is Sable baseline policy, not a Restless patch admission.

## Generator identity

The generator configuration is:

~~~text
build/titan2/n1d-c3b-engineering.mk
~~~

It intentionally adds no Sable apps or branding in E1.

First engineering target:

~~~text
treble_arm64_bvN-bp4a-userdebug
goal=systemimage
~~~

Final Sable product identity is explicitly E2-owned.

## Host-layout fixes

Two exact C3A-discovered Soong patches are carried into E1 solely for
out-of-tree host-layout compatibility:

~~~text
0001-soong-ci-tests-skip-out-of-tree-host-paths.patch
0002-soong-dexpreopt-gen-support-out-of-tree-product-packages.patch
~~~

They are separately blob-pinned and do not change the runtime patch count.

## Authorization

E1 permits only:

~~~text
separate C3B workspace init/sync with explicit network + mutation authorization
five-project scaffold sync with explicit network + mutation authorization
exact PHH base hardening
Treble product generation
product parse with explicit authorization
systemimage compile with explicit authorization
two exact Soong host-layout fixes with explicit mutation authorization
~~~

E1 blocks:

~~~text
target-files
OTA
dist
release packaging
device contact
adb
fastboot
flash
signing
physical runtime qualification
release
~~~

## Operator sequence

Repository contracts:

~~~bash
bash build/gates/n1d-c3b-transition-contract.sh
bash build/gates/n1d-c3b-engineering-contract.sh
bash build/gates/sable-pipeline-contract.sh
~~~

Preflight:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh preflight
~~~

Initialize:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh   init-base   --authorize-network   --authorize-source-mutation
~~~

Sync and seal:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh   sync-base   --authorize-network   --authorize-source-mutation
~~~

Stage and generate:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh   stage   --authorize-network   --authorize-source-mutation
~~~

Verify:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh verify
~~~

Parse:

~~~bash
bash build/titan2/qualify-n1d-c3b-product-parse.sh   --authorize-product-parse
~~~

Compile:

~~~bash
bash build/titan2/build-n1d-c3b-systemimage.sh   --authorize-c3b-compile   --authorize-host-layout-source-mutation   --jobs 16
~~~

The build phase accepts no network authorization.

## Exit criteria

Static/source transition:

~~~text
N1D_C3B_TRANSITION_CONTRACT=PASS
N1D_C3B_ENGINEERING_CONTRACT=PASS
SABLE_STANDARD_PIPELINE_CONTRACT=PASS
~~~

Workspace/staging:

~~~text
N1D_C3B_GRAPHENE_BASE_SEAL=PASS
N1D_C3B_SCAFFOLD_STAGE=PASS
N1D_C3B_PREP_VERIFY=PASS
~~~

Parse:

~~~text
N1D_C3B_PRODUCT_PARSE=PASS
~~~

Successful compile:

~~~text
N1D_C3B_SYSTEMIMAGE=PASS
N1D_C3B_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT
N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO
N1D_C3B_RELEASE_ELIGIBLE=NO
~~~

A compile failure is not a reason to import C3A wholesale. Preserve the exact
failure and admit only the minimum reviewed compatibility change supported by
evidence.
