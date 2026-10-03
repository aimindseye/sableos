# Titan 2 N1I-B: TrebleDroid MTK IMS and real radio-capability-switch analysis

Status: **source analysis only. No device contact, no build, no flash, no install.**

Date: 2026-10-03

```text
BASE_MAIN=20d8df8ff97706c73b2bdbf522fbf3c75abfc6a1
LANE=N1I_B
DEVICE_EXECUTION_AUTHORIZED=NO
```

Machine-readable companion: `docs/titan2/N1I_B_DECISIONS.env`.
Verification script: `build/titan2/audit-n1i-b-trebledroid-mtk-ims-capability.sh`.

## 0. Answer first

Telephony on Titan 2 is two separable problems. Do not merge them.

1. **Registration stability.** LTE/NR_NSA attach, then ERROR_UNSPECIFIED data
   teardown, then reject cause 13. Nothing in C3A source ties this to IMS or to
   `mtkNetworkIndication == NULL`. Cause 13 is a network-originated EMM reject.
2. **IMS / voice.** The configuration routes MMTEL to `com.mediatek.ims`, but no
   package provides it. This is a definite, source-explained defect
   (`CONFIGURATION_POINTS_TO_MISSING_PROVIDER=YES`).

On capability switching:

- AOSP already contains a real, transactional modem capability switch:
  `SubscriptionManagerService.setDefaultDataSubId` -> `remapRafIfApplicable` ->
  `ProxyController.setRadioCapability` -> `RIL.setRadioCapability` ->
  `IRadioModem.setRadioCapability`. It follows the default **data** SIM, not the
  default voice SIM.
- `persist.vendor.radio.simswitch` and `persist.vendor.radio.c_capability_slot`
  appear in no AOSP, TrebleDroid or Restless source. They are vendor-namespace
  state, not an AOSP interface. Writing them is not equivalent to the modem
  operation, so we do not recommend forcing them.
- Whether AOSP actually issues the HAL call on Titan 2 is **unproven offline**.
  A single read-only log line discriminates it (section 6).

On IMS:

- C3A already carries the TrebleDroid MTK IMS selection logic, the PHH-signature
  install trust, and five MTK-IMS-blob compatibility shims (ImsManager,
  SubscriptionManager, TelephonyMetrics, ImsCall hold, incoming-call binder
  thread). Do not re-port them.
- C3A does **not** carry the IMS APK. TrebleApp downloads it at runtime from
  `treble.phh.me`. That makes the TrebleDroid option cheap but network-dependent
  and of unverified provenance.

## 1. Method, pins and limits

```text
SOURCE_ANALYSIS_ONLY=YES
C3A_WORKSPACE_AVAILABLE_TO_THIS_LANE=NO
```

The C3A build workspace (`/srv/sable-build/workspaces/titan2-n1d`) is not
reachable from the cloud container this lane ran in. The C3A contents below are
therefore derived from the **pinned inputs and the exact 369-patch recipe**, not
from the built tree. The audit script takes every source path as a flag so the
build host can re-run it against the real workspace.

| Input | Pin | Used for |
|---|---|---|
| TrebleDroid `treble_app` | `96acf04e74d42a08cc841688686ad3c5d8bd5790` (C3A manifest) | B2 |
| TrebleDroid `device_phh_treble` | `39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed` (C3A manifest) | B1, B4 |
| TrebleDroid `vendor_hardware_overlay` | `bb0bbb9e1314e5312f718ca1d3ea320137d14370` (C3A manifest) | B2, B3 |
| TrebleDroid `vendor_interfaces` | `a2271d260e226e8de5cb1e8c15a229dc90c007dd` (C3A manifest) | B6 |
| `cawilliamson/treble_restlessos` | `4adc5766f457849ca37e0b318bced65aef5a2233` | B1 (369 patches) |
| GrapheneOS `platform_frameworks_opt_telephony` | tag `2026061600` = `e94347b56d44b140331038675c4bdf2fd5d86981` | B3, B4 |
| GrapheneOS `platform_packages_services_Telephony` | tag `2026061600` = `56d3a244ad4ba62fe1143babdf779db7523f8761` | B3 |
| GrapheneOS `platform_frameworks_base` | tag `2026061600` = `e574f68aae07563ed270ca09f135fe24b7d1b788` (two files only) | B3, B5 |
| LineageOS `android_hardware_interfaces` `lineage-23.1` | `cdd5b413be38284ba9474baef4a8cee39b72f7d3` (radio AIDL) | B4, B6 |
| AtlasOS (`Abyss-c0re/atlasos`) | `63d7f4e3dca3a471ea57ec33b0bdda48db1b3b9c` (2026-10-01, reference only) | B5 |

Known limits, stated so nobody over-reads this report:

- AOSP `hardware/interfaces` was not reachable from the cloud lane. The radio
  AIDL was read from the LineageOS mirror of the same Android 16 interface. The
  `setRadioCapability` contract is stable across Android 13-16.
- `treble.phh.me` is not reachable from the cloud lane (proxy 403). The IMS APK
  was never fetched or inspected. Its package name, signature, manifest
  permissions and dex content are **UNVERIFIED**.
- No device logs were available. Runtime facts come from the task statement and
  from existing repo evidence (`N1B2_RADIO_COMPAT_R1.md`,
  `N1B2_CELLULAR_ROOT_CAUSE.md`), and are tagged as such.
- AtlasOS claims (NVRAM rewrites simswitch, the modem reads it at boot, and so on)
  are lab claims by that project. They are quoted as claims, not as facts.

## 2. B1: what C3A already contains

C3A is the pinned GrapheneOS base plus TrebleDroid scaffold plus the exact
RestlessOS 369-patch stack. N1F (the running image) is C3A plus five Sable apps,
with no compatibility-patch delta. Therefore everything in the "present" column
is already in the running image.

Tier counts from the repo inventory: trebledroid 198, trebledroid-staging 121,
rom 29, personal 17, release-builds 4.

| FEATURE/PATCH | UPSTREAM_TREBLEDROID | PRESENT_IN_C3A | NOT_PRESENT_IN_C3A | ATLASOS_ADDITIONAL_CHANGE | RELEVANCE |
|---|---|---|---|---|---|
| TrebleApp IMS menu and logic (`Ims.kt`, `ImsSettings.kt`, `pref_ims.xml`) | YES (`treble_app@96acf04`) | YES. TrebleApp is in `overlay.mk` PRODUCT_PACKAGES; personal hw-overlay patch 0001 swaps in the source-built APK. IMS menu is always enabled (`ImsSettings.enabled() = true`) | - | Atlas hides TrebleApp from IMS; TitanControls is its IMS source of truth (ALGOCUBES A14) | HIGH |
| treble_app staging 0009 (catch IMS download failure) | NO (Restless) | YES | - | - | LOW. Message says `treble.phh.me` TLS cert expired (May 2026) |
| RRO `me.phh.treble.overlay.mtkims_telephony` (`config_ims_mmtel_package=com.mediatek.ims`, target `com.android.phone`) | YES | YES (`treble-overlay-telephony-mtk-ims` in `overlay.mk`); enabled by TrebleApp `Ims.startup` when a MediaTek radio HAL is detected | - | `cmd overlay enable` (redundant) | HIGH |
| Static overlay `me.phh.treble.overlay.mtkims` (target `android`, gated on `persist.sys.phh.ims.mtk=true`) | YES | YES, present but **inactive** | - | Sets the property true | LOW. See section 4: 2 of its 3 resources do not exist in Android 16 |
| Setter for `persist.sys.phh.ims.mtk` | NO. No setter at the pinned revisions | NO setter in C3A | YES, none | Atlas sets it in `titan2-ims-setup.sh`, `phh-on-boot.sh`, heal | LOW |
| MediaTek IMS APK (`ims-mtk-u[-resigned].apk`) | Hosted at `treble.phh.me`, not in git | NO. Not in the system image, not in any pinned repo | YES | Atlas ships `/system/priv-app/MtkIms/MtkIms.apk` and a fallback `ims-mtk-u-resigned.apk` under `/system/etc/titanus2` (hybrid pack, not in git) | CRITICAL |
| PHH signature trust (`PHH_SIGNATURE`, fw/base 0051) | YES | YES | - | - | HIGH. Prerequisite for the `-resigned` variant and for platform-like seinfo |
| `ImsManager.updateImsServiceConfig(Context,int,boolean)` shim (net/ims 0001) | YES | YES | - | - | MEDIUM. MTK blob compatibility |
| `SubscriptionManager.getSimStateForSlotIndex` restored (fw/base 0033: "MTK IMS still needs it") | YES | YES | - | - | MEDIUM |
| `TelephonyMetrics` stub (staging opt/telephony 0001) | NO (Restless) | YES | - | - | HIGH for blob loading. Android 16 removed the class; MTK IMS blob calls it |
| ImsCall inverted hold/resume auto-detect (staging net/ims 0001) | NO (Restless) | YES | - | - | LOW. Only matters once IMS works |
| `ImsPhoneCallTracker` binder-thread conditional revert (opt/telephony 0006) plus `TelephonyUtils` helper (fw/base 0034) | YES | YES, **inert by default**: `ro.telephony.block_binder_thread_on_incoming_calls` defaults true | - | Atlas 0210 flips the default to false | MEDIUM. Legacy IMS incoming calls |
| `ImsResolver` | no patch | AOSP code, unmodified | - | Atlas 0096 calls `ImsResolver.resetIms` | HIGH. Routing semantics (section 4) |
| `ImsPhone` | no patch | AOSP code, unmodified | - | - | MEDIUM |
| `SubscriptionManagerService` | 0001 (do not override third-party calling account) | YES, only that patch | - | Atlas 0096 adds `alignImsCapabilityToVoiceSub` (property writes plus `resetIms`) | HIGH |
| `PhoneSwitcher` | no patch | AOSP code, unmodified | - | - | MEDIUM. Data routing, not capability |
| `RadioCapability`, `ProxyController`, `RIL`, `RadioModemProxy` | no patch | AOSP code, unmodified | - | Atlas writes vendor properties instead of using this path | CRITICAL |
| QNS | none | NOT PRESENT | YES, none | `am broadcast ...TRY_WFC_CONNECTION` | LOW |
| IWLAN | `vndk.rc` sets `ro.telephony.iwlan_operation_mode AP-assisted` only for FLOSS IMS | gated, inactive | - | `persist.data.iwlan.enable true` | LOW |
| CarrierConfig | none (no patch touches the loader) | AOSP code, unmodified | - | `cmd phone cc set-value -p ...` forcing | MEDIUM |
| APN database | staging `device_phh_treble` 0003; `vendor/apn` pin `8b06f423`; rom 0003 and generic_common 0001 remove the AOSP sample list | YES | - | Inserts a "Titan IMS" APN | MEDIUM |
| MTK RIL compatibility in `rw-system.sh` (`AT+EAIC=2` to `3` binary patch, `persist.sys.phh.radio.force_cognitive`) | YES | YES, conditional on `/vendor/*/mtk-ril.so` existing (Titan 2 presence UNVERIFIED) | - | - | LOW-MEDIUM |
| `mtk-sms-fwk-ready` (HIDL `vendor.mediatek.hardware.radio@2.6` `setSmsFwkReady(1)`, slot1/slot2, at boot_completed) | YES (`base.mk`) | YES | - | - | LOW-MEDIUM. Harmless if the HIDL service is absent |
| `phh-on-boot.sh`: if `/vendor/bin/mtkmal` exists and `persist.mtk_ims_support` or `persist.mtk_epdg_support` is 1, set both to 0 and reboot | YES | YES | - | Atlas forces `persist.vendor.mtk_*` instead | MEDIUM. Opposite intent to Atlas |
| `vndk.rc` `persist.sys.phh.restart_ril` handlers | YES | YES, default off | - | Atlas: never default on (UICC drop) | LOW |
| `persist.sys.phh.sim_slots`, `persist.sys.phh.force_euicc_slots` (staging) | NO (Restless) | YES, no-op when unset | - | - | LOW |
| MediaTek radio extension interfaces and clients | `vendor_interfaces` carries the **older HIDL** `vendor.mediatek.hardware.radio@2.0` to `@2.11` definitions (only 2.0 to 2.6 have build modules). It has **no** `mtkradioex` (Android 10+ generation) definitions. Titan 2's vendor exposes `mtkradioex` services per the N1B2 service list. The only client in the source set is `mtk-sms-fwk-ready` (`setSmsFwkReady(1)` on radio@2.6) | Interfaces: older generation YES. Client for MTK indications: NO | `mtkradioex` definitions YES-missing; any MTK indication client YES-missing | none found in Atlas either | see section 7 |
| Samsung and Huawei radio shims (opt/telephony 0002, 0008-0012, fw/base 0046-0047) | YES | YES | - | - | NONE for MediaTek |
| Titan 2 specific telephony overlay in `vendor_hardware_overlay` | no (Unihertz has Jelly2, Luna, TitanpocketEEA only) | NO | YES | - | LOW |

Conclusion for B1: **no C3A patch touches `ImsResolver`, `PhoneSwitcher`,
`RadioCapability`/`ProxyController`, QNS, IWLAN or the CarrierConfig loader, and
nothing implements an MTK RadioEx client.** Those are unmodified AOSP. Do not
describe them as "ported fixes".

## 3. B2: TrebleDroid's MediaTek IMS option

```text
TREBLEDROID_MTK_IMS_AVAILABLE=YES
TREBLEDROID_MTK_IMS_PACKAGE=ims-mtk-u-resigned.apk
TREBLEDROID_MTK_IMS_ALREADY_LOCAL=NO
NETWORK_FETCH_REQUIRED=YES
TREBLEDROID_MTK_IMS_EXPECTED_SERVICE_PACKAGE=com.mediatek.ims
```

`AVAILABLE=YES` means the UI option exists in C3A. It does not mean the artifact
is reachable: the artifact host was not reachable from this lane and the
Restless patch 0009 records an expired TLS certificate at that host.

| Question | Answer | Basis |
|---|---|---|
| Does Settings expose it? | YES | `ImsSettings.enabled()` is hard-coded `true`; header "IMS features" in `pref_headers.xml` |
| Exact UI path | Settings, then "TrebleDroid Settings" (Restless 0002 sets the System category in the manifest metadata; the on-device placement is UNVERIFIED), then "IMS features", then the row titled "Install IMS APK for MediaTek R+ vendor" (preference key `key_ims_install_apn`; the title is rewritten at runtime from "Download and install IMS APK") | `AndroidManifest.xml` alias `TopLevelSettingsActivity`; `pref_ims.xml`; `ImsSettingsFragment.onCreatePreferences` |
| Source class/method | `me.phh.treble.app.ImsSettingsFragment.onCreatePreferences`, the click listener on `ImsSettings.installImsApk` | `ImsSettings.kt` |
| Artifact installed | `https://treble.phh.me/ims-mtk-u-resigned.apk` | `ImsSettings.kt`, the `when` selecting `Pair(url, message)` |
| Package name that results | `com.mediatek.ims` expected. **UNVERIFIED**: APK not fetched. Inferred from the overlay value and from Atlas `pm path com.mediatek.ims` | overlay `config.xml`; Atlas `titan2-ims-setup.sh` |
| Android-generation variant | `ims-mtk-u` ("MediaTek R+ vendor") when any of `gotMtkR`, `gotMtkS`, `gotMtkAidl` is true and `SDK_INT >= 34`. Android 16 (SDK 36) lands here. `-resigned` suffix is chosen because C3A's `services.jar` has the `PHH_SIGNATURE` field (fw/base 0051). No Android 15/16-specific variant exists in this source | `ImsSettings.kt` |
| APK origin | Prebuilt, downloaded. Not source-built. Not in any pinned repo | repo greps; `ImsSettings.kt` |
| Already cached locally? | NO in the image or repos. A copy would exist on-device only after the menu was used (`getExternalFilesDir(DIRECTORY_DOWNLOADS)/ims.apk`); `pm path com.mediatek.ims` empty says it was not installed | task statement; `ImsSettings.kt` |
| Network required? | YES. Android `DownloadManager.enqueue` to the URL above | `ImsSettings.kt` |
| License / provenance | **No license or provenance for the APK in any pinned repo.** `treble_app`, `vendor_hardware_overlay` and `device_phh_treble` have no LICENSE file at the pinned revisions. Hosted on a personal host (`treble.phh.me`). Whether it contains MediaTek-derived code is unknown | repo listing |
| Signing identity | The `-resigned` variant is signed with the PHH key whose certificate is hard-coded as `PHH_SIGNATURE` in C3A `PackageManagerServiceUtils` | fw/base 0051 |
| Installs to /data or system? | `/data/app` through `PackageInstaller` (`MODE_FULL_INSTALL`). Not part of `system.img`. Lost on factory reset | `ImsSettings.kt` |
| Permissions obtained | The installer (TrebleApp) is `android.uid.system`, persistent, platform-signed privapp with `INSTALL_PACKAGES`, `REQUEST_INSTALL_PACKAGES`, `DIAGNOSTIC`, `INTERACT_ACROSS_USERS`. The IMS APK is installed without runtime grants. Its privilege comes from the signature: 0051 makes PHH-signed packages skip signature checks, get `seinfo=platform`, and are accepted by an extra platform-signature comparison in `ScanPackageUtils`. The APK's own manifest permissions are UNVERIFIED | `AndroidManifest.xml`, `privapp-permissions-me.phh.treble.app.xml`, fw/base 0051 |
| Needs root or PHH privileged API? | No root, no `phhsu`. It needs a system-uid installer (TrebleApp) and the PHH-signature trust patch. The overlay switch uses `IOverlayManager.setEnabled`, also system-uid | `OverlayPicker.kt` |
| Other side effect | Before installing, TrebleApp sets `persist.vendor.vilte_support=0`. A vendor-namespace property set from a system app may be denied; the result is not checked | `ImsSettings.kt` |

Security note for the engineering lane. The PHH signature trust patch means any
APK signed by that one key is treated as platform-equivalent in C3A. That is an
accepted property of the **C3A lab control only** (`N1D_RESTLESS_SECURITY_BOUNDARY_R1`:
C3A is not a Sable release baseline). It must not be carried into C3B or a
release. The C3B scaffold decisions already mark `treble_app` and
`vendor/hardware_overlay` as `DROP_DEFAULT`.

### Overlays: what is enabled and where it routes

| Overlay package | Target | Gate | What it sets | Who enables it in C3A |
|---|---|---|---|---|
| `me.phh.treble.overlay.mtkims_telephony` | `com.android.phone` | none (non-static RRO) | `config_ims_mmtel_package = com.mediatek.ims` | TrebleApp `Ims.startup`, when `gotMtkP/Q/R/S/Aidl` is true |
| `me.phh.treble.overlay.mtkims` | `android` | static, `persist.sys.phh.ims.mtk=true` | `config_ims_package`, `config_carrier_volte_available`, `config_dynamic_bind_ims` | nothing. No C3A component sets the property |

Detection logic in `Ims.kt`: HIDL `vendor.mediatek.hardware.mtkradioex@{1,2,3}.0::IMtkRadioEx`
or HIDL `vendor.mediatek.hardware.radio@3.0::IRadio`, or AIDL
`vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/<slot>`, over instance
names `slot1`, `slot2`, `imsradio0`, and others. Existing repo evidence
(`N1B2_CELLULAR_ROOT_CAUSE.md`) says the Titan 2 service list contains
`mtkradioex` data/ims/network/sim/voice AIDL services, so the detection is
expected to succeed. The runtime overlay state itself is **UNVERIFIED** here.

## 4. B3: why the configuration points at a missing provider

Trace, all in pinned source:

```text
TrebleApp Ims.startup()                         (treble_app Ims.kt)
  detects MTK radio HAL -> OverlayPicker.setOverlayEnabled(mtkims_telephony, true)
        |
RRO sets com.android.phone R.string.config_ims_mmtel_package = "com.mediatek.ims"
        |
PhoneGlobals.onCreate(): getResources().getString(R.string.config_ims_mmtel_package)
  -> ImsResolver.make(context, defaultMmtelPackage, defaultRcsPackage, ...)     (PhoneGlobals.java)
        |
ImsResolver: device configuration "com.mediatek.ims" for FEATURE_MMTEL
        |
bind only if doesCachedImsServiceExist(pkg, slot, feature)   (ImsResolver.java)
  -> package not installed => no ImsServiceInfo => no ImsServiceController => no bind
```

Two source facts make the symptom exact:

- `getConfiguredImsServicePackageNameInternal` returns the device package only
  when `doesCachedImsServiceExist` is true. The method's own Javadoc says a
  configured package with no matching application is not bound.
- `isImsServiceConfiguredForFeature` deliberately short-circuits: if the device
  package string is non-empty it returns true, without checking the package
  exists. Telephony therefore believes IMS is configured while nothing is bound.
  This matches "configured as IMS service but `pm path` empty" and the repeated
  `ImsService` unavailable/timeout state.

Static overlay finding. `me.phh.treble.overlay.mtkims` sets `config_ims_package`
and `config_dynamic_bind_ims`. Neither name is defined in the Android 16
(GrapheneOS `2026061600`) `core/res/res/values/config.xml`; only
`config_carrier_volte_available` (default `false`) and
`config_device_volte_available` exist there. So even if the property were set,
that overlay's only live effect would be `config_carrier_volte_available=true`.
It is not the routing mechanism. The routing mechanism is the telephony RRO.

```text
CONFIGURATION_POINTS_TO_MISSING_PROVIDER=YES
```

Qualifier: YES is established for the mechanism and consistent with the task's
runtime observation (overlay configured, `pm path` empty). The live overlay
state was not read in this lane. A prior image (N1B2) recorded the same
resolution: "MMTEL and emergency MMTEL resolve to `com.mediatek.ims`" with
`IMS_SERVICE_DISCONNECTED`.

Smallest corrective options. **Not implemented in this lane.**

| Option | What it is | Cost / risk | Proprietary boundary |
|---|---|---|---|
| A. Install GSI-native MTK IMS | Provide `com.mediatek.ims` via the TrebleDroid option (section 3) | Smallest change. Network download, unverified provenance, Android-14-era APK on Android 16 | Third-party binary; needs a provenance review before any release |
| B. Disable or change the overlay | Disable `mtkims_telephony`, or point `config_ims_mmtel_package` at what is actually installed | Honest no-IMS state, then AOSP default (no IMS). Does not fix voice on a VoLTE-only carrier. Needs a TrebleApp or RRO change, so it is a C3A experiment, not a C3B item | None |
| C. Provide OEM MtkIms | Dependency closure of the stock IMS stack, from Developer A | Largest. Atlas needed a partial OEM port plus healing | Crosses the proprietary OEM IMS boundary; separate admission decision required |

Order of preference: A, then B only if A shows the provider package differs, then C.

## 5. B4: real radio capability switching

### 5.1 The real path

```text
Settings / any MODIFY_PHONE_STATE caller
  SubscriptionManager.setDefaultDataSubId(subId)
    -> SubscriptionManagerService.setDefaultDataSubId          (SMS.java)
       if (mDefaultDataSubId.set(subId))   // only when the value CHANGES
         remapRafIfApplicable()
           phone whose slot maps to default data sub  -> ProxyController.getMaxRafSupported()
           every other phone                           -> ProxyController.getMinRafSupported()
           ProxyController.setRadioCapability(rafs)
              - rejects if any phone is not idle
              - "Already in requested configuration, nothing to do" -> returns true, NO HAL call
              - else doSetRadioCapabilities: START -> APPLY -> FINISH, 45 s timeout, wake lock
                 Phone.setRadioCapability -> RIL.setRadioCapability
                   -> RadioModemProxy.setRadioCapability -> IRadioModem.setRadioCapability (AIDL)
                                                            or IRadio.setRadioCapability (HIDL 1.4+)
```

### 5.2 Direct answers

| Question | Answer |
|---|---|
| What API/event initiates a real switch? | A **change** of the default data subscription (`SubscriptionManagerService.setDefaultDataSubId`). That is the only caller of `ProxyController.setRadioCapability`. `MultiSimSettingController` also calls it when a single primary SIM is inserted or a primary SIM is removed. |
| Who chooses the primary capability phone? | `remapRafIfApplicable`: the phone whose slot maps to the default data subId gets the maximum RAF. No vendor input is consulted. |
| Does default data SIM trigger it? | YES, on change only. |
| Does default voice SIM trigger it? | NO. `setDefaultVoiceSubId` sets the Settings value, the Telecom outgoing account and the default-sub broadcast, and never calls `remapRafIfApplicable`. (AtlasOS 0096 deliberately adds a voice-driven path; that is not AOSP behavior.) |
| Does AOSP currently issue it on Titan 2? | **UNPROVEN offline.** Three conditions must all hold: the default data subId changes; per-phone RAF currently differs, otherwise it is a logged no-op; the HAL supports the call. When the SIM keeps its subscription record (same ICCID, the normal case), moving it between trays keeps the same subId; `MultiSimSettingController` compares subId lists and returns `PRIMARY_SUB_NO_CHANGE`, so a physical tray swap by itself issues nothing. |
| Can a privileged system component request it without vendor framework code? | Indirectly YES, by changing the default data sub. Directly NO: `ProxyController.setRadioCapability` is not exposed over Binder (`PhoneInterfaceManager` only reads RAF) and there is no `cmd phone` subcommand for it. A second HAL client calling `IRadioModem` would bypass RIL's session, and the response routes to RIL's callbacks. We do not recommend it. |
| Does the vendor HAL return success/failure? | Yes. `setRadioCapabilityResponse` carries `RadioResponseInfo`. `REQUEST_NOT_SUPPORTED` is a permanent failure and aborts. A failed START or APPLY triggers FINISH with failure and a revert to the old RAF. What the **MTK** HAL returns is UNVERIFIED. |
| Does switching cause a modem reset? | The AIDL contract warns it "may cause some vendor modems to reset" and that following commands may not be processed. Whether the MTK modem resets is UNVERIFIED. |
| Which events prove completion? | See 5.3. |

### 5.3 Completion evidence (read-only, from logcat)

- `ProxyController`: `setRadioCapability: new request session id=N`, per-phone
  `status=STARTING`, `onStartRadioCapabilityResponse: success=true`,
  `onApplyRadioCapabilityResponse: Valid start expecting notification`,
  `onFinishRadioCapabilityResponse: success=true`, then `clearTransaction`.
  Note: `onNotificationRadioCapabilityChanged: APPLY URC success=` prints the
  failure flag, so `success=false` there means no failure.
- No-op signature: `setRadioCapability: Already in requested configuration, nothing to do.`
- `RILJ`: `> SET_RADIO_CAPABILITY RadioCapability = ...` and the unsolicited
  `UNSOL_RADIO_CAPABILITY` (the AIDL contract says it arrives within 30 s).
- Broadcast `ACTION_SET_RADIO_CAPABILITY_DONE` (success) or `..._FAILED`.
- Modem reset, if any: the `modemReset` indication, RADIO_UNAVAILABLE, RIL
  service death.
- After success the framework re-reads IMEI and device identity
  (`Phone.radioCapabilityUpdated(rc, true)`).

### 5.4 PropertyOnly versus the real operation

```text
PROPERTY_ONLY       persist.vendor.radio.simswitch, persist.vendor.radio.c_capability_slot
REAL_MODEM_OPERATION  IRadioModem / RIL setRadioCapability via ProxyController
```

| Aspect | Properties | Real operation |
|---|---|---|
| In AOSP, TrebleDroid or Restless source | **Zero references** (checked across all pinned trees and all 369 patches) | Full implementation |
| Transaction and acknowledgement | None | START, APPLY, FINISH, session id, timeout, revert on failure |
| Visible to the framework | No | Yes: `Phone.getRadioAccessFamily`, broadcasts |
| Owner | Vendor namespace (`persist.vendor.*`) | Framework |

Classification of the two properties: **vendor-owned persisted state.** Whether
each is an input the vendor RIL reads at boot, an output the vendor RIL writes
after switching, or a cache, is **UNVERIFIED offline**. Atlas claims both: "Vendor
NVRAM resets `persist.vendor.radio.simswitch` to tray 1" and "modem reads this at
boot", and that the phone process cannot write it, so it uses `resetprop_phh`.
If those claims are true the property is, at best, a boot-time input that
bypasses property ownership and does not perform a runtime switch. The name
`c_capability_slot` suggests a C2K (CDMA) capability slot; this is a guess, and
if right it would be irrelevant to a US GSM/LTE SIM.

```text
PROPERTY_FORCING_RECOMMENDED=NO
```

Reason: no source or runtime evidence shows property mutation is required, and
the real path has not yet been observed.

## 6. What to read first (read-only discriminators)

These are descriptions for a later authorized lane. **Not executed here.**

1. In the existing N1H capture or a fresh logcat: grep `ProxyController`. "Already
   in requested configuration" means AOSP considers both phones equal and never
   calls the HAL. "new request session id" means it did.
2. `RILJ` `GET_RADIO_CAPABILITY` responses per phone: do the two phones report the
   same RAF? If yes, the MTK HAL does not distinguish a primary slot through this
   API, and AOSP's switch is a permanent no-op on this device.
3. `pm list features | grep telephony.radio.access`: the AIDL contract returns
   `REQUEST_NOT_SUPPORTED` when that feature is absent.

## 7. B6: `mtkNetworkIndication == NULL`

```text
MTK_NETWORK_INDICATION_NULL_ROOT_CAUSE=UNPROVEN
```

Facts, each from source or existing repo evidence:

- The string is a **vendor-side RILC log** (`radioNetworkServiceImpl[1]->mtkNetworkIndication == NULL`).
  No pinned AOSP, TrebleDroid or Restless source contains `mtkNetworkIndication`.
  Slot index `[1]` is phone 1, which is the tray-2 slot in the N1B2 evidence and
  in the task statement (`gsm.sim.state=ABSENT,LOADED`).
- **Which interface owns it.** The MediaTek extension indication is a *second*
  callback object, registered through a *second* call. In the older HIDL
  generation that is visible in `vendor_interfaces`:
  `vendor.mediatek.hardware.radio@2.0::IRadio.setResponseFunctionsMtk(IRadioResponse, IRadioIndication)`,
  with `IRadioIndication` extending the standard `android.hardware.radio@1.1::IRadioIndication`.
  Titan 2's vendor is the newer `mtkradioex` generation (N1B2 service list shows
  `mtkradioex` data/ims/network/sim/voice services). Its interface definition is
  **not** in the source set, so the exact method list for Titan 2 is unknown.
- **Who normally registers it.** MediaTek's own telephony framework in the stock
  image. That is an inference from outside this source set (stock telephony APKs
  are not imported in C3A by policy).
- **Does C3A have any client able to register it?** NO. AOSP `RIL` never calls
  `setResponseFunctionsMtk` or `setResponseFunctionsIms`; `opt/telephony` mentions
  MediaTek only in the Restless `TelephonyMetrics` stub; `treble_app` only probes
  whether `mtkradioex` service names exist; `mtk-sms-fwk-ready` calls
  `setSmsFwkReady(1)` and registers nothing. No Restless patch adds a client.
- **Do standard indications continue independently?** Yes. AOSP `RIL` registers its
  own `IRadioNetwork` response/indication pair (`mNetworkResponse`, `mNetworkIndication`),
  and the standard `networkStateChanged`, `cellInfoList`, `registrationFailed` and
  `UNSOL_DATA_CALL_LIST_CHANGED` flow through it. The `ERROR_UNSPECIFIED` teardown
  in the existing evidence was reported through that standard path, so the teardown
  report itself was not lost.
- Existing runtime evidence: the null log appeared **during the good LTE window**,
  while "AOSP registration responses still complete successfully", the data call
  succeeded and `ccmni1` came up (`N1B2_RADIO_COMPAT_R1.md`). A condition present in
  both the good and bad windows cannot by itself explain the transition.

What the older HIDL definition shows would be dropped when the MediaTek indication
channel has no consumer. This is the 74-method **older-generation** list
(`vendor.mediatek.hardware.radio@2.0::IRadioIndication`) and is only a guide to the
kinds of events; the Titan 2 `mtkradioex` list may differ.

| Category | Members |
|---|---|
| INDICATIONS_KNOWN_CRITICAL_FOR_BASIC_REGISTRATION | **None demonstrated.** Basic registration completed while the channel was null. |
| INDICATIONS_IMS_OR_MTK_EXTENSION_ONLY | The two observed callbacks, `smartRatSwitchInd` and `responseCsNetworkStateChangeInd` (MediaTek-named, absent from the AOSP radio AIDL; only the second is in any pinned definition). IMS, WFC and VT events: `volteLteConnectionStatus`, `confSRVCC`, `vtStatusInfoIndication`, `speechCodecInfoIndication`, `dedicatedBearer*`, `onWifiPdnActivate`, `onWfcPdnError`, `onWfcPdnStateChanged`, `onPdnHandover`, `onWifiRoveout`, `onNattKeepAliveChanged`, `onLocationRequest`. Messaging, broadcast and STK: `newEtwsInd`, `smsReadyInd`, `meSmsStorageFullInd`, `eMBMS*`, `bipProactiveCommand`, `onStk*`, `phbReadyNotification`, `cfuStatusNotify`, `oemHookRaw` |
| UNKNOWN | Network, data and SIM-state events that could matter and cannot be ruled out offline: `dataCallListChangedEx`, `dataAllowedNotification`, `responsePsNetworkStateChangeInd`, `responseNetworkEventInd`, `networkInfoInd`, `plmnChangedIndication`, `registrationSuspendedIndication`, `gmssRatChangedIndication`, `worldModeChangedIndication`, `resetAttachApnInd`, `mdChangedApnInd`, `onPcoStatus`, `pcoDataAfterAttached`, `onMdDataRetryCountReset`, `onRemoveRestrictEutran`, `onLteAccessStratumStateChanged`, `onSimPlugIn`, `onSimPlugOut`, `onSimMissing`, `onSimRecovery`, `onSimTrayPlugIn`, `onSimCommonSlotNoChanged`. The Titan 2 `mtkradioex` list and semantics are also UNKNOWN |

The UNKNOWN row is why the verdict is UNPROVEN and not "no effect". A consumer
for these is a candidate for a *later*, evidence-driven test; it is not shown to be
the cause.

```text
MTK_RADIOEX_SHIM_PROPOSED_ON_NULL_ALONE=NO
```

A shim would need the Titan 2 `mtkradioex` AIDL definition, which is not in the
C3A source set, and a registered consumer that is itself proprietary-adjacent. Do
not propose one on the strength of a null pointer.

## 8. B5: AtlasOS comparison (reference only, nothing copied)

Reviewed: `patches/gsi_source/0096`, `0210`, and in `packages/titan_ims/`:
`bin/titan2-ims-setup.sh`, `-rearm.sh`, `-simswitch-early.sh`, `-simswitch-hold.sh`,
`-diag.sh`, `init/titan2-ims.rc`. `titan2-ims-diag.sh` is read-only observability and
carries no mutation; its useful checks are folded into section 9.

Each behavior gets exactly one class. Classes: ALREADY_IN_C3A, ARCHITECTURE_REQUIRED,
REQUIRED_ONLY_WITH_OEM_MTKIMS, CAPABILITY_SWITCH_WORKAROUND, BOOT_RACE_WORKAROUND,
CARRIER_SPECIFIC_OVERRIDE, RECOVERY/HEALING_WORKAROUND,
UNSAFE_OR_NOT_ACCEPTABLE_FOR_SABLEOS, NOT_JUSTIFIED_BY_CURRENT_EVIDENCE.

| Key | Behavior (Atlas location) | Class | Note |
|---|---|---|---|
| `PHH_IMS_MTK_PROP` | `setprop persist.sys.phh.ims.mtk true` (setup.sh:42) | NOT_JUSTIFIED_BY_CURRENT_EVIDENCE | Only activates the static overlay; in Android 16 that is `config_carrier_volte_available` alone. Routing is the telephony RRO. |
| `MTK_IMS_OVERLAYS` | `cmd overlay enable ...mtkims_telephony` and `...mtkims` (setup.sh:101-102) | ALREADY_IN_C3A | TrebleApp already enables `mtkims_telephony`. The overlay is only useful paired with an installed provider. |
| `SET_IMS_SERVICE` | `cmd phone ims set-ims-service -s N -c/-d [-f 1] com.mediatek.ims` retry loop (setup.sh:230-233) | BOOT_RACE_WORKAROUND | It is `setBoundImsServiceOverride`, a test override. Redundant when the device overlay and provider are correct. |
| `IMS_ENABLE` | `cmd phone ims enable -s N` (setup.sh:234, 313) | RECOVERY/HEALING_WORKAROUND | Re-registration nudge. |
| `FORCE_CARRIER_CONFIG` | `cmd phone cc set-value -p ...` (VoLTE, WFC, GBA off, entitlement skip) (setup.sh:265+) | CARRIER_SPECIFIC_OVERRIDE | Persistent per-slot overrides. Entitlement and GBA bypass is carrier-specific and masks provisioning. |
| `DATA_ROAMING_UPDATE` | `content update siminfo data_roaming=1`, `settings put data_roaming` (setup.sh:351) | NOT_JUSTIFIED_BY_CURRENT_EVIDENCE | Reject cause 13 is network-originated. Whether a local roaming gate is also involved is not shown by any evidence we hold. |
| `IMS_APN_INSERT` | `content insert carriers` "Titan IMS" (setup.sh:388) | CARRIER_SPECIFIC_OVERRIDE | TrebleApp has its own "Create IMS APN" action; vendor/apn is the data source. |
| `PREFERRED_NETWORK_MODE` | `settings put global preferred_network_mode 11` (setup.sh:91) | NOT_JUSTIFIED_BY_CURRENT_EVIDENCE | In Android 16 `RILConstants`, 11 is `NETWORK_MODE_LTE_ONLY`; the Atlas comment calls it "LTE/NR hybrid". `NR_LTE_GSM_WCDMA` is 26. |
| `VENDOR_SIMSWITCH_FORCE` | `resetprop_phh persist.vendor.radio.simswitch` (setup.sh:169, early.sh:103) | CAPABILITY_SWITCH_WORKAROUND | Property write, bypasses vendor property ownership. Not the modem operation. |
| `C_CAPABILITY_SLOT_FORCE` | `resetprop_phh persist.vendor.radio.c_capability_slot` (setup.sh:170, early.sh:104) | CAPABILITY_SWITCH_WORKAROUND | Same. |
| `SIMSWITCH_HOLD_5S` | Loop re-applying simswitch every 5 s (hold.sh:6-12) | RECOVERY/HEALING_WORKAROUND | Blind periodic loop with root property writes. Violates the repo's healing rules (`HEALING_TRIGGER=OBSERVED_STATE_FAILURE_NOT_PERIODIC_BLIND_LOOP`). |
| `VOLTE_UA_MANUAL_START` | `ctl.start titan2_volte_clientapi_ua`, `titan2_volte_rcs_ua` (setup.sh:481) | REQUIRED_ONLY_WITH_OEM_MTKIMS | Exists because the OEM IMS stack expects the vendor UA and socket. Need with the GSI-native APK is UNPROVEN. |
| `IMSSERVICE_KILL_REARM` | `kill -9 com.mediatek.ims` once if started before the UA socket (rearm.sh:32) | BOOT_RACE_WORKAROUND | Ordering race between ImsService and the UA socket. |
| `INCOMING_BINDER_THREAD` | 0210 flips `ro.telephony.block_binder_thread_on_incoming_calls` default to false | ALREADY_IN_C3A | Restless 0006 already provides the switch with default true. The remaining delta is the default value; it is unjustified until an incoming call is tested with a provider present. Atlas's `persist.sys.phh.allow_binder_thread_on_incoming_calls` is not read by the pinned patch. |
| `SELINUX_PERMISSIVE_FALLBACK` | `setenforce 0` when the clientapi socket is missing (setup.sh:484) | UNSAFE_OR_NOT_ACCEPTABLE_FOR_SABLEOS | Production SableOS must never fall back to permissive. A missing socket is an SELinux policy defect to fix in policy. |
| `QNS_WFC_ACTIVATION` | `am broadcast ...qns.wfcactivation.TRY_WFC_CONNECTION` (setup.sh:503) | CARRIER_SPECIFIC_OVERRIDE | Carrier WFC entitlement gate; out of scope until VoLTE works. |
| `VOICE_SIM_DRIVES_CAPABILITY` | 0096 `alignImsCapabilityToVoiceSub`: voice sub change writes four properties and calls `ImsResolver.resetIms` | CAPABILITY_SWITCH_WORKAROUND | Differs from AOSP, which follows default data. Writes properties from the phone process (Atlas notes they are usually ignored). |
| `VILTE_SUPPORT_ZERO` | `persist.vendor.vilte_support 0`, `persist.dbg.vt_avail_ovr 0` (setup.sh:44-47) | REQUIRED_ONLY_WITH_OEM_MTKIMS | Atlas: VT `.so` is not on the GSI priv-app path, so `ImsVTProvider` throws on incoming. TrebleApp's install flow also sets `vilte_support=0`. |
| `VOLTE_WFC_DBG_OVERRIDES` | `persist.dbg.volte_avail_ovr`, `wfc_avail_ovr`, `allow_ims_off` (setup.sh:43,45) | ALREADY_IN_C3A | TrebleApp's "Force the presence of 4G Calling setting" toggle sets exactly these. |
| `PM_INSTALL_MTKIMS` | `pm install` `/system/priv-app/MtkIms/MtkIms.apk` or `ims-mtk-u-resigned.apk` (setup.sh:70-74) | REQUIRED_ONLY_WITH_OEM_MTKIMS | Provider injection from a non-git hybrid pack. Atlas's HYBRID doc bans "full native IMS inject". |
| `VENDOR_MTK_PROP_FORCING` | `persist.vendor.mtk_volte_support`, `mtk_wfc_support`, `ims_support`, `radio.sim.mode 3`, `radio.volte_state` (setup.sh:404-430) | NOT_JUSTIFIED_BY_CURRENT_EVIDENCE | Opposes upstream `phh-on-boot.sh`, which zeroes `persist.mtk_ims_support`/`epdg_support` and reboots. |
| `MULTI_SIM_SETTINGS_WRITES` | `settings put global multi_sim_data_call`, `multi_sim_sms` (setup.sh:344) | NOT_JUSTIFIED_BY_CURRENT_EVIDENCE | `MultiSimSettingController` owns these defaults. Writing data_call also bypasses `remapRafIfApplicable`. |
| `BIND_ALL_PRESENT_SLOTS` | Bind MMTEL on every present SIM (OEM `mims_support=2`) (setup.sh:237-252, 319-323) | REQUIRED_ONLY_WITH_OEM_MTKIMS | Premised on the OEM stack's dual IMS registration. |

Comparison note: Atlas's own "A15" row (`ImsSelfActivatorImpl IllegalAccessError`
on mobile-terminated calls) points at `ims-mtk-u-resigned`. Atlas therefore also
uses the PHH APK in some form, so "OEM MtkIms or nothing" is not what Atlas shows.

## 9. B7: hypothesis matrix

Verdicts: SUPPORTED, PARTIALLY_SUPPORTED, UNPROVEN, CONTRADICTED.

| ID | Proposition | Verdict | Exact basis |
|---|---|---|---|
| P1 | Capability-slot mismatch can explain the tray-2 failure | PARTIALLY_SUPPORTED | For: Atlas lab claim that MTK IMS/MMTEL follows `simswitch` and that `simswitch=1` with the voice SIM in tray 2 yields a null MMTEL. Against: the tray-2 SIM did register LTE/NR_NSA with working data while `simswitch=1`, so a mismatch does not block basic registration. It is a candidate for the IMS stage only, and unproven even there. The tray-1 result is the arbiter. |
| P2 | Property forcing is equivalent to real radio-capability switching | CONTRADICTED | The real path is a transactional modem command (section 5). The properties are vendor-namespace state that appear in no AOSP source. Atlas itself says the vendor ignores plain setprop and NVRAM rewrites the value. At most it is a boot-time input, not the operation. |
| P3 | Missing IMS can cause incoming-call failure | SUPPORTED | `ImsResolver` does not bind a missing package, so no MMTEL feature exists. A VoLTE-only network then has no voice path. Scope: "can". No call test was run in this lane, and this does not show IMS is the only cause. |
| P4 | Missing IMS causes cause 13 | CONTRADICTED | EMM cause 13 is a network reject ("roaming not allowed in this tracking area", 3GPP TS 24.301). No AOSP code turns IMS state into a registration reject. IMS was equally absent during the earlier good LTE window (`N1B2_RADIO_COMPAT_R1.md`), so a constant condition does not explain the change. Scope: direct or sufficient cause. Vendor-modem coupling cannot be excluded offline. |
| P5 | `mtkNetworkIndication == NULL` causes LTE data teardown | UNPROVEN | Section 7. The null log is vendor-side, appears in the good window too, and the teardown arrived through the standard AOSP indication path. No mechanism linking the null channel to `ERROR_UNSPECIFIED` is shown, but data and network events in the MediaTek channel cannot be ruled out offline. |
| P6 | OEM MtkIms is required before trying GSI-native MTK IMS | CONTRADICTED | As an ordering requirement. C3A already ships the selection logic, the PHH trust patch and five MTK-IMS compatibility shims, and the trial is a download. Atlas also uses `ims-mtk-u-resigned`. This does **not** say the GSI APK will work. |
| P7 | System-only Titan-specific GSI remains viable | PARTIALLY_SUPPORTED | For: C3A and N1F boot on stock vendor/boot with voice, data and NR_NSA registration observed (`N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md`), and Atlas is also a system GSI over stock vendor. Against: IMS/voice end to end is unproven, and Atlas needed provider injection. |
| P8 | Stock-super / system_ext hybrid is required | UNPROVEN | No evidence either way. Policy already forbids stock MTK framework JAR/SO and full vendor copy. Atlas bans "full native IMS inject" after a bootloop history. |

## 10. B8: cheapest IMS experiment (design only)

```text
DEVICE_EXECUTION_AUTHORIZED=NO
N1I_B_EXPERIMENT_EXECUTED=NO
```

Preference order from the task: (1) existing TrebleDroid GSI-native MTK IMS;
(2) minimal routing correction; (3) OEM MtkIms closure from Developer A;
(4) framework patches only for an observed failure; (5) healing only after the
architecture works.

### Preconditions

- Run the **tray-1 registration test first**, with the SIM in tray 1. Then the
  capability slot (`simswitch=1`) is aligned and P1 stops confounding the IMS
  result.
- One change at a time. Record raw failures.
- C3A lab image only. Not a release path (PHH trust patch).

### Step 0: read-only baseline (before any change)

```bash
adb shell cmd overlay list | grep -i -E 'mtkims|treble.overlay'
adb shell pm path com.mediatek.ims                      # expected: empty
adb shell cmd phone ims get-ims-service -s 0 -d -f 1    # device-configured MMTEL package, slot 0
adb shell cmd phone ims get-ims-service -s 1 -d -f 1
adb shell getprop persist.sys.phh.ims.mtk               # expected: empty
adb shell service list | grep -i mtkradioex
adb logcat -d | grep -E 'ProxyController|ImsResolver|ImsServiceController'
```

### Step 1: existing TrebleDroid option

1a. Acquire on the host, not the device, and verify before anything touches the device:

```bash
curl --fail --location --output ims-mtk-u-resigned.apk https://treble.phh.me/ims-mtk-u-resigned.apk
sha256sum ims-mtk-u-resigned.apk                       # record in evidence
apksigner verify --print-certs ims-mtk-u-resigned.apk  # compare to the PHH_SIGNATURE cert in Restless patch 0051
aapt2 dump badging ims-mtk-u-resigned.apk | head       # package name, sharedUserId, targetSdk
unzip -l ims-mtk-u-resigned.apk | grep classes         # dex files
```

Stop here if the package name is not `com.mediatek.ims`, the signer does not match
`PHH_SIGNATURE`, or the host certificate fails (the Restless patch records an
expired certificate): the answer is then option B in section 4, not a bypass.

1b. Install, using the existing option (one of):

- UI: Settings, "TrebleDroid Settings", "IMS features", "Install IMS APK for
  MediaTek R+ vendor". Wait for the toast "IMS apk installed! You may now reboot."
  This needs the device to reach the host itself.
- Host-fetched variant of the same artifact: `adb install -r ims-mtk-u-resigned.apk`.
  This skips the on-device download. TrebleApp's side effect
  `persist.vendor.vilte_support=0` would then not happen; record that difference.

1c. Reboot once. Observe, read-only:

```bash
adb shell pm path com.mediatek.ims
adb shell cmd phone ims get-ims-service -s 0 -d -f 1
adb logcat -b all -d | grep -E 'ImsResolver|ImsServiceController|ImsRILAdapter|NoSuchMethodError|IllegalAccessError|UnsatisfiedLinkError|avc: +denied'
```

Do **not** in step 1: set `persist.sys.phh.ims.mtk`, write any simswitch property,
restart RIL, `setenforce`, insert APNs, force carrier config, or force network mode.

### Interpretation

| Observation | Next step |
|---|---|
| `com.mediatek.ims` bound for MMTEL, state READY | Test registration; then an incoming call. Done with step 1. |
| Installed but package or service differs from the configured name | Step 2: correct the routing value (option B). No property forcing. |
| Process dies on `NoSuchMethodError`, `IllegalAccessError`, `UnsatisfiedLinkError` | Step 4: a framework patch for that one observed symbol only. |
| `avc: denied` for `com.mediatek.ims` | Fix policy. Never permissive. |
| Bound, but MMTEL never READY | Step 3: OEM MtkIms dependency closure from Developer A, which needs its own admission decision. |

### Rollback

`adb shell pm uninstall com.mediatek.ims`. The overlay and image are untouched.

## 11. Final decisions

```text
TRAY2_CAPABILITY_MISMATCH_RELEVANCE=UNPROVEN
REAL_CAPABILITY_SWITCH_IMPLEMENTATION=NO
PROPERTY_HOLD_REQUIRED=NO
TREBLEDROID_MTK_IMS_FIRST_TRIAL=YES
OEM_MTKIMS_NEXT_IF_GSI_IMS_FAILS=YES
FRAMEWORK_PATCH_REQUIRED_NOW=NO
MTK_RADIOEX_SHIM_REQUIRED_NOW=NO
SYSTEM_ONLY_ARCHITECTURE_VIABLE=UNPROVEN
STOCK_SUPER_HYBRID_REQUIRED_NOW=NO
```

| Decision | Justification |
|---|---|
| `TRAY2_CAPABILITY_MISMATCH_RELEVANCE=UNPROVEN` | Plausible for the IMS stage, but the tray-2 SIM registered LTE/NR_NSA with data while `simswitch=1`. The tray-1 test and the `ProxyController` log decide it. |
| `REAL_CAPABILITY_SWITCH_IMPLEMENTATION=NO` | The real switch already exists in AOSP and follows default data. No new SableOS code is justified before the read-only check in section 6 shows it is inert. |
| `PROPERTY_HOLD_REQUIRED=NO` | Properties are vendor-owned, absent from all framework source, and not shown necessary. A blind periodic hold also violates the healing rules. |
| `TREBLEDROID_MTK_IMS_FIRST_TRIAL=YES` | Cheapest option, already wired in C3A with its compatibility shims. Gated on host-side provenance and signer verification and limited to the C3A lab image. |
| `OEM_MTKIMS_NEXT_IF_GSI_IMS_FAILS=YES` | Next in preference order after routing correction. Crosses the proprietary boundary, so it needs a separate admission decision. |
| `FRAMEWORK_PATCH_REQUIRED_NOW=NO` | The needed MTK-IMS shims are already in C3A. A further patch needs a specific observed symbol failure. |
| `MTK_RADIOEX_SHIM_REQUIRED_NOW=NO` | The null indication is not shown to affect registration, and no vendor interface definition exists in the source set. |
| `SYSTEM_ONLY_ARCHITECTURE_VIABLE=UNPROVEN` | Boot, data and registration are proven; IMS/voice end to end is not. |
| `STOCK_SUPER_HYBRID_REQUIRED_NOW=NO` | Nothing in the evidence requires it before steps 1 and 2 are tried. |

## 12. Acceptance markers

Produced by `build/titan2/audit-n1i-b-trebledroid-mtk-ims-capability.sh` against
the pinned sources:

```text
N1I_B_C3A_IMS_PATCH_INVENTORY=PASS
N1I_B_TREBLEDROID_MTK_IMS_PATH=PASS
N1I_B_IMS_PROVIDER_ROUTING=PASS
N1I_B_RADIO_CAPABILITY_SWITCH_PATH=PASS
N1I_B_PROPERTY_VS_MODEM_SWITCH=PASS
N1I_B_ATLASOS_CLASSIFICATION=PASS
N1I_B_MTK_NETWORK_INDICATION_ANALYSIS=PASS
N1I_B_ENGINEER_HYPOTHESIS_MATRIX=PASS
N1I_B_CHEAPEST_IMS_EXPERIMENT_DEFINED=PASS
N1I_B_DEVICE_CONTACT=NO
N1I_B_BUILD=NO
N1I_B_FLASH=NO
N1I_B=PASS
```

`PASS` here means the report's claims were re-checked against source, not that
Titan 2 telephony works.

Run record from the lane that produced this report (cloud container, pinned
checkouts, `--check-scope`, 310 checks):

```text
SRC_TREBLE_APP=96acf04e74d42a08cc841688686ad3c5d8bd5790
SRC_DEVICE_PHH_TREBLE=39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed
SRC_HARDWARE_OVERLAY=bb0bbb9e1314e5312f718ca1d3ea320137d14370
SRC_VENDOR_INTERFACES=a2271d260e226e8de5cb1e8c15a229dc90c007dd
SRC_OPT_TELEPHONY=e94347b56d44b140331038675c4bdf2fd5d86981
SRC_TELEPHONY_APP=56d3a244ad4ba62fe1143babdf779db7523f8761
SRC_RESTLESS=4adc5766f457849ca37e0b318bced65aef5a2233
SRC_ATLASOS=63d7f4e3dca3a471ea57ec33b0bdda48db1b3b9c
CHECKS_TOTAL=310
N1I_B_SCOPE=PASS
```

The script was also run with deliberately wrong inputs (a changed hypothesis
verdict, a changed Atlas class, a flipped decision, a missing AtlasOS checkout, an
`opt/telephony` copy with the remap call removed). Each one produced the expected
FAIL marker, so the checks are not vacuous.

What the script does **not** prove: anything about runtime behavior, the IMS APK
(never fetched), the Titan 2 `mtkradioex` interface, or the built C3A tree. The
last of those is closed by re-running on the build host.

### Re-running on the build host

```bash
cd /srv/sable-build/sableos/repo
bash build/titan2/audit-n1i-b-trebledroid-mtk-ims-capability.sh \
  --atlasos /path/to/atlasos-checkout-at-63d7f4e
```

Defaults point at the C3A workspace and the pinned Restless recipe. Every source
has a flag; `--help` lists them. Re-running against the real C3A workspace is the
way to confirm the "present in C3A" column on the built tree.
