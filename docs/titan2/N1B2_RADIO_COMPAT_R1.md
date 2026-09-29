# N1B2 Radio Compatibility R1

## Decision

`N1B2_RADIO_COMPAT_R1_SUPERSEDES_PR208=YES`

This branch supersedes PR208 as the active Titan 2 cellular restoration path. PR208 proved useful for stock payload auditing, but it is no longer the right implementation vehicle because runtime evidence shows that N1B1 can already reach LTE service, create a WWAN data call, and then lose that data call later. The next work should therefore target radio compatibility, MTK indication handling, IMS binding, and QNS/IMS interaction rather than importing stock telephony APKs.

## Safety boundary

```text
N1B2_RADIO_COMPAT_R1_NO_STOCK_APK_IMPORT=YES
N1B2_RADIO_COMPAT_R1_NO_FLASH=YES
N1B2_RADIO_COMPAT_R1_NO_VENDOR_COPY=YES
N1B2_RADIO_COMPAT_R1_RUNTIME_CAPTURE_ONLY=YES
```

This branch intentionally does not add stock telephony APKs, MTK framework JARs, native IMS libraries, flash scripts, fastboot commands, userdata wipes, vendor partition copies, or full vendor payload copies.

## Evidence basis

Validation root:

```text
/srv/data/sable-build/evidence/titan2/n1b2-mtk-telephony-physical/20260929T205519Z
```

Key summary input:

```text
15-radio-compat-evidence-summary.txt
```

The current source of truth is the saved evidence summary, not terminal scrollback. The summary was created specifically to avoid losing important data to clipped terminal output.

## Proven good window

`N1B2_RADIO_COMPAT_R1_GOOD_WINDOW_PROVEN=YES`

The evidence shows a real LTE / WWAN good window on phone 1 / subId 1:

- voice registration and data registration reach `IN_SERVICE` / `HOME`
- radio technology is LTE
- registered PLMN is `310260`
- LTE band 66 is reported
- data profile is selected for `US Mobile` / `310240` / `pwg`
- `SETUP_DATA_CALL` succeeds with `cause=NONE`
- interface `ccmni1` is created
- WWAN data reaches `CONNECTED`
- IP, DNS, MTU, and default route are present

This means the immediate issue is not simply missing APN data, missing basic carrier config, or a completely absent AOSP phone stack.

## Proven drop window

`N1B2_RADIO_COMPAT_R1_DROP_WINDOW_PROVEN=YES`

The evidence also shows the failure window:

- `UNSOL_DATA_CALL_LIST_CHANGED` reports `ERROR_UNSPECIFIED`
- the same `ccmni1` WWAN data call transitions to `DISCONNECTED`
- netd removes interface wakeup/idletimer/quota state
- telephony display falls from LTE / NR_NSA to unknown after the drop

The next fix should preserve the good LTE attach and data setup path while preventing or explaining this later teardown.

## High-signal suspects

`N1B2_RADIO_COMPAT_R1_MTK_INDICATION_SUSPECT=YES`

During the LTE registration window, RILC reports MTK extension callbacks with a null indication consumer:

```text
smartRatSwitchInd: radioNetworkServiceImpl[1]->mtkNetworkIndication == NULL
responseCsNetworkStateChangeInd: radioNetworkServiceImpl[1]->mtkNetworkIndication == NULL
```

AOSP registration responses still complete successfully, so this is not proof by itself, but it is a high-signal compatibility gap to investigate.

`N1B2_RADIO_COMPAT_R1_IMS_BINDING_SUSPECT=YES`

IMS remains unbound or unusable:

- MMTEL and emergency MMTEL resolve to `com.mediatek.ims`
- callbacks show `IMS_SERVICE_DISCONNECTED`
- RCS shows `NO_IMS_SERVICE_CONFIGURED` / `IMS_UNSUPPORTED`
- telephony repeatedly reports no usable IMS service when registering callbacks

The next implementation should treat IMS/QNS as a runtime compatibility problem, not as permission to import signature-incompatible stock telephony APKs.

## Branch contents

This R1 branch carries only documentation and bounded capture/gating utilities:

```text
docs/titan2/N1B2_RADIO_COMPAT_R1.md
build/titan2/capture-n1b2-radio-compat-runtime.sh
build/gates/n1b2-radio-compat-contract.sh
```

## Runtime capture command

The capture script is device-contacting but non-mutating. It uses per-command timeouts so it should not hang indefinitely, and its summary grep is bounded to explicit files inside the evidence directory.

```bash
cd /srv/data/sable-build/sableos/repo

bash build/titan2/capture-n1b2-radio-compat-runtime.sh \
  --evidence-dir /srv/data/sable-build/evidence/titan2/n1b2-radio-compat-r1/$(date -u +%Y%m%dT%H%M%SZ)
```

Expected markers:

```text
N1B2_RADIO_COMPAT_ADB_WAIT=PASS
N1B2_RADIO_COMPAT_CAPTURE_GREP_SCOPE=EXPLICIT_CAPTURE_FILES_ONLY
N1B2_RADIO_COMPAT_CAPTURE=PASS
```

## Static contract

```bash
cd /srv/data/sable-build/sableos/repo
bash -n build/titan2/capture-n1b2-radio-compat-runtime.sh
bash -n build/gates/n1b2-radio-compat-contract.sh
bash build/gates/n1b2-radio-compat-contract.sh
```

Expected marker:

```text
N1B2_RADIO_COMPAT_R1_CONTRACT=PASS
```

## Next implementation direction

1. Keep AOSP phone stack active and source-built.
2. Do not import stock telephony APKs that collide with platform shared UIDs.
3. Investigate why MTK network indication callbacks have no consumer.
4. Investigate whether `com.mediatek.ims` can be made available through a source-compatible shim, overlay, or framework configuration change without importing signature-incompatible APKs.
5. Investigate whether QNS / IWLAN / IMS state contributes to the post-attach `ERROR_UNSPECIFIED` data teardown.
6. Preserve the good LTE attach window as a regression gate before changing radio compatibility code.

## PR208 disposition

PR208 should be closed as superseded by this branch after the clean PR is opened. Its useful contribution is the stock payload risk evidence and the decision to avoid stock APK import. Its build-payload direction is no longer the active cellular restoration path.
