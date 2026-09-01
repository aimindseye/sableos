# SableOS Build, Release, and Runtime Validation

This document implements the evidence gates defined by `SECURITY_PRIVACY_ASSURANCE_STANDARD.md`.

## Gate Sequence

```text
1. baseline hashes / guards
2. controlled source mutation
3. source contract audit
4. targeted tests
5. affected build
6. generated-artifact audit
7. compiled SELinux audit
8. full product build
9. exact image-content proof
10. AVB validation
11. expected image-delta classification
12. hardware-security capability record
13. privacy/data-flow/network-egress record
14. inactive-slot deployment
15. runtime security/privacy proof
16. physical behavior proof
17. natural slot success
18. fallback-slot health
19. unresolved-risk + provenance manifest
```

## Assurance Stage

Every device build or release gate must identify:

```text
SABLEOS_ASSURANCE_STAGE=DEVELOPMENT|RELEASE_CANDIDATE|PRODUCTION
```

Development permits `userdebug`, unlocked bootloader/test keys and bounded diagnostics. Production security/privacy claims require the production conditions defined in `SECURITY_PRIVACY_ASSURANCE_STANDARD.md`.

## Baseline

Before mutation verify exact source hashes, absence/presence expectations, and known-good image hashes.

If a baseline guard fails, do not mutate.

## Mutation

After a mutation has applied, do not rerun the whole block to repair a later failure. Use a targeted repair gate from post-mutation hashes.

Never put `exit` or `set -e` into commands intended for an interactive tmux shell.

## Build Output

Write full logs to `/tmp/...` and print bounded tails. With `tee`, preserve the producing command result via `${PIPESTATUS[0]}`.

Avoid recursive scans of giant Soong trees when `build.ninja` or `installs-<product>.mk` provide direct evidence.

Long-running builds should use a persistent terminal such as `tmux` when loss of an SSH session could terminate work.

## Generated Artifacts

Validate effective build topology:

- AIDL backend placement;
- Rust dylib/rlib choice;
- target partition;
- service contexts;
- frozen API dumps;
- production/dev signing state where relevant.

Do not rely only on source declarations when generated build files can prove the result.

## Hardware Security Capability Classification

Build and release gates must distinguish the portable SableOS security baseline from optional hardware-dependent hardening.

The canonical capability state is:

```text
AVAILABLE=YES|NO|UNKNOWN
ENABLED=YES|NO|NOT_APPLICABLE|UNKNOWN
VALIDATED=PASS|FAIL|NOT_APPLICABLE|NOT_RUN
```

The device record should evaluate, where applicable:

```text
MTE
PAC
BTI
TBI_TAGGED_POINTERS
TEE
KEYMINT
STRONGBOX
HW_ROOT_OF_TRUST
KEY_ATTESTATION
KEY_ROLLBACK_RESISTANCE
RPMB_OR_REPLAY_PROTECTED_STORAGE
SECURE_PROCESSOR
AVB_VERIFIED_BOOT
BOOT_ROLLBACK_PROTECTION
IOMMU_OR_DMA_ISOLATION
REMOTE_KEY_PROVISIONING
```

Validation scripts must not convert `NOT_APPLICABLE` into failure. They must not make optional MTE/PAC/BTI/StrongBox/etc. compiler, linker, kernel, allocator or runtime support unconditional on hardware which does not implement the capability.

If a capability is enabled, feature-specific validation is required before the release claims it is active.

The absence of optional hardware does not authorize weakening SELinux, AVB/verified boot, app/process isolation, privilege separation, update integrity or other portable mitigations.

See `HARDWARE_SECURITY_CAPABILITIES.md`.

## Privacy and Data-Flow Classification

Every shipped Sable-owned privileged service, preinstalled application and compatibility component should have a bounded privacy record:

```text
component=
data_classes_read=
data_classes_written=
persistent_storage=
retention=
network_access=YES|NO
network_purpose=
expected_destinations=
identifiers_used=
sensors_used=
privileged_permissions=
user_control=
delete_reset_behavior=
```

Production acceptance requires:

- no unexplained Sable-owned network egress;
- no mandatory Sable telemetry/analytics unless a future explicit privacy policy authorizes it;
- remote diagnostics opt-in by default;
- documented sensitive/persistent stores and deletion/reset behavior;
- no unnecessary persistent identifiers;
- privacy/security UI states backed by actual enforcement;
- third-party/vendor network/data behavior classified separately rather than mislabeled as Sable behavior.

Unknown/empty fields block a production privacy claim. `NONE` and `NOT_APPLICABLE` are valid explicit states.

## SELinux

Validate positive and negative policy:

- provider can register;
- required backend permission exists;
- intended client transaction authority is explicit;
- attribute-based platform grants are included in effective-policy review;
- unauthorized domains cannot transact with the service even if platform policy permits service-name discovery;
- no direct battery sysfs grant where architecture says the vendor HAL owns it;
- no broad policy expansion.

Runtime must remain enforcing. Expected AVC denials from deliberate negative tests should be recorded separately from unexpected runtime denials.

## Image Proof

- extract target binary from filesystem image;
- compare byte-for-byte with built binary;
- verify runtime libraries in expected partition;
- verify service contexts in image;
- verify immutable vendor image unchanged where required;
- verify no development credential/backdoor artifacts in production candidate images;
- verify privacy-sensitive defaults in the actual image where they are image-configured.

## AVB

Validate `system_ext`, `vbmeta_system`, and expected top-level `vbmeta` behavior.

For production, also prove the signing/bootloader state needed for the claimed verified-boot posture. Development unlocked state is recorded as development, not production failure.

## Expected Delta

Expected image deltas are milestone-specific and must be classified from generated content rather than assumed from the primary install partition.

For frozen S1.7 power IPC on bramble, stable AIDL metadata and SELinux policy propagation produce the validated pattern:

```text
system.img          changed
product.img         changed
system_ext.img      changed
vendor_boot.img     changed
vbmeta_system.img   changed   # downstream AVB consequence
vbmeta.img          changed   # downstream AVB consequence

boot.img            unchanged
dtbo.img            unchanged
vendor.img          unchanged # immutable Google prebuilt
```

The root changes were classified file/component-by-file/component: `product` and `system` changes were policy/metadata propagation, `vendor_boot` changed only through its vendor ramdisk policy content, and AVB changes followed their covered partitions.

Unexpected deltas still block deployment until explained.

## Deployment

Determine active/inactive slots at runtime.

```text
known-good active slot
 -> fastbootd
 -> write inactive logical partition(s)
 -> bootloader
 -> write inactive vbmeta partition(s)
 -> verify source preserved
 -> activate target
 -> reboot Android
```

Activation is last.

For a dedicated development device, direct controlled flashing may be used when the device-specific gate explicitly authorizes it, but the script must first verify expected product identity, bootloader state, image hashes and flash target.

## Runtime Security Proof

Verify:

- correct slot/device;
- enforcing SELinux;
- service domain/UID/GID;
- exact host/device binary hash;
- expected service registration;
- authorized client success;
- unauthorized transaction denial;
- expected negative-test AVCs only, with no unexplained relevant AVC denials;
- zero crash evidence;
- daemon stability.

For hardware-dependent security capabilities that are enabled, include feature-specific runtime proof before claiming them. If hardware capability is absent, record `NOT_APPLICABLE` rather than fabricating a pass or failing the device.

Root may be used briefly on userdebug for exact evidence where shell policy intentionally forbids access. Restore normal adb afterward.

## Runtime Privacy Proof

Where applicable verify:

- Sable-owned components classified `network_access=NO` cannot open meaningful direct or indirect network paths;
- mandatory Sable telemetry/analytics is absent;
- diagnostics upload remains disabled until user opt-in;
- expected network destinations match the documented inventory;
- runtime permission/AppOps/security UI reflects actual enforcement;
- sensitive data reset/delete behavior matches the documented claim;
- logs do not expose secrets or unnecessary stable identifiers.

Network/privacy evidence should be captured on a representative physical device for release-candidate/production claims when the feature depends on real networking, modem, sensor or account behavior.

## Physical Proof

When behavior depends on actual hardware state, use actual hardware rather than synthetic state.

This includes hardware-security capability validation when an effective runtime probe exists, and privacy behavior tied to modem/sensors/networking/user interaction.

## Supply-Chain / Provenance Proof

Before a production security claim, preserve evidence for:

- exact source commits/tags and local patch queue;
- build toolchain/compiler provenance;
- critical generated artifact hashes;
- release signing provenance;
- dependency inventory/SBOM where practical;
- offline/pinned build inputs where practical;
- repeatable build procedure;
- security-advisory state for Sable-owned dependencies;
- unresolved risk manifest.

Build provenance should move toward SLSA-style attestable provenance. This is a direction/reference, not a certification claim.

## Acceptance Models

Harness logic must model valid intermediate states.

Both may be correct:

```text
external -> Battery -> external
external -> Battery -> Unknown -> external
```

Capability validation must likewise distinguish `FAIL` from `NOT_APPLICABLE` and `NOT_RUN`.

## Slot Closure

Do not manually mark successful.

Require target naturally successful/bootable and fallback still successful/bootable.

## Production Closure Summary

A production-qualified release should be able to produce a bounded summary including at least:

```text
SABLEOS_ASSURANCE_STAGE=PRODUCTION
SABLEOS_SELINUX=ENFORCING
SABLEOS_AVB=VERIFIED
SABLEOS_BOOTLOADER_STATE=LOCKED_OR_DEVICE_APPROVED_EQUIVALENT
SABLEOS_SECURITY_PATCH_LEVEL_STATUS=VERIFIED
SABLEOS_UNRESOLVED_CRITICAL_SECURITY_RISKS=0
SABLEOS_UNEXPLAINED_SABLE_NETWORK_EGRESS=0
SABLEOS_MANDATORY_TELEMETRY=NO
SABLEOS_PRIVACY_INVENTORY=PASS
SABLEOS_HWSEC_CAPABILITY_RECORD=PASS
SABLEOS_SUPPLY_CHAIN_PROVENANCE=PASS
SABLEOS_UPDATE_RECOVERY=PASS
```

Any unavailable optional hardware capabilities remain separately recorded as `NOT_APPLICABLE` and do not invalidate the portable baseline.