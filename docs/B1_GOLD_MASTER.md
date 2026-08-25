# B1 gold master

## Status

**FROZEN**

B1 has been archived locally as an immutable gold master:

```text
/srv/data/aosp_gold_master_bramble/B1-oxynoded-SQ3A.220705.003.A1
```

Physical size at freeze: approximately **3.9 GiB**.

## Archived payloads

The gold master contains:

- primary flash images under `images/`
- supporting images under `artifacts/`
- the validated `sable_bramble_b1-target_files-eng.mindseye73.zip`
- the exact `oxynoded` executable
- build/source provenance under `metadata/`

`oxynoded` SHA-256:

```text
753cd2e2b4e915848a72f289d6bc764cd34edf1bbde0b0b4d023d06ae88d0e45
```

## Freeze validation

Before the final freeze:

- the target-files ZIP passed `unzip -t`
- every image/artifact entry in `metadata/images-and-artifacts.sha256` verified `OK`
- every metadata entry in `metadata/metadata.sha256` verified `OK`
- the corrected `build-info.txt` was included in the metadata checksum set
- `find "$B1" -perm /222 -print` returned no paths after the final `chmod -R a-w`
- both checksum manifests were verified again after the tree became read-only

## Hardware-boundary result

B0 and B1 retain identical copies of the hardware-sensitive baseline artifacts already checked during B1 validation:

- `bootloader.img`
- `radio.img`
- `vendor.img`
- `dtb.img`
- underlying DTBO payload

The final DTBO image differs because of AVB/build metadata, not because the underlying DTBO payload changed.

## Next gate

Do not advance to B1.1 until both B0 and B1 are validated on the physical Pixel 4a 5G G025E (`bramble`). See `docs/G025E_HARDWARE_ACCEPTANCE.md`.
