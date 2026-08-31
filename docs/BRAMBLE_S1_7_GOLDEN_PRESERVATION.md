# Bramble S1.7 golden preservation

Status: **PASS / storage-preservation evidence**

Purpose: preserve the frozen Pixel 4a 5G (`bramble`) S1.7 runtime and host-tool reference before reclaiming obsolete Android build outputs for the Pixel 7 (`panther`) Android 17 workspace.

## Golden archives

The local golden archive gate completed successfully before build-output cleanup.

Preserved under `/srv/data/sable_golden/`:

```text
SableOS_Bramble_S1_7_Source_Golden.tar.zst
SableOS_Bramble_S1_7_Runtime_Golden.tar.zst
SableOS_Bramble_S1_7_SHA256SUMS.txt
```

Observed compressed sizes:

- source archive: about 1.7 MiB;
- runtime archive: about 921 MiB.

Both archives passed `zstd -t` integrity validation. The runtime archive contains the frozen image/binary reference and the SHA-256 manifest is the authoritative archive checksum record.

The archives should receive an off-machine copy before the final S1.7 output directory is deleted. Large binary archives should not be committed to normal Git history; GitHub retains the small provenance/checksum records while an external object/file store such as Google Drive is appropriate for the compressed runtime artifacts.

## Disk cleanup A

Before cleanup:

```text
/srv/data free: approximately 181 GiB
```

Deleted obsolete build outputs:

```text
out_s0   approximately 116 GiB
out_s1   approximately 116 GiB
out_s12  approximately 7.5 GiB
```

Closed S1.8 bramble UI qualification probes under `/tmp` were also deleted. `/tmp/sable-panther-p0r1` was explicitly preserved because the Panther P1B gate consumes its pinned `adevtool`, vendor-state and kernel references.

After cleanup A:

```text
/srv/data free: 419.1 GiB
```

The bramble source tree, `.repo`, `device/`, and `out_s13b` were preserved.

## Host-tool preservation

Before deleting `out_s13b`, the exact Android host tools currently used by the Panther workflow were copied to:

```text
/srv/data/sable_host_tools/bramble_s1_7/host/linux-x86/bin/adb
/srv/data/sable_host_tools/bramble_s1_7/host/linux-x86/bin/fastboot
```

Exact hashes:

```text
adb
  d219a840c4bc029c515790c62fd8d470d9ae113e3ea2098f0295dd706cb8e881

fastboot
  1e36efac65ee9c0b934b6501ab97264cb19a660d1dde695e775f5c8f2106118b

host-tools.sha256
  19437ae62c78462169bd4e9f26ea1bfa7be0edb75e6be7dc96d89b1f3c71ef33
```

`ldd` found no shared libraries under the Android output directory for either executable, so no `out_s13b` private library closure had to be copied.

Independent execution passed:

```text
adb version     PASS
fastboot --version PASS
```

The preserved `adb` also successfully performed a read-only query of the Pixel 7 and observed:

```text
device=panther
build=CP2A.260705.006
```

Therefore the active Panther workflow no longer depends on `out_s13b` for `adb` or `fastboot`.

## Deletion authorization state

```text
BRAMBLE_S1_7_GOLDEN_ARCHIVE=PASS
SABLE_DISK_CLEANUP_A=PASS
SABLE_HOST_TOOLS_PRESERVED=PASS
HOST_ADB_EXECUTION=PASS
HOST_FASTBOOT_EXECUTION=PASS
HOST_ADB_DEVICE_TEST=PASS
```

`out_s13b` is technically disposable after an off-machine copy of the golden archives is verified. The bramble source tree remains the frozen S1.7 regression/porting reference and should not be removed as part of the normal Panther storage cleanup.

No device mutation, root, reboot or flash occurred during the preservation steps.
