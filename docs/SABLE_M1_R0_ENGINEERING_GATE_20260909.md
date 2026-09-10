# Sable M1-R0 engineering gate closure — 2026-09-09

Status: **PASS / CLOSED**.

M1-R0 establishes the implementation constraints for the first Sable Flow / Sable Start product code before Android source integration or renderer selection.

## Bound artifacts

```text
product/m1/sable-start-engineering-contract-v1.json
  sha256=10b1230af00a9dee6301622a4bd6c6d4016eb5c85704f1d43d5051f36063c5d1
  git_blob=ad751087dd5150a5d93aebb6ab460542e7cf7b4a

tools/validation/product-m1/SABLE_M1_ENGINEERING_PREFLIGHT.py
  sha256=1904208d4d59d78dad7b9ec1dd4dfbf1b1e27e7fab0c868ae1f27fedca34a974
  git_blob=6705206942d120fda53f662e7c5b760b0b9eddcc

tools/validation/product-m1/test_sable_m1_engineering_preflight.py
  sha256=f98d5e5db4ff9f63a5272bb15ca8245da45693c5e61284d78828b6d7ce4ad0e0
  git_blob=4166022fddaef0449ae76f4b379f29a313b2a5a3
```

The branch copies of all three machine-relevant artifacts are byte-bound to the locally validated versions by their Git blob identities.

## Validation

```text
PY_COMPILE=PASS_2_OF_2
ADVERSARIAL_TESTS=PASS_27_OF_27
STATIC_MUTATION_NETWORK_AUDIT=PASS
M1_ENGINEERING_CONTRACT_SCHEMA=PASS
M1_RENDERER_PRECOMMIT_GUARD=PASS_UNBOUND
M1_LAUNCHER3_FALLBACK_POLICY=PASS_REQUIRED
M1_NETWORK_PERMISSION_POLICY=PASS_INTERNET_FORBIDDEN
M1_BOUNDED_SCAN_POLICY=PASS
M1_SOURCE_PRESENT=NO
M1_SOURCE_ABSENCE=PASS_IMPLEMENTATION_NOT_STARTED
M1_READINESS=READY_TO_IMPLEMENT_UNDER_CONTRACT
SABLE_M1_ENGINEERING_PREFLIGHT=PASS
SABLE_M1_ENGINEERING_PREFLIGHT_RC=0
```

Adversarial coverage includes:

- forbidden `INTERNET` permission;
- unreviewed permission creep;
- exported service/receiver cardinality;
- implicit `android:exported` attributes;
- HOME/MAIN/DEFAULT binding;
- explicit backup-disable requirement;
- explicit cleartext-disable requirement;
- shared UID rejection;
- persistent-process rejection;
- process/shell execution fragments;
- raw battery sysfs access;
- unallowlisted Rust `unsafe`;
- unsafe token in comments not causing a false positive;
- source-root and source-file symlink rejection;
- bounded file-count enforcement;
- contract path escape rejection;
- renderer precommit rejection;
- `/tmp`-only optional evidence output;
- relative/non-`/tmp` evidence path rejection;
- existing evidence destination refusal;
- mode `0600` exclusive evidence-file creation.

## Engineering/security policy established

M1 starts with:

```text
RENDERER=UNBOUND_PENDING_QUALIFICATION
ANDROID_HOME_EXPORTED_ACTIVITY=EXACT_1_MAX
EXPORTED_SERVICES=0
EXPORTED_RECEIVERS=0
EXPORTED_PROVIDERS=0
INTERNET_PERMISSION=FORBIDDEN
NETWORK_EGRESS=NONE_M1
TELEMETRY=NONE_M1
BACKUP=EXPLICIT_FALSE
CLEARTEXT_TRAFFIC=EXPLICIT_FALSE
SHARED_UID=FORBIDDEN
PERSISTENT_PROCESS=FORBIDDEN
SHELL_PROCESS_EXECUTION=FORBIDDEN
DIRECT_SYSFS_HAL_DEVICE_ACCESS=FORBIDDEN
SABLE_OWNED_UNSAFE_RUST=FORBIDDEN_UNLESS_SEPARATELY_ALLOWLISTED
UNBOUNDED_CHANNELS_QUEUES=FORBIDDEN
BACKGROUND_POLLING=FORBIDDEN_UNLESS_SEPARATELY_JUSTIFIED
LAUNCHER3_FALLBACK=REQUIRED
```

The only pre-authorized launcher permission is `android.permission.QUERY_ALL_PACKAGES`, required for application visibility and independently consistent with the Android 17 AOSP Launcher3 manifest. Any additional permission requires a contract revision before source lands.

## Performance policy established

```text
PANTHER_MEASUREMENT=REQUIRED
HOT_START_TARGET_MS=150
WARM_START_TARGET_MS=200
START_SCROLL_P95_FRAME_OVERRUN_TARGET_MS=LTE_0
P99_TRACKING=REQUIRED
STARTUP_NETWORK=FORBIDDEN
STARTUP_DISK_IO=MINIMIZE_AND_MEASURE
STARTUP_BINDER=MINIMIZE_AND_MEASURE
IDLE_CPU_REGRESSION=MEASURE
RSS_REGRESSION=MEASURE
```

Performance closure must use distributions/traces rather than averages or visual judgment alone.

## Source disposition

No Sable Start production Rust source is landed by M1-R0. The validation environment used for this deliverable does not contain a Rust compiler, so uncompiled product Rust was deliberately not committed.

That is a gate success, not a blocker: M1-R0's purpose is to establish and validate the implementation contract before source creation.

## Next gate

```text
M1_R1=RENDERER_AND_HOST_TOOLCHAIN_QUALIFICATION
```

M1-R1 should first bind the actual Rust/Cargo/Clang/Soong environment available for the current Panther Android 17 workspace and then qualify the smallest viable Android-managed renderer path against:

- reproducible/offline build integration;
- Android Activity/window/surface lifecycle;
- touch/scroll/frame behavior;
- text shaping / Hindi / RTL;
- accessibility bridge feasibility;
- dependency/supply-chain size and licenses;
- startup/RSS/idle-CPU cost;
- no new privilege requirement.

Only after that gate should the first renderer-independent `start-core` source and Android shell adapter land.

## Authorization boundary

```text
SOURCE_MUTATION_AUTHORIZED=NO
WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
DEVICE_REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
```

M1-R0 repository documentation/validation publication does not authorize Android workspace mutation, build or device operations.
