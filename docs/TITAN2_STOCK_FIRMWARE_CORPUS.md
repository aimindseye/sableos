# Titan 2 stock firmware / OTA corpus seal

Status: **downloaded and transport-integrity sealed; read-only T0 input; not yet firmware-authenticity or flash qualified**

Date sealed: 2026-09-21

This document records the completed acquisition and byte-integrity verification
of the Unihertz Titan 2 stock firmware/OTA corpus collected under the local
artifact label `lichtmetzger-20260920`.

The binary corpus is intentionally **not committed to Git**. Canonical local
evidence location on the Sable build host:

```text
/srv/data/sable-build/artifacts/titan2/stock-firmware/lichtmetzger-20260920
```

## Acquisition result

```text
TITAN2_FIRMWARE_DOWNLOAD=PASS
FILE_COUNT=18
TOTAL_BYTES=61417875932
DEST=/srv/data/sable-build/artifacts/titan2/stock-firmware/lichtmetzger-20260920
```

The downloaded set contains 10 full firmware packages and 8 OTA packages across
Android 15 and Android 16, with EEA and TEE regional variants.

## Remote-inventory size verification

Every downloaded file was checked against the byte size recorded in
`remote-inventory.tsv`.

```text
SIZE_PASS_COUNT=18
SIZE_FAIL_COUNT=0
TITAN2_CORPUS_SIZE_VERIFICATION=PASS
```

## Corpus inventory

| Type | Android | Region | Build/package | Bytes |
| --- | --- | --- | --- | ---: |
| Firmware | 15 | EEA | 2025090216_g71v78c2k_dfl_eea.zip | 3535674709 |
| Firmware | 15 | EEA | 2025102717_g71v78c2k_dfl_eea.zip | 3531644524 |
| Firmware | 15 | EEA | 2025111916_g71v78c2k_dfl_eea.zip | 3569523116 |
| Firmware | 15 | TEE | 2025090819_g71v78c2k_dfl_tee.zip | 3536947795 |
| Firmware | 15 | TEE | 2025102716_g71v78c2k_dfl_tee.zip | 3532981728 |
| Firmware | 15 | TEE | 2025111915_g71v78c2k_dfl_tee.zip | 3570582619 |
| Firmware | 16 | EEA | 2026020617_g71v78c2k_dfl_eea.zip | 3693740474 |
| Firmware | 16 | EEA | 2026041315_g71v78c2k_dfl_eea.zip | 3743600619 |
| Firmware | 16 | TEE | 2026021022_g71v78c2k_dfl_tee.zip | 3693402149 |
| Firmware | 16 | TEE | 2026042212_g71v78c2k_dfl_tee.zip | 3743249119 |
| OTA | 15 | EEA | 2025102717_g71v78c2k_dfl_eea-ota.zip | 3173195306 |
| OTA | 15 | EEA | 2025111916_g71v78c2k_dfl_eea-ota.zip | 3205573414 |
| OTA | 15 | TEE | 2025102716_g71v78c2k_dfl_tee-ota.zip | 3174053841 |
| OTA | 15 | TEE | 2025111915_g71v78c2k_dfl_tee-ota.zip | 3206122821 |
| OTA | 16 | EEA | 2026020617_g71v78c2k_dfl_eea-ota.zip | 3109041853 |
| OTA | 16 | EEA | 2026041315_g71v78c2k_dfl_eea-ota.zip | 3145150785 |
| OTA | 16 | TEE | 2026021022_g71v78c2k_dfl_tee-ota.zip | 3108757036 |
| OTA | 16 | TEE | 2026042212_g71v78c2k_dfl_tee-ota.zip | 3144634024 |

## SHA-256 verification and seal

A deterministic `SHA256SUMS` file was generated over all files under
`Firmware/` and `OTA/`. A subsequent `sha256sum -c SHA256SUMS` verified all
18 entries successfully.

The corpus-level seal is:

```text
SEALED_UTC=2026-09-21T00:31:06Z
FILE_COUNT=18
TOTAL_BYTES=61417875932
SHA256SUMS_SHA256=21764a9839313e261b2a8d128ba6306085faf0525a159711c59469ed2edae6e1
```

The `SHA256SUMS_SHA256` value seals the checksum manifest itself. The checksum
manifest and binaries remain local build-host evidence rather than repository
payloads.

## What this closes

This evidence closes the **corpus acquisition and transport-integrity** portion
of Titan 2 T0:

```text
TITAN2_STOCK_CORPUS_DOWNLOAD=PASS
TITAN2_STOCK_CORPUS_REMOTE_SIZE_MATCH=PASS_18_OF_18
TITAN2_STOCK_CORPUS_SHA256_VERIFY=PASS_18_OF_18
TITAN2_STOCK_CORPUS_SEAL=PASS
```

It does **not** by itself prove:

- OEM cryptographic authenticity or package signing policy;
- partition-image provenance after extraction;
- bootloader / fastboot / fastbootd behavior;
- AVB/vbmeta/rollback semantics;
- stock restore success on physical hardware;
- compatibility of any package with a specific physical unit;
- authorization to unlock, flash, resize dynamic partitions, or boot a GSI.

Those remain later T0/T1 evidence gates.

## Next read-only work

Before any Titan 2 mutation, use this sealed corpus as the immutable input for:

1. read-only archive inventory and package metadata;
2. exact partition-image inventory;
3. boot/vbmeta/AVB and rollback-index inspection;
4. dynamic-partition / super metadata inspection;
5. kernel, vendor_boot, init_boot, dtbo and module inventory;
6. vendor/ODM VINTF and HAL inventory;
7. modem/IMS/firmware provenance mapping;
8. stock restore-plan construction.

The Panther-first rule in `TITAN2_GSI_PLAN.md` remains authoritative for any
bootloader or flash mutation.
