# Titan 2 N1I-C2 cellular integration closure R1

Status: **host-side architecture/evidence gate; no source mutation, build, device
contact or flash authorization**

## Why this gate exists

N1I-C1/V6F proved one exact OEM-IMS/framework ABI gap:

```text
stock TelephonyMetrics.writeRilAnswer = (II)V
C3A/C1 TelephonyMetrics.writeRilAnswer = (IIII)V
ImsRILAdapter observed call site       = (II)V
```

That result justifies a candidate compatibility overload. It does **not** justify
treating Titan 2 cellular bring-up as a succession of one-method / one-library
fixes.

AtlasOS and the earlier Titan 2 analysis show that a working MediaTek IMS stack
can span framework ABI compatibility, service binding, package/library/native
closure, vendor-UA ordering, subscription/radio-capability behavior, carrier
configuration, and state-triggered recovery. SableOS must review that envelope
as one architecture before authorizing another cellular image.

The V6G TelephonyMetrics overload therefore remains a **candidate** until this
closure review is complete.

## Security and architecture boundary

Keep the existing C3B boundary:

```text
AOSP phone stack = source-built
stock telephony APK import = NO
full stock framework import = NO
full stock product/system_ext copy = NO
stock vendor/kernel/firmware compatibility = PRESERVE

OEM/VENDOR IMS COMPATIBILITY
    framework/API shims, service binding, carrier/config integration
    -> may be admitted only with exact failure evidence

PROPRIETARY OEM IMS PAYLOAD IMPORT
    APK/JAR/SO from stock system/product/system_ext
    -> separate provenance, signature/shared-UID, licensing, security,
       SELinux and architecture admission
```

No component may be hidden inside a generic "cellular fix".

## AtlasOS clarification

The pinned AtlasOS Titan integration does not contain one standalone Java
"telephony module" that can simply be copied. Its relevant architecture is a
combination of:

- Titan-specific init/shell integration under `packages/titan_ims`;
- a large IMS setup/heal script;
- one-shot ImsService rearm behavior for a UA/socket ordering race;
- a `SubscriptionManagerService` patch that follows the configured Calls SIM;
- an `ImsPhoneCallTracker` incoming-call binder behavior patch;
- carrier/APN/property overrides;
- optional OEM/GSI IMS package installation and binding.

These are references, not an allowlist.

Atlas behaviors remain classified individually. In particular, blind periodic
simswitch/property holds, SELinux permissive fallback, generic RIL restart,
airplane-toggle loops and reboot-as-healing are not acceptable SableOS
solutions.

## Closure lane A: exact Java/framework ABI

Goal: prove the complete OEM IMS Java member surface against the proposed C1
runtime, not merely stop at the first failure.

Required evidence:

```text
A1_IMPORTED_MTK_JAR_MEMBER_CLOSURE=PASS
A2_IMS_APK_MEMBER_CLOSURE=PASS_OR_FULL_CLASSIFICATION
A3_APP_LOCAL_PARENT_FIRST_SHADOWS=REPORT_ONLY
A4_STOCK_TO_C1_ABI_DELTAS=FULL_INVENTORY
A5_DORMANT_JVM_DEBUG_SURFACE=REACHABILITY_CLASSIFIED
A6_NO_BROAD_FAILURE_SUPPRESSION=PASS
```

Known current evidence:

- `mediatek-common.jar`: zero unresolved members.
- `mediatek-ims-base.jar`: zero unresolved members.
- one confirmed TelephonyMetrics legacy overload gap.
- eight AgentPremain/JVM instrumentation failures have zero direct inbound DEX
  references, but fatal suppression remains unauthorized pending a stronger
  reachability/verifier decision.

The final audit must enumerate **all** remaining stock->C1 ABI deltas in one
report before a framework patch set is admitted.

## Closure lane B: OEM IMS package/library/native dependency closure

Review the entire accepted stock IMS dependency graph together:

```text
B1_IMS_APK_IDENTITY_SIGNATURE_SHARED_UID=PASS
B2_REQUIRED_JAVA_LIBRARY_CLOSURE=PASS
B3_OPTIONAL_JAVA_LIBRARY_AUTHORITY=EXPLICIT
B4_JNI_NATIVE_DT_NEEDED_CLOSURE=PASS
B5_NATIVE_SEARCH_PATH_AND_NAMESPACE=PASS
B6_PRIVAPP_PERMISSION_CLOSURE=PASS
B7_SYSCONFIG_FEATURE_CLOSURE=PASS
B8_SELINUX_FILE_AND_DOMAIN_REQUIREMENTS=CLASSIFIED
B9_INIT_SERVICE_SOCKET_AND_PROPERTY_REQUIREMENTS=CLASSIFIED
B10_STOCK_PRODUCT_SYSTEM_EXT_PATH_ASSUMPTIONS=CLASSIFIED
```

The current two JAR imports are not assumed sufficient merely because their
Java member closure passes.

## Closure lane C: Android telephony / IMS integration

Audit the exact runtime/source presence and necessity of each known compatibility
surface:

```text
C1_TELEPHONYMETRICS_LEGACY_ABI
C2_IMSMANAGER_UPDATE_IMS_SERVICE_CONFIG_COMPAT
C3_SUBSCRIPTIONMANAGER_GET_SIM_STATE_FOR_SLOT_INDEX_COMPAT
C4_IMSPHONECALLTRACKER_INCOMING_BINDER_BEHAVIOR
C5_IMSRESOLVER_PROVIDER_SELECTION_AND_BINDING
C6_IMS_SERVICE_READY_REGISTRATION_STATE_MACHINE
C7_MMTEL_AND_EMERGENCY_MMTEL_BINDING
C8_CARRIER_CONFIG_REQUIREMENTS
C9_IMS_APN_REQUIREMENTS
C10_VILTE_VT_NATIVE_DEPENDENCY_POSTURE
```

Every item receives one status:

```text
ALREADY_PRESENT_AND_PROVEN
REQUIRED_BY_EXACT_FAILURE
EVIDENCE_REQUIRED_BEFORE_ADMISSION
NOT_REQUIRED
UNSAFE_OR_POLICY_REJECTED
```

Do not enable Atlas/Treble compatibility switches solely because another ROM
does so.

## Closure lane D: modem/radio capability and DSDS

IMS closure must not hide a second radio-capability defect.

Required model:

```text
D1_STOCK_REAL_RADIO_CAPABILITY_PATH=REFERENCE_PROVEN
D2_GSI_PROXYCONTROLLER_RIL_TRANSACTION=RUNTIME_PROVE
D3_TRAY1_SINGLE_SIM=QUALIFY
D4_TRAY2_SINGLE_SIM=QUALIFY
D5_DUAL_SIM_DEFAULT_DATA_SWITCH=QUALIFY
D6_DUAL_SIM_DEFAULT_VOICE_SWITCH=QUALIFY
D7_RADIO_CAPABILITY_FAILURE_ROLLBACK=OBSERVE
D8_VENDOR_SIMSWITCH_PROPERTY_FORCING=NOT_EQUIVALENT_TO_MODEM_OPERATION
D9_MTKRADIOEX_REQUIRED_BEHAVIOR=EVIDENCE_GATED
```

Do not create a parallel Sable radio-capability implementation unless the
normal `ProxyController -> RIL -> IRadioModem.setRadioCapability` path is
proven insufficient on the GSI.

The observed `mtkNetworkIndication == NULL` message alone remains insufficient
authority for a new RadioEx client.

## Closure lane E: vendor UA / IMS process ordering

Atlas needed explicit vendor-UA startup and a once-per-boot ImsService rearm in
one architecture. SableOS must determine whether the admitted OEM IMS payload
has the same dependency.

Review:

```text
E1_VENDOR_VOLTE_UA_SERVICES_PRESENT
E2_VENDOR_UA_SOCKET_REQUIREMENTS
E3_IMSSERVICE_START_ORDER
E4_PRE_UA_IMSSERVICE_FAILURE_SIGNATURE
E5_REARM_REQUIRED_BY_OBSERVED_RACE
E6_REARM_SCOPE_ONE_SERVICE_ONE_SHOT
```

No kill/restart behavior is admitted without an exact observed ordering failure
and a disabled-healer control.

## Closure lane F: healing architecture

Healing is an architecture component, not a substitute for architecture.

Default policy:

```text
HEALING_DEFAULT=DISABLED_UNTIL_FAILURE_EVIDENCE
HEALING_TRIGGER=OBSERVED_STATE_FAILURE_NOT_PERIODIC_BLIND_LOOP
HEALING_ACTION=SMALLEST_IDEMPOTENT_RECOVERY
HEALING_RATE_LIMIT=REQUIRED
HEALING_SLOT_AWARE=REQUIRED
HEALING_ACTIVE_CALL_SAFE=REQUIRED
HEALING_EMERGENCY_CALL_SAFE=REQUIRED
HEALING_EVIDENCE_LOG=REQUIRED
HEALING_ROOT_CAUSE_MASKING=FORBIDDEN
RIL_RESTART_DEFAULT=FORBIDDEN
AIRPLANE_TOGGLE_LOOP=FORBIDDEN
SELINUX_PERMISSIVE_RECOVERY=FORBIDDEN
REBOOT_AS_HEALING=FORBIDDEN
```

Preferred recovery ladder, only after raw failure capture:

```text
1. classify IMS/radio/subscription state
2. restore a bounded configuration only if drift is proven
3. re-enable/re-register the affected IMS feature
4. rebind only the affected slot if proven necessary
5. restart only a narrowly scoped IMS/vendor service if proven safe
6. modem/RIL restart requires a separate exception
```

Any healer must log trigger, slot, subscription, action, result, cooldown and
recurrence count. A test is not considered PASS merely because a healer hid the
underlying failure.

## Closure lane G: runtime acceptance

A cellular candidate is not complete at "IMS registered".

Minimum acceptance:

```text
CELLULAR_REGISTERED_AFTER_BOOT=PASS
CELLULAR_DATA_STABLE_30_MIN=PASS
CELLULAR_SURVIVES_REBOOT_X3=PASS
CELLULAR_SURVIVES_AIRPLANE_TOGGLE=PASS
CELLULAR_LTE_DATA=PASS
CELLULAR_5G_DATA=PASS_OR_NETWORK_GATED_WITH_REASON
CELLULAR_VOICE_CALL_MO_MT=PASS
CELLULAR_SMS_MO_MT=PASS
CELLULAR_MMS_MO_MT=PASS
NO_COM_ANDROID_PHONE_CRASH=PASS
NO_RADIO_SELINUX_DENIAL=PASS
VOLTE_IMS=PASS_OR_CARRIER_GATED_WITH_REASON
TRAY1_SINGLE_SIM=PASS
TRAY2_SINGLE_SIM=PASS
DUAL_SIM=PASS_OR_CARRIER_GATED_WITH_REASON
DEFAULT_DATA_SWITCH=PASS
DEFAULT_VOICE_SWITCH=PASS
```

For a healing-enabled candidate also require:

```text
CELLULAR_HEALER_DISABLED_CONTROL_CAPTURE=PASS
CELLULAR_HEALER_TRIGGER_EVIDENCE=PASS
CELLULAR_HEALER_SECOND_CALL_RECOVERY=MEASURED
CELLULAR_HEALER_MISSED_CALL_RATE=MEASURED
CELLULAR_HEALER_SIM_SWITCH_STABILITY=PASS
CELLULAR_HEALER_REBOOT_STABILITY=PASS
```

## Admission order

Do not admit deltas one discovery at a time. Complete the host-side closure
matrix first, then create one reviewed cellular candidate set.

Order:

```text
1. resolve exact source authority / workspace
2. complete Java + native + package dependency closure
3. classify all framework/telephony compatibility deltas
4. classify vendor-UA/service-order requirements
5. classify capability/DSDS requirements
6. define healer state machine, disabled by default
7. review one proposed mutation set
8. build one candidate
9. rerun full sealed linkage qualification
10. physical runtime qualification with healer disabled first
11. only enable a healer for an observed reproducible failure
```

## Current V6G candidate disposition

```text
TELEPHONYMETRICS_TWO_ARG_OVERLOAD=EVIDENCE_BACKED_CANDIDATE
TELEPHONYMETRICS_APPLY_AUTHORIZED=NO_PENDING_C2_CLOSURE
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

The V6G host regression remains valid evidence. The verify-only source check
failed because the assumed `frameworks/opt/telephony` checkout path did not
exist; that is a source-authority discovery problem, not authorization to search
for another arbitrary checkout and patch it.

## C2 exit condition

N1I-C2 closes only when the proposed cellular mutation set is finite and
reviewable:

```text
C2_SOURCE_AUTHORITY=PASS
C2_FULL_JAVA_ABI_DELTA=PASS_COMPLETE
C2_NATIVE_DEPENDENCY_CLOSURE=PASS
C2_TELEPHONY_INTEGRATION_MATRIX=PASS_COMPLETE
C2_VENDOR_UA_ORDERING=PASS_CLASSIFIED
C2_RADIO_CAPABILITY_DSDS_MATRIX=PASS_CLASSIFIED
C2_HEALER_DESIGN=PASS_DISABLED_BY_DEFAULT
C2_PROPOSED_MUTATION_SET=PASS_FINITE_REVIEWED
C2_BUILD_AUTHORIZATION=SEPARATE_NEXT_GATE
```
