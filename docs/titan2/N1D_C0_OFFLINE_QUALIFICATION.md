# SableOS Titan 2 N1D C0 Offline Qualification

Status: **host-only qualification package; no device contact, build, flash or network fetch**

```text
TRACK=N1D_C0_OFFLINE
DEVICE=titan2
DEVICE_CONTACT_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
SOURCE_MUTATION_AUTHORIZED=NO
INPUT_MUTATION_AUTHORIZED=NO
OUTPUT_MUTATION_AUTHORIZED=YES_EVIDENCE_DIR_ONLY
```

## Purpose

N1C proved that its specific hybrid-super artifact must not be retried, but it did not isolate a single root cause. C0 converts the remaining uncertainty into offline, reproducible gates before any N1D build or device-side test.

The governing N1C postmortem requires comparison with the known-booting Restless/GSI path; first-stage/fstab review; dynamic-partition metadata review; VINTF; SELinux/Treble compatibility; data/encryption expectations; and AVB analysis. C0 implements the portions that can be proven from existing local images and source trees without touching the Titan 2.

## Architecture correction incorporated by C0

C0 does **not** assume that preserving physical `product_a` and `system_ext_a` in `super` means they are active framework-side partitions at runtime.

AOSP's GSI release contract includes `gsi_skip_mount.cfg`; the current AOSP skip list contains `/product` and `/system_ext`. C0 therefore reconstructs the runtime ownership decision first, then constructs the VINTF/SELinux view from the partitions Android would actually expose.

For a GSI that skips the stock framework-side partitions, the intended view is:

```text
/system      -> Sable/AOSP GSI system
/product     -> GSI embedded product view
/system_ext  -> GSI embedded system_ext view
/vendor      -> stock Titan 2 vendor
/odm         -> stock when present
```

The stock `product` and `system_ext` bytes can remain present in `super` while being inert at runtime.

## C0 gates

| Gate | Blocking for N1D build readiness | Question |
|---|---|---|
| `C0_00` | Yes | Are the exact N1C system/super artifacts still the documented hashes? |
| `C0_01_N1B_CONTROL` | No | Can historical N1B be cryptographically qualified, or must it remain `UNQUALIFIED_HISTORICAL`? |
| `C0_02_MOUNT_MODEL` | Yes | Would N1C skip or mount stock `product` / `system_ext`, based on the actual GSI skip file and Titan 2 fstab evidence? |
| `C0_03_FRAMEWORK_VIEW` | Yes | What files are GSI-only, stock-only, or overlapping in product/system_ext? |
| `C0_04_GSI_CONTRACT` | Yes | Does the proposed N1D product explicitly implement the AOSP GSI release contract rather than rediscovering it failure-by-failure? |
| `C0_05_VINTF` | Yes | Does authoritative `checkvintf --check-compat` pass on the reconstructed runtime view? |
| `C0_06_SEPOLICY` | Yes | Can the split SELinux policy compile using the stock vendor mapping version and the reconstructed framework-side view? |
| `C0_07_AVB_CHAIN` | Yes | What exactly do stock `vbmeta`, `vbmeta_system`, and `vbmeta_vendor` protect? |
| `C0_08_AVB_BOUNDARY` | Yes | Did N1C hybrid-super composition move/remove an AVB footer relative to the final logical `system_a` boundary, or is that hypothesis unsupported? |
| `C0_09_LP_METADATA` | Yes | Which LP metadata fields differ from stock for partitions intended to be preserved? |
| `C0_10_CONTROL_DIFF` | Yes | How does N1C differ from the exact known-booting Restless/GSI control? |
| `C0_11_CELLULAR_STATIC` | No for boot architecture | What historical N1B1/N1B2 telephony differences are worth carrying into later IMS work? |
| `C0_12_TOOLCHAIN_SEAL` | Yes | Are the reviewed audit/capture/classifier tools exactly the reviewed hashes? |

`C0_01` deliberately allows `UNQUALIFIED_HISTORICAL`. Missing old hashes must not be reconstructed or guessed; the later device-side ladder can create a fresh, sealed control.

`C0_11` is informational until the project enters cellular/IMS restoration. Boot architecture must be proven before Option B work changes framework or telephony behavior.

## AVB interpretation

C0 treats the N1C AVB-footer theory as a hypothesis, not a conclusion.

It normalizes the N1C source system image, extracts `system_a` from the N1C `super`, and runs `avbtool info_image` on both representations. The result is classified as:

```text
SUPPORTS_HYPOTHESIS
  source has a parseable footer; extracted logical partition does not

DOES_NOT_SUPPORT_HYPOTHESIS
  source and extracted logical partition both retain a parseable footer

NO_SOURCE_FOOTER
  the N1C source system itself has no parseable AVB footer, so the
  footer-loss theory is not applicable as originally stated
```

The test does not assume that source file size must always equal logical-partition size. A valid AVB image can be intentionally resized so its footer sits at the target partition boundary.

## SELinux method

The host `secilc` invocation follows Android init's split-policy model:

- platform policy from `/system/etc/selinux/plat_sepolicy.cil`;
- the mapping matching stock vendor's `plat_sepolicy_vers.txt`;
- optional platform/system_ext/product compatibility and policy files when present;
- stock vendor `plat_pub_versioned.cil` and `vendor_sepolicy.cil`;
- optional stock ODM policy.

This is materially stronger than checking only for the presence of a mapping filename.

## VINTF method

C0 uses `checkvintf --check-compat` with explicit directory mappings. Kernel compatibility is not claimed unless a kernel config/version is separately supplied; `checkvintf` skips kernel requirements when no kernel argument is supplied.

The runtime partition mappings must reflect the C0_02 mount result, not the physical contents of `super` by assumption.

## LP metadata method

The package runs `lpdump -j` against stock and N1C raw super images and records the complete diff. The automatic blocking count focuses on comparable metadata for preserved partitions while ignoring filesystem-usage fields.

N1D recomposition should be derived mechanically from the verified stock LP contract. Community scripts are useful topology references, not authoritative Titan 2 LP metadata.

## Required local inputs

The package defaults the known N1C paths from the public checkpoint, but C0 is fail-closed when required material is absent.

At minimum, provide:

```text
N1C_SYSTEM_IMG
N1C_SUPER_IMG
STOCK_REF_DIR
STOCK_SUPER_IMG (or a uniquely discoverable verified stock-super artifact)
RESTLESS_SYSTEM_IMG
N1D_PRODUCT_FILE
```

The historical N1B image/hash/proof fields are optional because C0 can formally conclude `UNQUALIFIED_HISTORICAL`.

## Run

```bash
cd /srv/data/sable-build/sableos/repo

cp build/titan2/n1d-c0.env.example \
  /srv/data/sable-build/evidence/titan2/n1d-c0.env

# Edit only local paths in n1d-c0.env.

bash build/titan2/qualify-n1d-c0-offline.sh \
  --config /srv/data/sable-build/evidence/titan2/n1d-c0.env
```

The script exits `0` only when all blocking C0 gates pass. A blocked qualification exits `4` and still writes its summary/report.

## Outputs

```text
N1D_C0_OFFLINE_SUMMARY.env
N1D_C0_GATES.tsv
reports/N1D_C0_OFFLINE_REPORT.md
reports/C0_02_skip_mount.cfg
reports/C0_02_fstab_inventory.txt
reports/C0_03_*_diff.md / *.tsv
reports/C0_04_gsi_contract.*
logs/C0_05_checkvintf.log
logs/C0_06_secilc.log
reports/C0_07_*_avb.txt
reports/C0_08_avb_boundary.env
reports/C0_09_*lpdump.json / lp_diff.*
reports/C0_10_system_control_comparison.md
inventory/*.env
```

By default the multi-gigabyte temporary raw super and extraction work tree are deleted on exit. `--keep-work` is available only for a deliberate local investigation.

## Final contract

A successful C0 run may state:

```text
N1D_C0_COMPLETE=YES
N1D_BUILD_READINESS=PASS
N1D_BUILD_AUTHORIZED_BY_THIS_SCRIPT=NO
N1D_FLASH_AUTHORIZED=NO
N1D_DEVICE_CONTACT_AUTHORIZED=NO
```

`N1D_BUILD_READINESS=PASS` is evidence for the next engineering decision; it is not itself authorization to start a build.

## Source references used to design the gate

- SableOS Titan 2 N1C first-write postmortem and hybrid-super checkpoint in `aimindseye/unihertz-titan2`.
- AOSP `build/target/product/gsi_release.mk` and `target/product/gsi/gsi_skip_mount.cfg`.
- AOSP `system/core/init/selinux.cpp` split-policy compilation path.
- AOSP `system/libvintf/check_vintf.cpp` host compatibility checker.
- AOSP `external/avb/avbtool.py`, including `info_image` / footer resizing semantics.
- AOSP `system/extras/partition_tools/lpdump.cc` JSON LP metadata output.
- `agreenbhm/Unihertz-Titan-2-LineageOS` `build_super_titan2.sh` as a structural reference only.
