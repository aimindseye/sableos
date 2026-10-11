# AtlasOS reference for Titan 2 / IMS1

Reference repository: https://github.com/Abyss-c0re/atlasos (public, third-party; separate from SableOS).

AtlasOS README describes a LineageOS/MisterZtr GSI patched for Unihertz Titan 2 and combined with stock vendor/boot. Its tracked `patches/gsi_source/SERIES` contains Android source changes.

Relevant source patches:
- [0096-telephony-ims-follows-settings-calls-sim.patch](https://github.com/Abyss-c0re/atlasos/blob/main/patches/gsi_source/0096-telephony-ims-follows-settings-calls-sim.patch): modifies `SubscriptionManagerService` for voice-subscription/IMS slot alignment, radio properties and `ImsResolver.resetIms`.
- [0210-telephony-incoming-binder-thread-both-phones.patch](https://github.com/Abyss-c0re/atlasos/blob/main/patches/gsi_source/0210-telephony-incoming-binder-thread-both-phones.patch): changes default `ro.telephony.block_binder_thread_on_incoming_calls` behavior in `ImsPhoneCallTracker`.
- [0092-settings-keep-disabled-sim-in-list.patch](https://github.com/Abyss-c0re/atlasos/blob/main/patches/gsi_source/0092-settings-keep-disabled-sim-in-list.patch): makes disabled/UICC-off subscriptions visible in Settings.

Developer feedback supplied to SableOS engineering: OEM IMS was partially ported with healing scripts; incoming calls reportedly became mostly stable but can still be missed, and switching SIM slots may cause issues. These are **developer claims, not independent runtime evidence**, and do not demonstrate closure of the SableOS CW1 ABI gap.

Policy: compare implementation and tests, verify patch revision/source correspondence, review permission and property side-effects, and prefer root-cause fixes over recurrent self-healing. AtlasOS code is reference material, not automatically suitable for SableOS.
