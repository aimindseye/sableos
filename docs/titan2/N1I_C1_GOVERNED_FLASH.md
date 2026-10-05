# Titan 2 N1I-C1 Governed Flash

Status: governed write-capable tooling for the exact N1I-C1 physical candidate.

This lane is intentionally separate from:

- PR #321: C1 image source/build;
- PR #324: read-only C1 physical runtime collector/qualifier.

The flash lane does not change the C1 image source and does not broaden the
physical qualifier's read-only contract.

Generic Titan write execution remains fail-closed:

~~~text
TITAN2_FLASH_EXECUTION_SUPPORTED=NO
TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO
~~~

C1 is a named exception only for the exact source/SHA below:

~~~text
TITAN2_N1I_C1_EXACT_WRITE_EXECUTOR_ALLOWED=YES_REVIEWED_SCOPE_ONLY
~~~

The central Titan flash guard requires both the generic prohibition and the
exact C1 exception contract, so this work does not silently reopen arbitrary
Titan flashing.

## Exact candidate authority

~~~text
IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
ARTIFACT_ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
ANDROID_PLATFORM=16
SYSTEM_SHA256=137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160
SYSTEM_BYTES=3210661888
TARGET_PARTITION=system_a
~~~

The admitted artifact is the read-only post-build-qualified artifact. The
executor verifies artifact.env, SHA256SUMS.txt, system-image-info.txt and
system.img before any adb or fastboot contact.

The host seal is verified once. The executor does not redundantly hash the
3.21 GB system image a second time after SHA256SUMS verification.

## Explicit authorization

A write run requires both exact flags:

~~~text
--authorize-device-contact YES_FLASH_SYSTEM_A_ONCE
--authorize-flash YES_SYSTEM_A_ONCE
~~~

The read-only receipt finalizer instead requires:

~~~text
--authorize-device-contact YES_READ_ONLY
~~~

and refuses any flash authorization.

## Mode-aware entry

The executor does not assume the Titan's current mode.

It first classifies the exact serial as one of:

~~~text
ANDROID_ADB
FASTBOOT
FASTBOOTD
ADB_UNREADY:<state>
AMBIGUOUS
FASTBOOT_UNKNOWN
ABSENT
~~~

Only the first three can proceed.

Transitions are bounded:

~~~text
ANDROID_ADB
  -> adb reboot bootloader
  -> bootloader fastboot
  -> fastboot reboot fastboot
  -> userspace fastbootd

FASTBOOT
  -> fastboot reboot fastboot
  -> userspace fastbootd

FASTBOOTD
  -> no transition
~~~

After every transition the exact serial is rediscovered. The executor never
uses an unqualified first device.

Unauthorized/offline adb, ambiguous dual visibility, missing devices, duplicate
serial rows, or an unclassifiable fastboot transport fail closed.

If Android is the entry mode, the executor first requires:

~~~text
ro.serialno=<exact requested serial>
ro.product.vendor.device=Titan_2
ro.product.vendor.manufacturer=Unihertz
ro.vendor.build.fingerprint=<exact qualified stock vendor fingerprint>
ro.build.version.release=16
ro.build.version.sdk=36
ro.boot.slot_suffix=_a
sys.boot_completed=1
~~~

System-side ro.product identity is not used as the Titan authority because a
Treble/GSI system can legitimately expose generic product identity.

## Fastbootd geometry contract

A single getvar-all capture is used for prewrite geometry rather than many
repeated getvar subprocesses.

Required:

~~~text
product=Titan_2
current-slot=a
is-userspace=yes
unlocked=yes
snapshot-update-status=none
is-logical:system_a=yes
partition-size:super=9663676416
active *_a-cow count=0
~~~

The live V01.00.14 Titan 2 fastbootd control proves seven materialized active
logical partitions with positive sizes:

~~~text
system_a
system_ext_a
product_a
vendor_a
system_dlkm_a
vendor_dlkm_a
odm_dlkm_a
~~~

Targeted read-only getvars independently prove:

~~~text
odm        = partition not found
odm_a      = partition not found
odm_b      = partition not found
odm_dlkm_a = present / logical
~~~

Therefore odm_a is not merely optional. Unexpected materialization of odm,
odm_a, or odm_b is treated as a topology mismatch and fails closed.

The executor is mode-flexible but baseline-strict. It admits only physically
qualified system_a allocation states:

~~~text
757059584   STOCK_V010014
3146977280  C3A_ANDROID16_CONTROL
3200540672  N1F_PHYSICAL_CONTROL
~~~

The former 2994388992 STOCK_V010014 assumption was incorrect: that value is a
later GSI image/logical target, not the live V01.00.14 stock allocation.

For the exact live stock geometry captured during C1 preflight:

~~~text
CURRENT_LOGICAL_ALLOCATED_BYTES=4203425792
C1_TARGET_SYSTEM_A_BYTES=3210661888
PROJECTED_LOGICAL_ALLOCATED_BYTES=6657028096
PROJECTED_REMAINING_SUPER_BYTES=3006648320
MINIMUM_REMAINING_SUPER_BYTES=536870912
REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES=3263168512
C1_TARGET_WITHIN_REVIEWED_GROUP_CEILING=YES
~~~

The reviewed E5A/E5B deployment package had already established active-group
capacity safety for a 3263168512-byte system target. C1's exact 3210661888-byte
target is below that ceiling.

The established Titan deployment model uses standard Android fastbootd's
implicit logical resize as part of the single flash system_a operation. Manual
resize-logical-partition remains prohibited.

A prewrite size already equal to the C1 target is refused. Any unknown baseline
is refused for owner review.

Projected allocation must fit the exact super size and leave at least 512 MiB
of headroom.

If fastboot exposes both an unsuffixed active alias (for example system) and
the concrete active name (system_a), capacity accounting de-duplicates that
alias rather than counting the same allocation twice. The seven concrete active
logical partitions remain mandatory and unknown additional logical partitions
still consume capacity.

## Mutation boundary

The sole partition-write command in the executable source is:

~~~text
fastboot -s <exact serial> flash system_a <sealed C1 system.img>
~~~

There is no:

~~~text
erase
format
-w
set_active
create/delete/resize-logical-partition
vbmeta flash
boot/vendor/super flash
COW deletion
factory reset
userdata or metadata wipe
automatic retry
~~~

Fastboot's already-qualified implicit logical resize behavior is used for
system_a. There is no manual pre-resize.

## Prewrite attempt journal

Immediately before crossing the irreversible write boundary, after artifact,
mode and geometry qualification have all passed, the executor seals:

~~~text
attempt-journal/
  N1I_C1_FLASH_ATTEMPT_ARMED.env
  SHA256SUMS.txt
~~~

It records the exact serial hash, image source/SHA, target, preflash baseline,
attempt number 1, tool commit and:

~~~text
ATTEMPT_STATE=ARMED
AUTOMATIC_FLASH_RETRY=NO
~~~

The attempt journal exists **before** the fastboot flash command is invoked.
A later run for the same exact serial/image/target refuses another write even
if the earlier process was killed, USB disappeared, fastboot returned nonzero,
or the host crashed before a success result could be journaled.

A corrupt or incomplete attempt journal is also an owner-review condition and
fails closed before device contact. The executor never treats missing success
evidence as permission to repeat a prior armed attempt.

## Known prewrite-abort retirement

The physical run from tool head
`4024d750e5e2eb019ff62532d2a1fe685902c0aa` exposed a Bash `set -u`
bug in the attempt-journal verifier:

~~~text
local root="$1" journal="$root/attempt-journal"
~~~

The shell expands the second assignment before the first local assignment is
established. The run therefore stopped after sealing the attempt journal but
before the `fastboot flash system_a` source line.

An armed attempt journal is still fail-closed by default. It must never be
deleted or manually bypassed.

For this one known prewrite defect, the host-only retirement tool may create a
separate sealed retirement record:

~~~text
build/titan2/retire-n1i-c1-prewrite-abort.sh

attempt-retirement/
  N1I_C1_PREWRITE_ABORT_RETIREMENT.env
  SHA256SUMS.txt
~~~

Retirement is admitted only when all of the following are true:

- the original attempt journal is valid and sealed;
- its tool source is exactly the known buggy `4024d750...` head;
- its serial/image/source/target match the C1 candidate;
- preflight was a clean stock V01.00.14 PASS;
- `write-proof/fastboot-flash-system-a.log` does not exist;
- no postwrite getvar/state exists;
- no command-success journal exists;
- no write-completed proof exists.

The flash-log absence is a strong source-order proof because shell redirection
creates that file before the fastboot executable is launched. Therefore a run
without that file did not cross the write command line.

The retirement tool performs no adb or fastboot commands and preserves the
original attempt journal unchanged. The flash duplicate guard ignores a prior
attempt only when its separate retirement record verifies completely. A
missing, malformed or corrupt retirement remains a hard stop.

The verifier-local defect was also fixed in all three affected functions by
separating dependent local assignments, and the regression suite now rejects
that source pattern.

## Irreversible-point success journal

Immediately after the one fastboot flash command returns zero, before postwrite
qualification or reboot, the executor additionally seals:

~~~text
command-journal/
  N1I_C1_FLASH_COMMAND_SUCCEEDED.env
  fastboot-flash-system-a.log
  SHA256SUMS.txt
~~~

The success journal records:

~~~text
FLASH_ATTEMPT_COUNT=1
FASTBOOT_FLASH_RC=0
FLASH_COMMAND_RESULT=PASS
AUTOMATIC_FLASH_RETRY=NO
~~~

The attempt journal and success journal together are the duplicate-write guard.

Any later invocation for the same exact serial hash, image SHA, image source
and system_a target refuses another write when a valid prior success journal is
found.

A discovered C1 command journal with a bad/missing seal or malformed mandatory
metadata also fails closed before device contact. Corrupt write evidence is an
owner-review condition, never permission to try the write again.

This remains true even if postwrite getvar, reboot, Android observation, or
receipt generation failed.

## Postwrite proof

After a successful flash command the executor captures one new getvar-all state.

It requires:

~~~text
system_a bytes=3210661888
current-slot=a
is-userspace=yes
snapshot-update-status=none
active *_a-cow count=0
~~~

It then seals:

~~~text
write-proof/
  N1I_C1_WRITE_COMPLETED.env
  fastboot-flash-system-a.log
  fastboot-getvar-all-pre.txt
  fastboot-getvar-all-post.txt
  pre-state.env
  post-state.env
  SHA256SUMS.txt
~~~

Only after that proof is sealed does the executor issue one normal fastboot
reboot.

## No reflash after observation failure

A successful system_a write is never automatically repeated.

If any of these later operations fail:

- postwrite getvar;
- postwrite geometry qualification;
- reboot command;
- Android boot observation;
- Android runtime identity;
- receipt creation;

the tool emits a DO_NOT_REFLASH marker.

If the write proof is complete and Android later becomes available, use the
read-only receipt-finalization action rather than rerunning flash.

## Sealed flash receipt

A successful Android return creates:

~~~text
/srv/sable-build/artifacts/titan2/n1i-c1-flash-receipts/<stamp>-<image>-<serial-hash>/
  TITAN2_FLASH_RECEIPT.env
  postboot-runtime.env
  SHA256SUMS.txt
~~~

The receipt includes the exact fields consumed by PR #324:

~~~text
TITAN2_FLASH_RECEIPT_VERSION=1
DEVICE_SERIAL=<exact serial>
ARTIFACT_ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
SYSTEM_SHA256=137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160
TARGET_PARTITION=system_a
FLASH_RESULT=PASS
POST_FLASH_DEVICE_SERIAL=<same exact serial>
POST_FLASH_MODE=ANDROID_ADB
~~~

The directory is private local evidence because the receipt intentionally
contains the exact device serial. PR #324 publishes only the serial hash in its
qualification summary.

## Host-only regression suite

Before physical use:

~~~bash
bash -n   build/titan2/flash-n1i-c1-cellular-isolation.sh   build/titan2/n1i-c1-flash-common.sh   tests/titan2/n1i-c1/test-flash-executor.sh

python3 - <<'PY'
from pathlib import Path
p = Path("build/titan2/qualify-n1i-c1-fastboot-state.py")
compile(p.read_text(encoding="utf-8"), str(p), "exec")
print("N1I_C1_FASTBOOT_QUALIFIER_SYNTAX=PASS")
PY

bash tests/titan2/n1i-c1/test-flash-executor.sh
~~~

The suite uses mock adb/fastboot commands only. It verifies:

- one and only one source-level system_a flash site;
- no forbidden partition/wipe commands;
- no errexit mode-switching in the executor;
- duplicate-write guard definition/order;
- sealed attempt journal occurs before the sole write source line;
- dependent local initializers that can trip `set -u` are forbidden;
- valid known prewrite-abort retirement succeeds with zero-write evidence;
- retirement is refused when a flash log exists or the original tool head differs;
- one adb and one fastboot enumeration per individual mode probe;
- remote fastboot getvar failure text is rejected even when fastboot exits 0;
- Android -> bootloader -> fastbootd transition;
- bootloader -> fastbootd transition;
- fastbootd no-op entry;
- refusal of unauthorized/absent/ambiguous transports without reboot or flash;
- all three accepted known baseline geometries (stock/C3A/N1F);
- exact live V01.00.14 seven-partition allocation arithmetic;
- C1 target remains below the reviewed group-safe target ceiling;
- refusal of unexpected odm/odm_a/odm_b materialization;
- refusal of unknown baseline geometry;
- refusal when system_a already has C1 target size;
- refusal when active COWs are present;
- refusal of truncated active-logical geometry;
- active unsuffixed/`_a` alias de-duplication without weakening inventory;
- postwrite target-size qualification and wrong-size rejection;
- fail-closed corrupt-journal contract.

No physical device contact is authorized by the regression suite.

## Physical command

Do not execute this until the host-only regression suite on the exact flash-tool
head passes.

~~~bash
bash build/titan2/flash-n1i-c1-cellular-isolation.sh flash   --authorize-device-contact YES_FLASH_SYSTEM_A_ONCE   --authorize-flash YES_SYSTEM_A_ONCE   --serial "$TITAN_SERIAL"   --artifact-dir     /srv/sable-build/artifacts/titan2/n1i-c1-cellular-isolation/20261005T133622Z-a745c7daa082-postbuild   --system-image-sha256     137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160
~~~

If the output says the flash write completed but receipt finalization is
pending, do not rerun that command.

After Android is healthy, run only:

~~~bash
bash build/titan2/flash-n1i-c1-cellular-isolation.sh finalize-receipt   --authorize-device-contact YES_READ_ONLY   --serial "$TITAN_SERIAL"   --artifact-dir     /srv/sable-build/artifacts/titan2/n1i-c1-cellular-isolation/20261005T133622Z-a745c7daa082-postbuild   --system-image-sha256     137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160   --write-evidence-dir "<N1I_C1_FLASH_EVIDENCE_DIR from the successful write>"
~~~

The resulting receipt directory is the input to the PR #324 C1 physical
collector.
