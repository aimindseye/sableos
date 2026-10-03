# N1D C3B E5B standardized deployment

Status: **STANDARD FLASH PLAN SEALED PASS / N1D EXECUTION QUALIFICATION IN PROGRESS / PHYSICAL FLASH NOT YET OWNER-REAFFIRMED**

This stage moves E5B into the canonical SableOS deployment architecture:

```text
build/sable.sh
 -> build/deploy/artifact_registry.py
 -> build/devices/titan2.sh
 -> build/titan2/prepare-n1d-c3b-e5b-flash-plan.sh
```

It deliberately does not enable `build/sable.sh titan2 N1D flash`.
The existing Titan-wide execution guard remains active until the standardized
N1D plan has been generated, reviewed and bound to the exact fastboot logical
image size.

## Frozen inputs

```text
E3_BUILD_SOURCE=caf98dde723d07a071d95aaa1ef27d578d3208d8
E3_SYSTEM_SHA256=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5
E5B_DECISION_SHA256=74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926
TARGET_PARTITION=system_a
EXPECTED_ACTIVE_SLOT=a
COW_DELETION_ALLOWED=NO
SLOT_CHANGE_ALLOWED=NO
AVB_MUTATION_ALLOWED=NO
BOOT_CHAIN_FLASH_ALLOWED=NO
WHOLE_SUPER_FLASH_ALLOWED=NO
USERDATA_ERASE_ALLOWED=NO
FACTORY_RESET_ALLOWED=NO
```

The manual authorization freeze remains an evidence input. Its SHA-256 is
computed and stored by the standard artifact registry at registration time.
The freeze file is intentionally treated as an opaque, hash-bound historical
evidence artifact; flash planning does not depend on internal freeze-env key
names. Deployment semantics come from the separately hash-verified E5B decision
JSON.

## Canonical registration

Run from the exact merged source containing this integration:

```bash
cd /srv/sable-build/sableos/repo

bash build/sable.sh titan2 N1D register-artifact \
  --build-source caf98dde723d07a071d95aaa1ef27d578d3208d8 \
  --artifact-kind gsi-system-image \
  --primary-artifact system \
  --artifact system=/srv/sable-build/workspaces/titan2-n1d-c3b/out-c3b-engineering/e3-systemimage/20261003T014638Z/target/product/tdgsi_arm64_ab/system.img \
  --expected-sha256 system=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5 \
  --artifact e5b_decision=/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z/e5b-authorization-package.json \
  --expected-sha256 e5b_decision=74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926 \
  --artifact e5b_freeze=/srv/sable-build/evidence/titan2/n1d-c3b-e5b-manual-authorization-freeze/20261003T061712Z/e5b-manual-authorization-freeze.env \
  --build-evidence-dir /srv/sable-build/evidence/titan2/n1d-c3b-e3-systemimage/20261003T014638Z
```

No device command is run by registration.

Then inspect the exact registered record:

```bash
bash build/sable.sh titan2 N1D show-artifact \
  --build-source caf98dde723d07a071d95aaa1ef27d578d3208d8
```

The manifest is expected at:

```text
/srv/sable-build/release-registry/titan2/N1D/caf98dde723d07a071d95aaa1ef27d578d3208d8.json
```

## Canonical standardized flash plan

After registration succeeds:

```bash
bash build/sable.sh titan2 N1D flash-plan \
  --build-source caf98dde723d07a071d95aaa1ef27d578d3208d8
```

The standard registry is verified before the Titan adapter is called.

The canonical flash-plan path first verifies the registered artifact set,
including the E3 image, E5B decision JSON and authorization freeze. The N1D C3B
adapter then consumes that verified state and:

1. treats the authorization freeze as opaque hash-bound evidence;
2. validates deployment semantics from the E5B decision JSON;
3. verifies the E3 build-state evidence;
4. determines raw versus Android sparse image format;
5. derives the logical image size used by fastboot;
6. recomputes active-group and total-super capacity against that exact logical
   size;
7. records the fastboot implicit logical-partition resize semantics;
8. emits and seals a no-write plan.

Sealed result:

```text
N1D_C3B_E5B_STANDARD_FLASH_PLAN=PASS_PREPARED_NO_WRITE
SYSTEM_FORMAT=raw
SYSTEM_LOGICAL_BYTES=2994405376
FASTBOOT_IMPLICIT_RESIZE_TARGET_BYTES=2994405376
ACTIVE_GROUP_PROSPECTIVE_BYTES=6440771584
REMAINING_SUPER_HEADROOM_BYTES=3222904832
MINIMUM_REMAINING_HEADROOM_BYTES=536870912
EVIDENCE_SEAL_SHA256=62f92bff11821979b070b5568038dbae132e6714c87b9b43016be9c5ae503d69
```

The plan therefore removes the earlier manual resize assumption. Standard
Android fastboot will perform the logical-partition resize implicitly as part of
the single `flash system_a` operation. No separate
`resize-logical-partition` command is required or permitted.

## Execution boundary

Even after flash-plan PASS:

```text
SABLE_DEVICE_FLASH_SUPPORTED=NO
SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=NO
TITAN2_FLASH_EXECUTION_SUPPORTED=NO
TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO
```

The earlier owner authorization approved the reviewed E5B mutation concept, but
execution remains held because standard Android fastboot performs an implicit
logical-partition resize as part of flashing a logical partition. The exact
logical size must first be sealed by the standardized flash plan.

The execution-qualification change remains inside the canonical
`build/sable.sh -> build/deploy/flash.sh -> build/devices/titan2.sh` path. It
does not introduce a standalone Titan write script.

The qualified mutation surface is intentionally limited to:

```text
fastboot flash system_a <sealed E3 system.img>
fastboot reboot
```

The first command includes fastboot's implicit resize of `system_a` to exactly
`2994405376` bytes. Before it may execute, the driver must revalidate the
E5A-bound fastboot serial, userspace-fastbootd state, slot `a`, unlocked state,
snapshot status `none`, current `system_a` size `757059584`, super size,
materialized logical allocation and zero active-slot COWs.

Physical execution still requires a fresh owner scope reaffirmation covering
the exact implicit resize to `2994405376` bytes. The scope token is an
execution interlock, not a substitute for that owner authorization. Factory
reset remains separately unauthorized.
