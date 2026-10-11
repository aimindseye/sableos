# N1I-IMS1 — AtlasOS / Stock / SableOS compatibility work package (2026-10-11)

**Authority: RESEARCH/STATIC_ONLY.** No build, source mutation, network fetch, device, reboot or flash is authorized by this document.

**Path authority:** Read [N1I cellular evidence path registry](N1I_CELLULAR_EVIDENCE_PATH_REGISTRY_20261011.md) first. In particular the exact stock `system_ext/framework` root is `/srv/data/sable-build/evidence/titan2/n1b2-cellular-static/20260929T131259Z/stock-2026041315-root/system_ext/framework`. Do not rediscover its 22 files.

## Source-backed AtlasOS findings
1. `0096-telephony-ims-follows-settings-calls-sim.patch` changes `SubscriptionManagerService` to set `persist.radio.titan2_simswitch`, `persist.radio.simswitch`, and best-effort `persist.vendor.radio.*` properties and call `ImsResolver.resetIms(slot)` after a default voice-SIM choice. **Do not copy this directly**: validate property ownership, SELinux, source class API, subscription race ordering, and whether resetting IMS causes missed calls.
2. `0210-telephony-incoming-binder-thread-both-phones.patch` changes the `ro.telephony.block_binder_thread_on_incoming_calls` default from true to false in `ImsPhoneCallTracker`. A code change to the default is not evidence of correct threading on our Android 16 base. Check for differing source revisions and callback semantics.
3. AtlasOS developer reports partial OEM IMS port and healing scripts, with occasional missed calls and SIM-switch concerns. These are self-reported observations, **not a passing runtime acceptance suite**.
4. CW1 addresses stock `MtkGsmCdmaCallTracker.invoke-super` ABI linkage, **not automatically an IMS MMTEL incoming-call fix**. Its latest local report is `PASS_EXACT_SUPER_LINKAGE_STATIC_ONLY`; semantics pending.

## Stock comparison inputs by priority
| Priority | Artifact(s) | Specific question |
|---|---|---|
| P0 | `mediatek-ims-base.jar`, `mediatek-ims-common.jar`, `mediatek-ims-extension-plugin.jar` | Which DEX classes and exported contracts underpin IMS registration and MMTEL call lifecycle? |
| P0 | `mediatek-telephony-common.jar`, `mediatek-telephony-base.jar` | Where does radio default SIM/phone ID state enter the MTK telephony code? |
| P1 | `mediatek-framework.jar`, `mediatek-common.jar` | Which framework hooks and services are required by P0, relative to the Android 16 candidate? |
| P1 | `OPCommonTelephony.jar`, `agui-framework.jar` | Do these support previously unmapped or optional dependencies? Note exact filename case. |
| P1 | `mediatek-carrier-config-manager.jar`, `mediatek-telecom-common.jar` | Carrier gating, call routing and Telecom interface assumptions |
| P2 | `mediatek-services.jar`, `agui-services.jar`, `CapCtrlInterface.jar`, `CustomPropInterface.jar` | Only follow concrete DEX references from P0/P1 |

These are prioritization hypotheses, **not claims that each JAR is on the active runtime classpath**. Check bootclasspath / system-server classpath / permissions and package manifest before treating any file as a provider.

## Deliverable IMS1-A: source and contract matrix
Create a single TSV with:
`feature\tconsumer_dex_sha256\tconsumer_owner\tmethod_ref\tstock_provider\tcandidate_provider\tstock_result\tsableos_result\tatlasos_patch\tbehavioral_risk\tevidence_ref\taction`

Required rows:
- IMS MMTEL service discovery, binding and restart.
- Default voice subscription -> IMS phone/slot mapping.
- Vendor radio property ownership and persistence.
- Incoming call `IImsCallSessionListener.onIncomingCall` callback and binder-thread policy.
- SIM slot switch and dual-SIM IMS capability changes.
- Registered-IMS idle retention vs reboot/modem reset recovery.
- Stock plugin class loading and missing optional libraries.

Classify `action` as `KEEP_STOCK`, `SOURCE_PORT_CANDIDATE`, `CONFIG_ONLY`, `RUNTIME_PROBE_REQUIRED` or `UNRESOLVED`. No speculative Java patch while a source field/descriptor or OEM consumer call site is unverified.

## Deliverable IMS1-B: bounded static checks
- Reuse `build/titan2/n1i_static.py` and `build/titan2/n1i-b2-members.py` instead of decompiling every stock JAR again.
- Read D1R2 `FINAL_GAP_SET.tsv` and CW1 link `SUMMARY.json` before classifying new gaps.
- Use already retained JADX output **only if its location has been confirmed**; the current registry marks JADX output paths `UNRESOLVED`.
- Capture a compact evidence manifest (source file, SHA-256, exact class descriptor/callsite, stock provider result, Android 16 candidate result); reject unverified line-number references.
- Do not run scripts that edit the Android checkout, update GitHub automatically, or contact any device as part of this audit.

## Decision gates
1. No proposed patch until the exact SableOS Android 16 owner and stock/JADX callsite are bound.
2. No IMS service reset/healing-loop adoption without evidence of the condition detected, trigger frequency, concurrent calls/SIM switches and cancellation behavior.
3. If source-level change is needed, use a dedicated incremental build branch and warm `out_cw1` only after separately authorizing the expanded IMS mutation scope.
4. Gate full-image assembly and device tests separately; operator wants no more guessed fastboot/fastbootd modes or blind flashes.

## Follow-up state
- CW1 compiled and exact DEX definitions PASS.
- CW1 stock consumer static invoke-super linkage PASS (operator output 2026-10-11), report remains on ai-g732; report checksum **not provided yet**.
- IMS1 static matrix NOT YET EXECUTED.
- Protected source and device mutation NO.
