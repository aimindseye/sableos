# Titan 2 N1I-C2 Cellular MVP Materialization R1

Status: **host-only stock payload freezing; no Android-source mutation, build,
device contact, reboot or flash authorization**

## Purpose

The V5 mutation manifest is now finite and sealed:

```text
NATIVE_AUTHORITY=N1I_A_A4_ACCEPTED_SUPERSET
NATIVE_IMPORT_COUNT=33
MUTATION_COUNT=41
MUTATION_SET=PASS_FINITE_REVIEWABLE
```

The next step is not another dependency experiment. It is to freeze the exact
stock bytes that the one Cellular MVP implementation will consume.

Materialization produces a sealed stock bundle containing:

- V01.00.14 `ImsService.apk`;
- `mediatek-common.jar`;
- `mediatek-ims-base.jar`;
- all 33 admitted A4 native compatibility files.

Total stock files:

```text
3 core OEM/Java files
33 native compatibility files
---
36 stock files
```

The full 41-entry mutation manifest is then rewritten as a **frozen mutation
manifest** in which every proprietary stock artifact has an exact SHA-256.

## Authority

Input mutation manifest:

```text
/srv/sable-build/evidence/titan2/n1i-c2-cellular-mvp-manifest/
  20261005T215928Z-8ebeebdb
```

Required manifest authority:

```text
A4_SHA256=6dad2e573b912d6a20fd5b16cb667dc15b9d43cb1f831fa2751830282e437fd4
NATIVE_COUNT=33
MUTATION_COUNT=41
MUTATION_SET=PASS_FINITE_REVIEWABLE
```

Stock/C3A input image authority:

```text
stock system:
b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd

stock product:
de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37

stock system_ext:
1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170

stock vendor:
cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada

C3A control:
4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
```

## Replay policy

The authoritative materialization path always performs one fresh **read-only**
N1I-A replay using the pinned stock reference, the pinned N1I-A audit and the
sealed C3A control.

The previously qualified V6E replay is deliberately **not** stock-byte
authority for materialization. Its runtime-linkage metadata/log was sealed, but
the extracted `work/stock/...` tree was not individually sealed. Reusing that
mutable extraction for first-time native hashes would weaken the materialization
boundary.

The fresh replay remains offline and performs no device contact. The 36 selected
stock files are copied and hashed immediately. After the sealed stock bundle is
verified, the temporary replay `work/` extraction is deleted before the
materialization evidence directory is sealed.

## Materialization checks

For each proposed stock file:

1. resolve the exact device path under the qualified stock extraction;
2. reject missing files and symlinks;
3. copy to the same partition-relative path in the sealed bundle;
4. hash source and copy and require byte identity.

The materializer also pins the complete 41-ID mutation shape. In particular,
the TelephonyMetrics patch, incoming-call property selection, PHH mtkmal guard,
integration package and healer actions must match the reviewed V5 semantics;
materialization is not allowed to silently freeze a different implementation
plan.

Output paths are rejected if they overlap the SableOS repository, the sealed
manifest input, or the replay input.

For all 33 native entries additionally require:

```text
ELF class = ELF64
endianness = little-endian
e_machine = AArch64 (183)
```

The three core artifacts are checked against their already-pinned SHA-256:

```text
ImsService.apk
30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539

mediatek-common.jar
511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549

mediatek-ims-base.jar
bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab
```

## Outputs

Artifact bundle:

```text
files/system/...
files/system_ext/...
CELLULAR_MVP_STOCK_MATERIALIZATION.tsv
CELLULAR_MVP_FROZEN_MUTATION_MANIFEST.tsv
CELLULAR_MVP_MATERIALIZATION_SUMMARY.env
SHA256SUMS.txt
```

Expected final counts:

```text
N1I_C2_MATERIALIZATION_STOCK_FILE_COUNT=36
N1I_C2_MATERIALIZATION_CORE_FILE_COUNT=3
N1I_C2_MATERIALIZATION_NATIVE_FILE_COUNT=33
N1I_C2_MATERIALIZATION_NATIVE_HASH_COUNT=33
N1I_C2_MATERIALIZATION_MUTATION_COUNT=41
N1I_C2_CELLULAR_MVP_STOCK_MATERIALIZATION=PASS
```

The evidence directory records the replay authority, logs, artifact location and
its own seal.

## What materialization does not do

Materialization does not:

- mutate `frameworks/opt/telephony`;
- modify `device/phh/treble`;
- change product properties;
- install the Titan integration package;
- build `system.img`;
- contact the Titan 2;
- reboot or flash.

Those actions belong to the subsequent **implementation/build authorization**
and must consume the frozen mutation manifest exactly.

## Next transition

After a successful materialization review, the implementation lane may authorize
the entire finite MVP source delta together:

1. stage the 36 sealed stock files;
2. apply the TelephonyMetrics two-argument overload;
3. set the Titan incoming-call compatibility property;
4. Titan-gate the PHH `mtkmal` IMS/ePDG disable/reboot behavior;
5. add the Sable Titan cellular integration package;
6. ship the healer disabled by default;
7. build one Cellular MVP `system.img`.

No library-by-library build loop is inserted between materialization and that
candidate build.
