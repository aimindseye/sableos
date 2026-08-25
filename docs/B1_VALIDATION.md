# B1 validation record

## Build identity

- Device: Google Pixel 4a 5G G025E
- AOSP device: `bramble`
- Product: `sable_bramble_b1-userdebug`
- Android: 12.1
- AOSP tag: `android-12.1.0_r11`
- Build ID: `SQ3A.220705.003.A1`
- Android Rust toolchain observed during build: Rust 1.51.0

The full B1 build completed successfully, followed by a successful `target-files-package` build and `unzip -t` validation.

## oxynoded

Installed path:

```text
/system_ext/bin/oxynoded
```

Verified executable properties:

```text
ELF 64-bit LSB pie executable
Machine: AArch64
Type: DYN (Position-Independent Executable)
Interpreter: /system/bin/linker64
NEEDED: libc.so
NEEDED: libdl.so
```

SHA-256:

```text
753cd2e2b4e915848a72f289d6bc764cd34edf1bbde0b0b4d023d06ae88d0e45  oxynoded
```

## B0 -> B1 hardware-boundary checks

The following artifacts are byte-for-byte identical between vanilla B0 and SableOS B1:

| Artifact | SHA-256 |
|---|---|
| `bootloader.img` | `ac16680a4e393aeb0e4f15c9d4b3ee0120434c6738fe1a5520acd61a54fafafb` |
| `radio.img` | `e3b992a136d77424727ddf9665ec4a1e55788bae85bd0bb3d944e9cebc0125e8` |
| `vendor.img` | `40d0c3f7bd92deeb513829a306341515a6971d7b006192eb4b7bffced391e272` |
| `dtb.img` | `ab926d3bd16e4151fe64975c06d3b30c42e2198d4e24ac9cee957b8eb27b7f39` |
| `super_empty.img` | `6bb18232cb1c0a9e3c8d0a6dcad6f1e74e90a1f98f736fe11d260ceb1befde59` |

### DTBO investigation

The final `dtbo.img` hash differs between B0 and B1. `avbtool info_image` showed that the AVB salt, digest, and embedded build fingerprint changed:

- B0 product fingerprint contains `aosp_bramble`
- B1 product fingerprint contains `sable_bramble_b1`

After handling the AVB footer on temporary copies, the DTBO payloads compared byte-for-byte identical.

Conclusion: no underlying DTBO payload modification was detected between B0 and B1; the final-image difference is attributable to AVB/build metadata.

## B1 image SHA-256 values

```text
354a7d4aa9d4455bb0faa681d1bb2364c147cf1a4dc830f0a4945c2b03ed7da5  vendor_ramdisk.img
3dfcccaaf2a6ce8df2185a7da0458c5f2e90c8e100c9ea78b8c8d712ab800d2d  vbmeta_system.img
40d0c3f7bd92deeb513829a306341515a6971d7b006192eb4b7bffced391e272  vendor.img
638f63dcf08a5b3eb33f6df69fb900fe0bb88c5e9dc6ea7862476362a08af36e  vendor_boot-test-harness.img
6bb18232cb1c0a9e3c8d0a6dcad6f1e74e90a1f98f736fe11d260ceb1befde59  super_empty.img
72ae83b955fc1b4b5c07a46ba5440b9800f85f3b9203a1c4055aaf06989494fd  userdata.img
79ff1d9c2c2c2ff69e8fc3bd9173da857bfd2c97ac8c42011e19e286782eebe6  system_other.img
7eccc76011c73f49194d76bdf708144c906ab07d0f83f91c94c9fe521cea3e68  system_ext.img
7f28802a769382accef5458058b23ed151506919caf774efaee173b888447683  ramdisk-test-harness.img
8d30311645993f211c6317bb77cb82da642413df97389d461c02cbfcdd2be398  vendor_ramdisk-debug.img
9a862db930d3a0bff345f282dd4de5903795ba57e11dc256ecae51996a4982c0  system.img
9aafe52b0f91b17ac01d4ca774b3b963fc8e14b665310bf0b28dfc9ee370dd82  dtbo.img
ab926d3bd16e4151fe64975c06d3b30c42e2198d4e24ac9cee957b8eb27b7f39  dtb.img
ac16680a4e393aeb0e4f15c9d4b3ee0120434c6738fe1a5520acd61a54fafafb  bootloader.img
b838f6a9945776d3a3cc2b719546185071d14fad5f738efa20979b7ab253e0c4  ramdisk-debug.img
c4ad7ba6b246986f9991d7c5154d70e7dfed320340bc44202bdc338870ff2582  vendor_boot-debug.img
d2b3f5b5ea600b6daccd384ce77a519e0d6cdb8f83a8f4e74f287553f0ae4aa1  vbmeta.img
e3b992a136d77424727ddf9665ec4a1e55788bae85bd0bb3d944e9cebc0125e8  radio.img
edd6f2f688f12181fdab8e9d1280c82eca4185e833862af89f9d34f154292857  ramdisk.img
f8fd2314c7a3dee93e27866b479a3423975835f664a505ee0eda5b2f6ba2e99a  vendor_boot.img
fcaa3e706a6b4ac4699fb965218964b342b41cc918caee99fd3232c7009e176d  product.img
fe3637453a6dc754c842cde07e7939ff214d4a92888c6afd13c9b3a2c3826c16  boot.img
```

## Next gate

Before B1.1, validate B0 and B1 on physical G025E hardware. B1.1 should add an init service and a dedicated SELinux domain without weakening SELinux enforcement or introducing broad root privileges.
