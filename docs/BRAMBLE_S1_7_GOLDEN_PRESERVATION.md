# Bramble S1.7 golden preservation

Status: **PASS / off-machine golden backup verified**

Purpose: preserve the frozen Pixel 4a 5G (`bramble`) S1.7 runtime and host-tool reference before reclaiming obsolete Android build outputs for the Pixel 7 (`panther`) Android 17 workspace.

## Golden archives

The local golden archive gate completed successfully before build-output cleanup.

Preserved locally under `/srv/data/sable_golden/`:

```text
SableOS_Bramble_S1_7_Source_Golden.tar.zst
SableOS_Bramble_S1_7_Runtime_Golden.tar.zst
SableOS_Bramble_S1_7_SHA256SUMS.txt
```

Exact local hashes recorded during the verified Drive copy:

```text
97555a656e1d6ef5dd0eec73dc05dee9a762c17acf46ef3d842f5e3ddbb2813d  SableOS_Bramble_S1_7_Source_Golden.tar.zst
013fe4e89a8d2954f8062b06f254de24dc2f1c85d59f0d3889b2553b412d7ce6  SableOS_Bramble_S1_7_Runtime_Golden.tar.zst
6a87e868fac5c1dae9688e3850df0e7adbdcf285c0f183845d2ed9fdf842cd71  SableOS_Bramble_S1_7_SHA256SUMS.txt
```

Both `.tar.zst` archives passed `zstd -t` integrity validation before upload.

The repository also retains the normalized checksum manifest at:

```text
golden/bramble/s1_7/SHA256SUMS.txt
```

## Google Drive off-machine backup

Destination:

```text
My Drive/
└── SableOS Golden Archives/
    └── Bramble S1.7 Golden/
```

Google Drive folder ID:

```text
1ttr6WhGZAjbA5pFt3k8CVoCsfEt5W-7M
```

Verified remote objects:

```text
SableOS_Bramble_S1_7_Source_Golden.tar.zst
  Drive ID: 1sskdEHncS1WTWpZDiaQdsL9cUMHxEoie
  Size:     1,732,971 bytes
  SHA-256:  97555a656e1d6ef5dd0eec73dc05dee9a762c17acf46ef3d842f5e3ddbb2813d

SableOS_Bramble_S1_7_Runtime_Golden.tar.zst
  Drive ID: 1RfzFRbbpCun2oi8ig8rkll-r1JAkrU3H
  Size:     964,873,519 bytes
  SHA-256:  013fe4e89a8d2954f8062b06f254de24dc2f1c85d59f0d3889b2553b412d7ce6

SableOS_Bramble_S1_7_SHA256SUMS.txt
  Drive ID: 1b0c_ZRXX-kQPMHpm5O3e3mz3Xj6B5iJW
  Size:     1,544 bytes
  SHA-256:  6a87e868fac5c1dae9688e3850df0e7adbdcf285c0f183845d2ed9fdf842cd71
```

The ThinkPad transfer used `rclone copy`, not `move`. Verification used `rclone check --download`; it returned exit status 0 with `0 differences found` and `3 matching files`. The include/exclude ordering warning from rclone was non-fatal and did not invalidate the successful byte comparison.

The Drive connector independently observed all three files with the same remote sizes and successfully read the uploaded SHA-256 manifest.

## Frozen S1.7 runtime image hashes

```text
e094666c78675de5acdb50e178511e6fe606ffc070c54082360c3e448f8dd188  boot.img
33f9152c63aa2c45fc171b38f9baff522c4ea6ed5566a85d016e78143f3ed9be  dtbo.img
950cc79de4b2406d7a108346b2c5944e252f9991aea9666bd13136ee771070b4  product.img
d890d1d546acdf527063122a756dff87f81950d2c1be72143730c21248e82547  system.img
d198ab376060e2353841eb60249c69e56501381f1259544133e163e6a0f66473  system_ext.img
49d776911f955fd7b0a677980710be24aa567a900671b7fee0a0fd87ecb2e2fd  vendor.img
7fb952ade542cac0e1e96a63ad71333b797f4806a0e74222f12e7f3a4c4ad3d3  vendor_boot.img
ee87dd8478eddf0b4efb0b09323dd724bcf481d387ef4e6b4da2d08f2ea023a3  vbmeta_system.img
98042fbdf4f04426b8741adaf32592e04ac2f5426e959fc1331595176a4c6a69  vbmeta.img
```

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

Independent execution passed for both tools, and the preserved `adb` successfully performed a read-only Pixel 7 query observing:

```text
device=panther
build=CP2A.260705.006
```

Therefore the active Panther workflow no longer depends on `out_s13b` for `adb` or `fastboot`.

## Deletion authorization state

```text
BRAMBLE_S1_7_GOLDEN_ARCHIVE=PASS
BRAMBLE_S1_7_DRIVE_BACKUP=PASS
BRAMBLE_S1_7_DRIVE_REMOTE_VERIFY=PASS
SABLE_DISK_CLEANUP_A=PASS
SABLE_HOST_TOOLS_PRESERVED=PASS
HOST_ADB_EXECUTION=PASS
HOST_FASTBOOT_EXECUTION=PASS
HOST_ADB_DEVICE_TEST=PASS
OUT_S13B_DELETE_AUTHORIZED=YES
```

`out_s13b` is now disposable. The bramble source tree remains the frozen S1.7 regression/porting reference and should not be removed as part of the Panther storage cleanup.

No device mutation, root, reboot or flash occurred during the preservation and backup steps.
