# SableOS Build, Release, and Runtime Validation

This document implements the evidence gates defined by `SECURITY_PRIVACY_ASSURANCE_STANDARD.md` and the product-composition rules defined by `CORE_PRODUCT_MODEL.md`.

## Gate Sequence

```text
1. baseline hashes / guards
2. controlled source mutation
3. source contract audit
4. targeted tests
5. affected build
6. generated-artifact audit
7. core-product composition/default-app gate when applicable
8. kernel baseline/update record when kernel-changing or first qualifying the device
9. compiled SELinux audit
10. full product build
11. exact image-content proof
12. AVB validation
13. expected image-delta classification
14. hardware-security capability record
15. privacy/data-flow/network-egress record
16. inactive-slot deployment
17. runtime security/privacy proof
18. physical behavior proof
19. natural slot success
20. fallback-slot health
21. unresolved-risk + provenance manifest
```

The core-product gate and kernel baseline/update gate are conditional. Substrate bring-up builds do not fail merely because Sable-owned product surfaces are not yet integrated, and normal builds whose kernel inputs are unchanged reference/verify the sealed device kernel baseline rather than rebuilding the kernel solely to satisfy policy.

## Assurance Stage

Every device build or release gate must identify:

```text
SABLEOS_ASSURANCE_STAGE=DEVELOPMENT|RELEASE_CANDIDATE|PRODUCTION
SABLEOS_CORE_PRODUCT_STAGE=SUBSTRATE|PRODUCT_INTEGRATION|RELEASE_CANDIDATE|PRODUCTION
```

Development permits `userdebug`, unlocked bootloader/test keys and bounded diagnostics. Production security/privacy claims require the production conditions defined in `SECURITY_PRIVACY_ASSURANCE_STANDARD.md`.

`SUBSTRATE` means Android/device/platform qualification before Sable Home/Hub/AOD/Agent/Voice are required to be present. `PRODUCT_INTEGRATION` begins when those Sable-owned surfaces intentionally enter product images.

## Baseline

Before mutation verify exact source hashes, absence/presence expectations, and known-good image hashes.

If a baseline guard fails, do not mutate.

For a gate which intentionally changes the kernel, also bind the canonical per-device kernel/KMI/module baseline defined by `KERNEL_SECURITY_UPDATE_POLICY.md` before mutation.

For a product-integration gate, bind the intended default-app/product matrix from `CORE_PRODUCT_MODEL.md` and the last known-good AOSP capability baseline before replacing a mature surface.

## Mutation

After a mutation has applied, do not rerun the whole block to repair a later failure. Use a targeted repair gate from post-mutation hashes.

Never put `exit` or `set -e` into commands intended for an interactive tmux shell.

Kernel security mutations must be classified as K1, K2 or K3 before applying them. A K1/K2 gate must reject unexpected KMI/LTS-family change. K3 follows full device/platform migration discipline rather than continuing as a hotfix gate.

A product mutation which removes/replaces an AOSP default must identify the replacement and expected capability delta before mutation. Do not remove an AOSP fallback merely because a Sable UI prototype renders.

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
- production/dev signing state where relevant;
- installed/default product packages and roles when a Sable surface is being integrated.

Do not rely only on source declarations when generated build files can prove the result.

## Core Product Composition Gate

The normative core product is defined in `CORE_PRODUCT_MODEL.md` and ADR-0007.

Canonical status fields:

```text
SABLEOS_CORE_PRODUCT_STAGE=SUBSTRATE|PRODUCT_INTEGRATION|RELEASE_CANDIDATE|PRODUCTION
SABLEOS_CORE_PRODUCT_MODEL=PASS|FAIL|NOT_RUN
SABLEOS_DEFAULT_APP_MATRIX=PASS|FAIL|NOT_RUN
SABLEOS_AOSP_FOUNDATION_PRESERVED=PASS|FAIL|NOT_RUN
SABLEOS_HOME_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_HUB_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_SEARCH_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_SECURITY_PRIVACY_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_AOD_STATUS=NOT_INTEGRATED|PRESENT|ENABLED|DEVICE_UNAVAILABLE|FAIL
SABLEOS_AGENT_STATUS=NOT_INTEGRATED|PRESENT|ENABLED|DISABLED_BY_DEFAULT|FAIL
SABLEOS_VOICE_STATUS=NOT_INTEGRATED|PRESENT|ENABLED|FAIL
SABLEOS_LANGUAGE_BASELINE=PASS|FAIL|NOT_RUN
```

### SUBSTRATE

During device/platform bring-up:

- preserve the selected AOSP application/runtime/platform capability baseline;
- preserve Android locale/font/IME infrastructure;
- preserve notification/conversation, Telecom, PackageManager, PermissionController/AppOps, ContactsProvider, DocumentsUI/SAF, WebView and other foundations needed by the future Sable product;
- record Sable-owned surfaces as `NOT_INTEGRATED` rather than fabricating a pass;
- do not change the active build merely to satisfy future product composition.

The current Panther P1B target-files integration is `SUBSTRATE`. This revised product gate does not restart or invalidate that build.

### PRODUCT_INTEGRATION

When a Sable-owned surface first enters the product, prove at minimum:

- exact package/binary/image presence and hashes;
- intended default/role assignment where applicable;
- no unexpected removal of Android dependencies/capabilities;
- declared permissions, UID, SELinux domain and Binder/service dependencies;
- network/data-flow/privacy inventory;
- localization/Indic text/input coverage for user-facing surfaces;
- crash/restart isolation from privileged services;
- touch/keyboard behavior appropriate to the supported interaction profiles;
- rollback/fallback path while the replacement remains under qualification.

Surface-specific evidence:

**Home** — prove HOME/launcher role/default behavior, application launch/task compatibility and rollback to the retained reference launcher during development.

**Hub** — prove notification/conversation ingestion through Android-supported interfaces, authorized `RemoteInput`/notification-action execution, bounded/local history, no direct reading of other applications' private databases, and lock-screen/privacy redaction behavior.

**Search** — prove Unicode/multilingual behavior, bounded indexing/data authority, and typed action dispatch rather than generic privileged execution.

**Security & Privacy** — prove displayed state corresponds to PackageManager/PermissionController/AppOps/effective platform evidence and does not require root/ADB-supervisor privilege.

**AOD** — prove device support, burn-in mitigation, lock-screen privacy, doze/suspend residency, idle-power impact, and that disabling/failure does not break normal suspend/notifications/lockscreen. `DEVICE_UNAVAILABLE` is valid where the hardware/product cannot support the intended AOD mode.

**Agent** — prove local-first/default provider policy, model/tool provenance, memory/retention controls, explicit network behavior, typed capability allowlist, negative tests against generic shell/root/filesystem/other-app-private-data access, and prompt/tool failure isolation.

**Voice** — prove the language/voice matrix from `LANGUAGE_AND_VOICE_POLICY.md`, including local-first behavior, microphone privacy semantics and no silent cloud fallback.

### RELEASE_CANDIDATE / PRODUCTION

Before the revised core product is release-qualified:

- the intended default-app matrix must be explicit and closed;
- all strategic Sable surfaces intended for that release must be `DEFAULT`, `ENABLED`, or have an explicit product-supported state as defined by the surface;
- any retained AOSP surface must be intentionally retained rather than accidentally left behind;
- replaced AOSP surfaces must have passed capability-parity and physical regression gates;
- no Sable surface may gain broader privilege merely because it centralizes multiple capabilities;
- the product tagline/principle must remain architecturally true: applications provide capabilities while Sable organizes people, attention and actions through authorized interfaces.

## R8 Final UI Product-Composition Gate

For the current Panther R9 UI/product milestone, the generic product-integration gate is specialized by the R9 architecture and source contracts. `R8_PIXEL_UI_PRODUCT_CLOSURE.md` remains historical R8 evidence.

A full Panther build must not be described as the final R9 product build merely because `target-files-package` succeeds. Before starting that build, generated product/build evidence must prove the intended source/package set.

The exact source commit must also have passed the local CI `full` profile before
any fresh Panther target-files build begins. The full profile covers policy,
static contracts, Rust, Android application checks, APK seals, quality,
supply-chain/security checks, standalone Text Reader, Reader and Mail. It writes
the source-bound attestation:

```text
.git/sable-local-ci/<source-commit>.pass
```

The Panther release-candidate driver requires that attestation to contain:

```text
SABLE_LOCAL_CI=PASS
PROFILE=full
SOURCE_COMMIT=<exact build source commit>
```

Module-only physical-UX qualification is intentionally exempt because it runs
before the full-CI gate. A branch advance after CI invalidates the authorization
naturally: the new source commit has no matching attestation and the image build
fails closed.

Required application identities include:

```text
org.sableos.launcher
org.sableos.calculator
org.sableos.sudoku
org.sableos.minesweeper
org.sableos.game2048
org.sableos.media
org.sableos.textreader
org.sableos.reader
org.sableos.hub
org.sableos.mail
org.sableos.weather
org.sableos.calendar
```

The gate must also prove the current UI4/UI5/UI6 source/applicator identities for SystemUI, Settings, SetupWizard2 and Keyguard/frameworks/base.

For each Sable application bind:

- source commit/blob or qualified upstream/composition identity;
- exact APK package name;
- exact APK hash;
- expected install partition/path;
- target-files membership;
- launcher/default role when applicable;
- replacement/retention disposition for the prior Android application.

For the R8 Calculator replacement, `ExactCalculator` must not remain as an accidental competing product implementation. Any intentional retention must be explicit and must not own the intended Sable Calculator role.

The gate fails closed if a standalone Gradle/emulator artifact is qualified but absent from the actual Panther product graph.

Required pre-build marker:

```text
R8_FINAL_UI_PRODUCT_COMPOSITION=PASS
```

Until that marker exists:

```text
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```

Reader/Text Reader requirement: Sable Reader is publication-only and must not
compose the TextReader/OCR runtime or request camera permission. Standalone
Sable Text Reader owns bounded TXT/VIEW/SEND/PROCESS_TEXT, local-only TTS/audio
export and optional camera/gallery OCR. Its source manifest must actively remove
inherited INTERNET via the Android manifest merger, and its final Sable APK must
contain no INTERNET permission. It must also have no translation/model-download
path, a 2 MiB text-ingestion bound, and no network-required TTS voice fallback.
Camera hardware remains optional
and camera permission is scoped to the camera-OCR flow.

## Kernel Baseline and Independent Security Update Gate

SableOS supports independent kernel security updates according to `KERNEL_SECURITY_UPDATE_POLICY.md` and ADR-0005.

### Normal platform/product build

If kernel inputs are unchanged:

```text
sealed device/kernel baseline
        +
platform/Sable changes
        -> normal product build
        -> verify/reference kernel baseline
```

Do **not** rebuild, replace or advance the kernel merely because SableOS supports independent kernel updates.

A normal build should record enough evidence to prove whether kernel-related inputs/images changed. Unexpected kernel-image or module-partition deltas block closure until explained.

### First device kernel qualification

Before a device claims independent kernel-update capability, establish the canonical baseline fields from `KERNEL_SECURITY_UPDATE_POLICY.md`, including where applicable:

```text
SABLEOS_KERNEL_BASELINE=
SABLEOS_KERNEL_RELEASE=
SABLEOS_KERNEL_ANDROID_BRANCH=
SABLEOS_KERNEL_KMI_VERSION=
SABLEOS_KERNEL_SOURCE_COMMIT=
SABLEOS_KERNEL_SOURCE_MANIFEST_SHA256=
SABLEOS_KERNEL_CONFIG_SHA256=
SABLEOS_KERNEL_MODULE_MANIFEST_SHA256=
SABLEOS_KERNEL_BOOT_IMAGE_SHA256=
SABLEOS_KERNEL_SYSTEM_DLKM_SHA256=
SABLEOS_KERNEL_VENDOR_DLKM_SHA256=
SABLEOS_KERNEL_VENDOR_BOOT_SHA256=
SABLEOS_KERNEL_AB_OTA_PARTITIONS=
SABLEOS_KERNEL_BUILD_TOOLCHAIN_PROVENANCE=
SABLEOS_KERNEL_KMI_BASELINE_VALIDATION=
```

The exact applicable partition set is device-specific.

### K1/K2 security build

For an intentional kernel security update:

```text
sealed kernel baseline
        +
provenance-recorded K1/K2 change
        -> supported pinned kernel build
        -> KMI/ABI check
        -> GKI module match where applicable
        -> vendor-module compatibility
        -> affected image/partition build
        -> AVB/signing proof
        -> A/B OTA/deployment proof
        -> physical runtime/rollback closure
```

At minimum require the kernel update record fields defined in `KERNEL_SECURITY_UPDATE_POLICY.md`, including:

```text
SABLEOS_KERNEL_UPDATE_TYPE=K1_SECURITY_BACKPORT|K2_SAME_KMI_SUBLEVEL
SABLEOS_KERNEL_UPDATE_KMI_UNCHANGED=YES
SABLEOS_KERNEL_UPDATE_SOURCE_PROVENANCE=PASS
SABLEOS_KERNEL_UPDATE_ABI_KMI_CHECK=PASS|NOT_APPLICABLE
SABLEOS_KERNEL_UPDATE_GKI_MODULE_MATCH=PASS|NOT_APPLICABLE
SABLEOS_KERNEL_UPDATE_VENDOR_MODULE_COMPATIBILITY=PASS|NOT_APPLICABLE
SABLEOS_KERNEL_UPDATE_BUILD=PASS
SABLEOS_KERNEL_UPDATE_IMAGE_MANIFEST=PASS
SABLEOS_KERNEL_UPDATE_AVB=PASS
SABLEOS_KERNEL_UPDATE_BOOT=PASS
SABLEOS_KERNEL_UPDATE_MODULE_LOAD=PASS|NOT_APPLICABLE
SABLEOS_KERNEL_UPDATE_SELINUX=PASS
SABLEOS_KERNEL_UPDATE_HARDWARE_REGRESSION=PASS
SABLEOS_KERNEL_SECURITY_UPDATE=PASS
```

For production A/B delivery also require rollback/natural-slot evidence where supported.

A kernel version string alone is not evidence that a CVE is fixed. Source/provenance and effective validation are authoritative.

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

A kernel K1/K2 update must also prove the post-update device remains enforcing and has no new unexplained security-relevant AVC or module-load failures attributable to the change.

A core-product integration must prove that presentation surfaces do not directly acquire backend/HAL/device-node authority which belongs behind narrow services.

## Image Proof

- extract target binary from filesystem image;
- compare byte-for-byte with built binary;
- verify runtime libraries in expected partition;
- verify service contexts in image;
- verify immutable vendor image unchanged where required;
- verify no development credential/backdoor artifacts in production candidate images;
- verify privacy-sensitive defaults in the actual image where they are image-configured.

For product-integration builds, verify the exact installed package/binary set and intended default roles against the core-product matrix. Unexpected AOSP app removal or duplicate privileged Sable/AOSP implementation blocks closure until explained.

For kernel-changing builds, hash every affected kernel/module/device image and classify unaffected kernel-related partitions as unchanged or `NOT_APPLICABLE`.

## AVB

Validate `system_ext`, `vbmeta_system`, and expected top-level `vbmeta` behavior.

For production, also prove the signing/bootloader state needed for the claimed verified-boot posture. Development unlocked state is recorded as development, not production failure.

Kernel K1/K2 production payloads must validate the AVB/signing state for all affected boot/kernel/module partitions before activation.

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

For core-product replacement gates, the expected delta must include the exact Sable packages/resources/SELinux/policy/default-role changes and any intentionally removed AOSP package. Do not accept a broad product-image change without package/component classification.

For kernel K1/K2 gates, the expected-delta set is derived from the device's actual kernel/module dependency graph and `AB_OTA_PARTITIONS`; do not globally assume that only `boot` changes.

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

When more than one Android device is attached to the build host, deployment must be bound to an explicit operator-selected serial. Additional ADB or fastboot transports may remain attached only when every mutating device command is serial-scoped and the selected serial is proven present exactly once in the relevant transport before mutation. The presence of unrelated attached devices must not cause an implicit target selection, and a missing or ambiguous selected serial remains a hard failure.

For a production kernel security update, root/unlocked flashing is not the delivery model. Use the Sable-signed supported A/B OTA/update path to the inactive slot, updating the exact affected kernel/module partitions and preserving the prior successful slot through closure.

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

For product-integration builds, also validate surface-specific trust boundaries: Hub actions remain application-authorized; Agent tools remain allowlisted/typed; AOD has no unauthorized private-content/microphone path; Home/Search/Security UI failures do not destabilize privileged services.

For kernel K1/K2 updates additionally verify the target kernel release/build identity, required module load state, absence of update-related kernel panic/oops evidence, and device-critical hardware paths relevant to the kernel change.

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

For Hub/Agent/Voice additionally verify bounded/local retention defaults, no mandatory notification/app-inventory upload, no silent cloud model/speech fallback, and explicit user control over remote providers if present.

Network/privacy evidence should be captured on a representative physical device for release-candidate/production claims when the feature depends on real networking, modem, sensor or account behavior.

## Physical Proof

When behavior depends on actual hardware state, use actual hardware rather than synthetic state.

This includes hardware-security capability validation when an effective runtime probe exists, privacy behavior tied to modem/sensors/networking/user interaction, AOD/doze/burn-in/power validation, voice microphone behavior, and K1/K2 kernel updates which may affect suspend, charging, radio, audio, camera, storage, USB, networking or other driver/module behavior.

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

Sable Home/Hub/Search/Security/AOD/Agent/Voice dependencies and local models are part of the production dependency/provenance inventory when shipped.

Kernel K1/K2 updates also preserve the upstream fixing commit(s), Sable backport/advance provenance, kernel source manifest, config, KMI/ABI evidence and module/image hashes.

Build provenance should move toward SLSA-style attestable provenance. This is a direction/reference, not a certification claim.

## Acceptance Models

Harness logic must model valid intermediate states.

Both may be correct:

```text
external -> Battery -> external
external -> Battery -> Unknown -> external
```

Capability validation must likewise distinguish `FAIL` from `NOT_APPLICABLE`, `NOT_INTEGRATED` and `NOT_RUN`.

A `SUBSTRATE` product build may legitimately record all Sable product surfaces as `NOT_INTEGRATED`; a production product may not use that state to hide missing required surfaces.

A kernel update gate must distinguish an unavailable device-specific independent-update capability from a failed attempted K1/K2 update. A device can remain SableOS-eligible even if its proprietary module/update architecture prevents safe independent kernel updates.

## Slot Closure

Do not manually mark successful.

Require target naturally successful/bootable and fallback still successful/bootable.

For a production kernel security OTA, retain the previously successful kernel slot as fallback until the new slot has passed required runtime/security/physical checks and becomes naturally successful.

## Production Closure Summary

A production-qualified release should be able to produce a bounded summary including at least:

```text
SABLEOS_ASSURANCE_STAGE=PRODUCTION
SABLEOS_CORE_PRODUCT_STAGE=PRODUCTION
SABLEOS_CORE_PRODUCT_MODEL=PASS
SABLEOS_DEFAULT_APP_MATRIX=PASS
SABLEOS_AOSP_FOUNDATION_PRESERVED=PASS
SABLEOS_SELINUX=ENFORCING
SABLEOS_AVB=VERIFIED
SABLEOS_BOOTLOADER_STATE=LOCKED_OR_DEVICE_APPROVED_EQUIVALENT
SABLEOS_SECURITY_PATCH_LEVEL_STATUS=VERIFIED
SABLEOS_UNRESOLVED_CRITICAL_SECURITY_RISKS=0
SABLEOS_UNEXPLAINED_SABLE_NETWORK_EGRESS=0
SABLEOS_MANDATORY_TELEMETRY=NO
SABLEOS_PRIVACY_INVENTORY=PASS
SABLEOS_HWSEC_CAPABILITY_RECORD=PASS
SABLEOS_LANGUAGE_BASELINE=PASS
SABLEOS_SUPPLY_CHAIN_PROVENANCE=PASS
SABLEOS_UPDATE_RECOVERY=PASS
```

Any unavailable optional hardware capabilities remain separately recorded as `NOT_APPLICABLE` and do not invalidate the portable baseline. Device-unavailable optional presentation capabilities such as an unsupported AOD mode must be explicitly classified rather than silently failed or falsely claimed.

If the release includes a kernel K1/K2 security update, also require `SABLEOS_KERNEL_SECURITY_UPDATE=PASS` and bind its exact kernel update record. If the release does not change kernel inputs, bind the existing sealed `SABLEOS_KERNEL_BASELINE=PASS` record instead.
