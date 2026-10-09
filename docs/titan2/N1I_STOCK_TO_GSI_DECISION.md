# Titan 2 N1I: stock-to-GSI consolidated decision

Status: **SKELETON — operator to fill in on the build host. No value below is a result until the operator records it.**

Companion: `docs/titan2/N1I_STOCK_TO_GSI_DECISION.env` (machine-readable; every marker starts `PENDING`).

```text
REVIEW_DATE=PENDING
REVIEWER=PENDING
REVIEW_HOST=PENDING
REPO_HEAD_USED=PENDING
DEVICE_CONTACT=NO
BUILD=NO
FLASH=NO
NETWORK_FETCH=NO
```

## How to fill this in

- Every claim names one exact artifact path (with SHA-256), commit or PR.
- If a sealed artifact is not accessible, write `UNKNOWN_EVIDENCE_NOT_ACCESSIBLE`. Never PASS or FAIL by inference.
- A result for one composition (stock, C3A, N1F, C1, C2, D1R1, D1R2) never transfers to another.
- Rows marked **REPO** were pre-filled from committed evidence by the drafting lane. Re-verify each against the sealed host artifact and change its status to `VERIFIED` or `CONTRADICTED`.
- Do not paste raw modem logs, subscriber identifiers or IPs. Use sanitized key lines and hashes.

## 0. Evidence pin table (G0 — fill before anything else)

If any row needed by a gate below is `UNKNOWN_EVIDENCE_NOT_ACCESSIBLE`, that gate's verdict is UNKNOWN.

| ID | Composition | Image / archive SHA-256 | Source commit | Sealed evidence directory | Evidence SHA-256 | Status |
|---|---|---|---|---|---|---|
| E-STOCK | Stock V01.00.14 system | `b2074e20…f431bd` (system), `de1fdeca…aad37` (product), `1d9d2592…d170` (system_ext), `cfeacc74…1ada` (vendor) | n/a | `/srv/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference` | PENDING | PENDING |
| E-STOCK-RT1 | Stock tray-1 runtime capture | `c3d49e62…a76cc1` (raw zip) | n/a | PENDING | PENDING | REPO: `build/titan2/n1i-f-stock-v010014-control.env` |
| E-STOCK-RT2 | Stock tray-2 runtime capture | `b77da377…dc4a89` (telephony), `3e23000d…bdda76c` (radio) | n/a | PENDING | PENDING | REPO: `docs/titan2/evidence/N1I_F_STOCK_V010014_TRAY2_KEY_LINES.txt` |
| E-C3A | C3A control | `4c292b98…c554c16` | PENDING | PENDING | PENDING | PENDING |
| E-N1F | N1F R2 | `dc1f917d…eb46299a` | PENDING | PENDING | PENDING | PENDING |
| E-N1F-RT | N1F/C3A tray-1 collapse capture | PENDING | PENDING | PENDING | PENDING | REPO: branch `n1i-e-registration-collapse-tray1-evidence-20261003`, section 9AA |
| E-N1IA | N1I-A OEM IMS closure | report `08e6dbec…6b68c`, env `a7135f58…47b4de8` | PENDING | `/srv/sable-build/evidence/titan2/n1i-a-oem-ims/20261005T002256Z` | PENDING | PENDING |
| E-C1 | N1I-C1 image | **PENDING (not pinned in any current doc)** | `a745c7da…` (image source) | PENDING | PENDING | PENDING |
| E-C2 | N1I-C2 image | **PENDING (not pinned in any current doc)** | PENDING | PENDING | PENDING | PENDING |
| E-D0 | D0 host closure run (PR #334 tooling) | n/a | `92e1e117…` (PR #334 head, draft) | **PENDING — confirm a sealed D0 run exists** | PENDING | PENDING |
| E-D1R1 | D1R1 image | PENDING | PENDING | PENDING | PENDING | PENDING |
| E-D1R2 | D1R2 image | `fb87b6a0…bab415` | `28b44ee7…` (build), `c71a8c3a…` (flash tooling) | `/srv/sable-build/evidence/titan2/n1i-d1r2-cellular-image-resume/20261008T021355Z` | PENDING | PENDING (issue #336) |
| E-APN-GSI | GSI APN database | `US.xml` blob `ef74372c…d599` | LineageOS `android_vendor_apn` `8b06f423…` (C3A manifest pin) | in-tree source | n/a | REPO-verifiable (see 3.1) |

Current device state (fact 7 of the gate brief is ambiguous; record it exactly):

```text
SYSTEM_A_IMAGE_SHA256_ON_DEVICE=PENDING
USERDATA_STATE=PENDING   # e.g. preserved since <image>, or factory-reset at <time>
LAST_CONFIRMED_ANDROID_BOOT_IMAGE=PENDING
```

## 1. Executive table

One row per fact. Keep it short; detail lives in sections 2–5.

| FACT | EVIDENCE | APPLIES_TO | CONCLUSION | OPEN_GAP | ACTION |
|---|---|---|---|---|---|
| PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |

## 2. G1 — static Java / classpath closure

Classes: `MISSING_CLASS`, `MISSING_METHOD_OR_FIELD`, `DUPLICATE_CLASS`, `BOOTCLASSPATH_ORDER_OR_PATH`, `APEX_VERSION_OR_CLASSLOADER`, `SIGNATURE_OR_SHARED_UID`, `BYTECODE_BEHAVIOR_UNKNOWN`.

| Composition | Source result (path/SHA) | Finding | Class | Status |
|---|---|---|---|---|
| C1 | PENDING | **REPO:** `TelephonyMetrics.writeRilAnswer` stock `(II)V` vs C3A/C1 `(IIII)V`; `ImsRILAdapter` calls `(II)V` (`N1I_C2_CELLULAR_INTEGRATION_CLOSURE_R1.md`) | `MISSING_METHOD_OR_FIELD` | REPO, verify |
| C1 | PENDING | PENDING | PENDING | PENDING |
| C2 | PENDING | PENDING | PENDING | PENDING |
| D1R2 | PENDING | PENDING | PENDING | PENDING |

Method/body behavior (stock AOSP-named JARs vs C3A): no existing tool compares method bodies. Choose one and record it:

```text
G1_METHOD_BODY_COMPARISON=PENDING   # NOT_PERFORMED_REMAINS_UNKNOWN | NARROW_EXCEPTION_PERFORMED:<scope,path>
```

## 3. G3 — registration-loss mechanism

### 3.1 Data-profile and attach configuration (REPO-prefilled; verify)

| Item | Stock V01.00.14 | GSI (C3A/N1F) | Source | Status |
|---|---|---|---|---|
| Default data APN in use | `fast.t-mobile.com` ("T-Mobile US"), IPv6 | `pwg` ("US Mobile", GID1 `6901`), IPv4v6, roaming IPv4 | stock env; N1B2 / 9AA evidence; `US.xml` | REPO, verify |
| Initial-attach (`ia`) APN for this SIM | `fast.t-mobile.com` entry is typed `ia`; stock modem feature `IA_MD_Preferred_APN=1` | **No `ia`-typed entry for 310240/GID 6901.** AOSP falls back `ia`→`default` (`KEY_ALLOWED_INITIAL_ATTACH_APN_TYPES_STRING_ARRAY` default `{"ia","default"}`), so `pwg` is pushed via `setInitialAttachApn` | `DataProfileManager.updateInitialAttachDataProfileAtModem`; `US.xml` | REPO source fact; runtime IA push PENDING (grep `Initial attach data profile updated as`) |
| IMS APN for this SIM | `ims` up on `ccmni2` | **No `ims`-typed entry for 310240** in the GSI database | `US.xml`; stock tray-2 key lines | REPO, verify |
| What the stock framework sent as IA APN | PENDING (stock log: `setInitialAttachApn` / MTK IA lines) | n/a | E-STOCK-RT1/RT2 raw | PENDING |

### 3.2 Ordered event sequence

Distinguish first data teardown from first WWAN registration loss. IMS is a separate axis.

| Step | Stock tray 1 | Stock tray 2 | GSI tray 1 (N1F, 9AA) | GSI tray 2 (N1B2) |
|---|---|---|---|---|
| Registration HOME | PENDING | REPO: yes | REPO: 20:37:59 | PENDING |
| Default data CONNECTED | PENDING | REPO: yes | REPO: 20:37:59 (`pwg`) | REPO: yes (`pwg`) |
| IMS PDN up | PENDING | REPO: yes (`ccmni2`) | REPO: no (no provider) | PENDING |
| `ERROR_UNSPECIFIED` teardown | REPO: count 0 | REPO: transient, recovered | REPO: 20:39:30 | REPO: yes |
| Reject causes | REPO: 11/13/15 count 0 | REPO: 27 transient | REPO: 13→15→11, EMERGENCY | PENDING |
| Recovery to HOME + data | n/a | REPO: PASS | REPO: HOME 20:39:39, collapses again 20:41:43 | PENDING |
| `SET_RADIO_CAPABILITY` / `ProxyController` | PENDING | REPO: real transaction, 2 requests | PENDING (`new request session` vs `Already in requested configuration`) | PENDING |
| simswitch / c_capability_slot | REPO: 1/1 | REPO: 1/1 | REPO: 1/1 | REPO: 1/1 |

```text
G3_FIRST_DIVERGENCE_STEP=PENDING
G3_FIRST_DIVERGENCE_EVIDENCE=PENDING
GSI_REGISTRATION_LOSS_CAUSE=PENDING   # keep UNKNOWN unless a step is proven
```

## 4. G2 — native / service / policy and boot-fatal closure

Only boot-fatal findings that the N1F control passes on the same gate count. SELinux, VINTF and policy warnings are not BOOT_FATAL unless init semantics prove it. Do not reopen the ICU/APEX false positive.

| Gate (D0) | C1 | C2 | D1R2 | N1F control | Evidence |
|---|---|---|---|---|---|
| A SELinux (init-equivalent) | PENDING | PENDING | PENDING | PENDING | PENDING |
| B property contexts | PENDING | PENDING | PENDING | PENDING | PENDING |
| C service contexts / VINTF | PENDING | PENDING | PENDING | PENDING | PENDING |
| D privapp / shared UID / seapp | PENDING | PENDING | PENDING | PENDING | PENDING |
| E bootclasspath / APEX / classloader | PENDING | PENDING | PENDING | PENDING | PENDING |

```text
D0_SEALED_RUN_EXISTS=PENDING
D0_COVERS_D1R2=PENDING          # D0 as built compares N1F vs C1/C2 only
C1_C2_D1R2_BOOT_FATAL_DIFFERENCE=PENDING
```

## 5. G4 — decision

Pick exactly one. Fill in what each option means before choosing.

| Option | Meaning (operator defines) | Exit criteria |
|---|---|---|
| `GO_HOST_ONLY_MINIMAL_COMPAT_DELTA` | PENDING | PENDING |
| `GO_LINEAGE_TITAN_OFFLINE_REFERENCE` | PENDING | PENDING |
| `HOLD_EXACT_MISSING_EVIDENCE` | PENDING | PENDING |
| `HOLD_BOOT_ROOT_CAUSE_UNRESOLVED` | PENDING | PENDING |

```text
NEXT_ARCHITECTURE_DECISION=PENDING
DECISION_RATIONALE=PENDING
```

For every proposed source delta:

| Delta | Owner (file/project) | Smallest implementation | Prior negative checks | Boot-regression scope | Radio acceptance test |
|---|---|---|---|---|---|
| PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |

## 6. True gaps (at most five)

Each gap names exactly one existing evidence file to examine next, or says why a new capture is indispensable.

| # | Gap | Next evidence file | New capture indispensable? |
|---|---|---|---|
| 1 | PENDING | PENDING | PENDING |

## 7. Evidence ledger

All prior PASS / FAIL / UNKNOWN markers, one row each, unchanged.

| Marker | Value | Source | Composition |
|---|---|---|---|
| PENDING | PENDING | PENDING | PENDING |

## 8. Final markers

Copied from the `.env` after review. Do not edit here directly.

```text
STOCK_ARTIFACT_INVENTORY=PENDING
STOCK_OEM_IMS_STATIC_CLOSURE=PENDING
STOCK_VS_C3A_METHOD_BEHAVIOR=PENDING
C1_C2_D1R2_BOOT_FATAL_DIFFERENCE=PENDING
GSI_REGISTRATION_LOSS_CAUSE=PENDING
STOCK_RERESTORE_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
NEXT_ARCHITECTURE_DECISION=PENDING
```
