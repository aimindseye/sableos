# Titan 2 V01.00.14 — stock-first cellular/voice execution-flow discovery

**Authority:** discovery contract for draft PR348. **State:** accepted Phase2C forensic checkpoint, stock flow still **NOT RECONSTRUCTED**. This is a host/source evidence plan, not a PR347 repair plan. No AOSP image build, device contact, stock restoration, flash, OEM binary import, or source modification is authorized.

## Non-negotiable scope correction (2026-10-28)

**Do not filter stock discovery by PR347, C3A, current FLOSS IMS, currently selected packages, presumed patch candidates, or historical runtime symptoms.** SableOS has not established the complete functional path used by factory V01.00.14 for outgoing/incoming voice or per-SIM recovery. Restricting discovery to existing PR code would assume the answer. PR342/344/345/346/347 and C2 are **downstream reconciliation/acceptance** contexts, never a gate to deciding whether a stock component, callback, or call-graph edge is worth observing.

Separate three artifacts with independent conclusions:

1. **Stock execution model**: what V01.00.14 ships, loads, calls, signals, times, and recovers from. Inventory all relevant and *apparently unrelated* components across the full partitions, not merely the six matching AOSP16 framework JARs. Preserve untraced paths, unresolved dynamic dispatch and native/modem black boxes explicitly.
2. **OEM-versus-upstream difference**: compare the observed stock implementation with version- and module-matched upstream Android 16; account for compiler output, stock March 2026 security backports, GMS/Mainline packaging, and its Android 14 vendor BSP. A stock-only symbol is not yet proven OEM-authored.
3. **SableOS integration decision**: only **after** the stock model and necessary differences have evidence, compare with exact selected PR347/current compiled image and decide on minimal safe compatibility changes. Missing callers in today's PR347 **must not remove an item from the stock discovery ledger**.

### Already proven and limits

- Stock V01.00.14 `system` is Android 16, build `BP2A.250605.031.A3`; `vendor` advertises Android 14 `UP1A.231005.007`. Phase1 stock-vs-AOSP16-r2 provenance PASS.
- Factory stock has passed outgoing and incoming voice, data and messaging with the same physical SIM independently in tray 1 and tray 2. Stock dual-SIM DSDS remains unqualified.
- OEM IMS provider is `/system_ext/priv-app/ImsService/ImsService.apk` (`com.mediatek.ims`, shared `android.uid.phone`); two required Java libraries include `mediatek-common.jar` and `mediatek-ims-base.jar`. Its native/vendor and platform-APEX dependencies require provenance-sensitive closure.
- Stock observations show `+CIREGU` progression and `setImsRegistrationState registered=true`, a separately connected IMS bearer (`ccmni2`) and default data (`ccmni1`), and a tray-2 radio-capability transaction (`MtkProxyController`, `NW_SET_RADIO_CAPABILITY_REQ`). **These are observed milestones, NOT an end-to-end reconstructed outgoing/incoming call path.** A transient `mtkImsIndication == NULL` can occur before successful registration; avoid false causal attribution.
- Exact matched-A16 Phase2 analyzed six system framework JARs, 13,749 defined declaration differences; Phase2B retained them all and prioritized 5,770. Phase2C accepted 256 historical exact-member overlaps, 432 owner families, and a *sample only* of 84 descriptors / 32 owners. The 32/3 caps are a **display sampling policy only**, never discovery or parser stop conditions. V5 historical 3,891 signatures are evidence hints, not a complete stock flow; original 4,785 ledger is not recovered.
- No present result establishes all callsite transitions, system service/Binder routing, IMS registration-to-dial linkage, SIP/UA/native/modem behavior, media path, emergency/CS fallback, or failure-recovery flow. No current PR347 ABI gaps proven.

## Discovery universe — independent of PRs

Cover the **entire pinned V01.00.14 stock system, system_ext, product, and vendor images**, including:
- APK/priv-app and JAR DEX definitions **and actual invoke/callsite references**, all dex splits, ART boot/system-server class paths, load priority and packages; register each artifact and SHA. Include Dialer, Telecom, Telephony, TeleService, Phone, Carrier Services, messaging, OEM IMS, JNI wrappers, service registries, SystemUI and any encountered helpers. Do not assume any component is out of scope from its filename.
- APEX/CAPEX internals, active module versions, packaged JARs/native `.so`, VNDK namespace boundaries, system_ext shared-UID/signature and permission dependencies.
- `init*.rc`, VINTF HAL declarations, SELinux, properties, overlays/carrier/APN configs, network transport and modem/radio services. Native edges: JNI registration/dlsym, `DT_NEEDED`, binder/AIDL/HIDL, vendor IMS UA sockets, interfaces and callbacks. Mark unobservable proprietary modem internals explicitly.
- Both normal and exceptional paths, including callbacks, reflection, classloading, scheduled work, broadcasts, binder asynchronous returns, retry/backoff and runtime state changes. Static call graphs cannot fully prove runtime reachability; do not fabricate it.

Do not cap the **stored** graph by `REVIEW_FIRST_N`, highest score, six JARs, or a predetermined number of components. Ranking applies only to analyst order, after complete source enumeration with honest unsupported-artifact holds.

## Stock call-path experiments and independent scenario matrix

Build independent **outgoing** and **incoming** voice timelines (not one synthesized common path), plus registration, recovery, call teardown and slot/capability selection. For each scenario, map expected events to observed evidence and label missing events as UNKNOWN:

1. Boot, package/process/service readiness; SIM/ISIM visibility; active subscription, default voice/data/SMS, radio capability and modem stack readiness.
2. APN, carrier entitlement/config, RIL registration and default/IMS bearer establishment; MMTEL feature binding, IMS registration/capabilities, WFC/VoLTE transitions.
3. Dial/UI → Telecom → Telephony → selected CS or IMS route → MMTEL/IMS CallSession → MediaTek IMS → UA/native → modem/network; include outgoing alerting, answer, audio route and termination. The chain is a **hypothesis** until each edge is backed by stock source or runtime traces.
4. Network/modem unsolicited incoming event → IMS/CS indication → Telephony/Telecom → Ringing UI → answer/reject and audio → teardown. Verify direction-specific binder thread, lifecycle and missed-call delivery.
5. IMS unavailable, loss of registration, bearer failure and recovery; CS fallback, roaming/WFC policy, carrier configuration effects; emergency route. Do not force modem resets, airplane cycling or permissive SELinux as a debugging shortcut.
6. One SIM each in tray 1 and tray 2 (stock controls already PASS); two simultaneous SIMs, voice/data default swaps, call hold/swap/handover, incoming-on-other-SIM and per-subscription registration (UNQUALIFIED until a separately approved stock runtime experiment).

**No automation should originate real calls on the user's behalf.** Existing raw stock control captures should be reused first. A live experiment must require a factory-stock-identity check and explicit separate authorization; the current Titan 2 may not be booted in stock. Existing `build/titan2/capture-n1b2-cellular-runtime.sh` can support read-only runtime logging *when stock is already installed*. Its logs contain sensitive subscriber and caller data; reuse `build/titan2/sanitize-n1i-stock-control.py` and manually review redaction before sharing. No capture in this charter contacts the device.

## Evidence graph and semantics

Maintain four independent ledgers (all retained, no default filtering):
- **ARTIFACTS**: partition, path, SHA256, APK/JAR/APEX/ELF, SDK/security patch, platform signature/shared UID, extracted-member hash, exact source reference when supported.
- **NODES/EDGES**: concrete caller/callee signature or service/interface/socket/intent/property, direction, process/partition/classloader, edge type (DEX_INVOKE, BINDER_CONTRACT, VINTF_LINK, JNI_LINK, NATIVE_NEEDED, CONFIG_SELECTION, EVENT_CALLBACK, RUNTIME_OBSERVED), exact file/offset/timestamp/evidence location.
- **SCENARIO_TIMELINES**: stock incoming/outgoing and failure/recovery per SIM, wall-clock/monotonic order when available; observed/expected/unknown status. **Do not claim a total call path from selected log snippets**.
- **OPEN_BOUNDARIES**: dynamic dispatch, reflection, APEX/classloader uncertainty, native entrypoint, radio HAL, modem/UA SIP internals, non-observed call states, missing raw logs, privilege restrictions and proprietary code. Each open boundary has a concrete next evidence requirement, not an assumed edge.

Each edge/decision must declare one evidence grade: `RUNTIME_OBSERVED` (captured on stock and time-correlated), `STATIC_EXACT` (concrete invoke/service contract), `CONFIG_ONLY`, `HYPOTHESIS`, or `UNKNOWN`. Runtime observation of two adjacent events is **not** necessarily an observed method-to-method call. Source matched by major Android version is **not** by itself authorship or post-June-2025 upstream-backport exclusion.

## Sequence of next deliverables and explicit stop conditions

**3A — offline full-stock topology and preexisting control reconciliation (NEXT):** verify prior SHA seals, no firmware re-download, enumerate all relevant DEX/native/config/Android components across four stock partitions and record full caller/event graph starting from both outgoing and inbound seeds, including transitive expansion. Reuse older validated extractors where possible. Record all unresolved native/reflection/IPC edges as UNKNOWN. Reconcile already captured stock tray-1/tray-2 logs with provenance, without device contact. **If the complete partition/APEX set cannot be decoded, report a partial topology HOLD and exact uncovered artifacts; do not call the graph complete.**

**3B — host-only method behavior:** targeted JADX/deodex and Ghidra of exact owners at graph branch points (subscriptions, IMS registration, MTK IMS callbacks, RIL/radio capability, audio, APN/recovery, incoming/outgoing). Compare AOSP16 source and later upstream patches. All 432 Phase2C owner families remain accessible for queries; its 84 selected descriptors seed *human review only*, never a discovery cutoff.

**3C — factory-stock runtime path (SEPARATELY AUTHORIZED):** if existing captures cannot confirm linkages, obtain operator approval and a verified stock-booted device before a privacy-safe, timestamped outgoing/incoming/SIM test. Never reflash just to satisfy this charter without a separate safety/security/AVB review.

**3D — stock-flow gap accounting:** for every scenario/edge, mark PROVEN, STATIC_ONLY, CONFIG_ONLY or UNKNOWN, plus baseline/upstream origin. Only when sufficient stock behavior is established does PR347 reconciliation begin. Present selected SableOS implementation alternatives and minimal, individually reviewable patches then; PR347 source/selection cannot erase unknown stock edges.

**C2 Zygote boot-fatal triage stays an independent boot-acceptance blocker, not a source of selection bias for stock call-flow discovery.**

## Existing SableOS evidence authority

- `docs/titan2/evidence/N1I_F_STOCK_V010014_CONTROL_SANITIZED.md` (stock functional control, both physical trays; not an end-to-end call trace).
- `docs/titan2/N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE.md` (OEM IMS APK, Java/native/config closure).
- `docs/titan2/N1I_B_TREBLEDROID_MTK_IMS_CAPABILITY_ANALYSIS.md` (IMS and modem-capability architecture evidence).
- `build/titan2/capture-n1b2-cellular-runtime.sh` and `build/titan2/sanitize-n1i-stock-control.py` (reused read-only runtime and privacy tooling, only with appropriate stock state).
- Owner's accepted matched A16 Phase1 receipt `/srv/sable-build/evidence/titan2-phase1-a16-matched-20261028T152221Z`; exact DEX Phase2 receipt `/srv/sable-build/evidence/titan2-phase2-exact-abi-20261028T154126Z`; Phase2B `/srv/sable-build/evidence/titan2-phase2b-classification-20261028T155410Z`; Phase2C `/srv/sable-build/evidence/titan2-phase2c-historical-20261028T161438Z`.
- Original V5 historical crosswalk: `/srv/sable-build/evidence/titan2-exact-member-v5-20261028T125307Z`.

**Acceptance for this charter: scope/decision correction documented, not full stock call-flow reconstruction. NO PATCH / NO BUILD / NO DEVICE CONTACT / NO FLASH.**
