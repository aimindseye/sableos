# N1D C3B E5B standardized deployment

Status: **STANDARD ARTIFACT REGISTRATION + FLASH PLAN IMPLEMENTED / PHYSICAL FLASH STILL FAIL-CLOSED**

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

The N1D C3B plan then:

1. re-verifies the E3 image SHA;
2. verifies the E5B decision and authorization-freeze artifacts through the
   registry;
3. verifies the E3 build-state evidence;
4. determines raw versus Android sparse image format;
5. derives the logical image size used by fastboot;
6. recomputes active-group and total-super capacity against that exact logical
   size;
7. records the fastboot implicit logical-partition resize semantics;
8. emits and seals a no-write plan.

Expected end marker:

```text
N1D_C3B_E5B_STANDARD_FLASH_PLAN=PASS_PREPARED_NO_WRITE
```

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

After that result is reviewed, the next change is a separate execution-
qualification change to the common deployment/adapter path. It must not introduce
a standalone Titan write script.
