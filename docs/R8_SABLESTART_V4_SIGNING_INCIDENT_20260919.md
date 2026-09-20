# R8 SableStart v4 signing incident — 2026-09-19

## Scope

This record captures the SableStart package-registration failure found during
physical R8 validation on Pixel 7 (`panther`). It is a development-signing
and package-scan integration defect. It is not the deferred production-key /
OTA-signing program.

## Physical result before package validation

The coherent R8 slot-B deployment booted successfully with the expected build
identity and preserved encrypted shared data:

```text
sys.boot_completed=1
ro.boot.slot_suffix=_b
ro.product.device=panther
ro.crypto.state=encrypted
ro.build.version.incremental=2026091900
```

The eight standalone Sable APKs registered normally. The source-built
`org.sableos.start` package did not.

## Artifact identity

The live SableStart APK and the APK in the sealed target-files archive were
byte-identical:

```text
sha256=f5eeac4876a308c49dada1051e8ee0b877967dac1736a9519a5e5bf31c42e3ad
path=/system/app/SableStart/SableStart.apk
package=org.sableos.start
```

The target-files archive also contained:

```text
SYSTEM/app/SableStart/SableStart.apk.idsig
```

The canonical SableStart Soong module explicitly requested:

```bp
v4_signature: true,
```

## Confirmed boot-time failure chain

PackageManager logged the complete causal sequence:

```text
/system/app/SableStart changed; collecting certs (forced)
avc: denied { ioctl } ... path="/system/app/SableStart/SableStart.apk"
VerityUtils: Failed to measure fs-verity, errno 13
Failed to scan /system/app/SableStart:
Failed to collect certificates ... using APK Signature Scheme v4
System package org.sableos.start no longer exists
```

The failure is therefore not explained by a missing APK, stale target-files,
package-name mismatch, required AndroidX library, or a shared system UID.

SableStart and `framework-res.apk` use different development certificates,
but SableStart does not declare a shared UID and does not require platform
signing. The certificate difference is not the causal defect identified by the
boot evidence.

## Fix

SableStart must not emit a v4 `.idsig` sidecar under the current Panther
system-app policy:

```bp
v4_signature: false,
```

This is explicit rather than relying on the Soong default so the intended
product contract is reviewable.

## Permanent qualification controls

R8 now treats this as a release-candidate composition requirement:

1. canonical SableStart source must explicitly contain
   `v4_signature: false`;
2. source containing `v4_signature: true` fails before the Panther build;
3. target-files must contain exactly one
   `SYSTEM/app/SableStart/SableStart.apk`;
4. target-files must not contain
   `SYSTEM/app/SableStart/SableStart.apk.idsig`;
5. the final local build records both source-policy and target-files-policy
   evidence;
6. GitHub CI self-tests the signing policy and validates the source contract;
7. repository CI policy fails if the signing gate is removed from the build,
   target-files qualification or final-R8 closure workflow.

The implementation is centralized in:

```text
build/gates/r8-sablestart-signing-policy.py
```

## Shell-gate lesson

Do not implement this requirement as:

```bash
set -euo pipefail
if unzip -l "$TF" | grep -Fq 'SableStart.apk.idsig'; then
    ...
fi
```

When `grep -q` finds the match it may exit before `unzip` finishes.
`unzip` then receives SIGPIPE, and under `pipefail` the pipeline can return
non-zero even though the forbidden member was present. This produced a false
PASS during the incident.

The permanent gate uses Python `zipfile` membership instead of an early-exit
shell pipeline.

## Requalification requirement

A previous R8 target-files artifact that contains the SableStart `.idsig`
remains unqualified even when the APK bytes themselves are unchanged.

After the source fix:

```text
source signing policy
 -> SableStart Soong build
 -> full target-files regeneration
 -> no-.idsig target-files proof
 -> package identity proof
 -> coherent authorized deployment
 -> live PackageManager registration proof
```

Manual `pm install`, package-state deletion or data wiping must not be used to
hide this product-integration defect.
