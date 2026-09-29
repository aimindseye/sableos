# Titan 2 N1B2 cellular root-cause report

Status: PR 207 evidence report template
Date: 2026-09-29

PR 207 is read-only evidence collection. It does not fix cellular and does not
authorize module, overlay, sepolicy, permission, product package, image, or
flash changes.

## Current state

```text
ROOT_CAUSE_STATUS=EVIDENCE_REQUIRED
N1B1_STATUS=FAILING_SAMPLE
N1B2_STATUS=FAILING_SAMPLE
STOCK_STATUS=KNOWN_GOOD_REFERENCE
PR207_FIXES_CELLULAR=NO
PR208_REQUIRED_FOR_FIX=YES
```

Known symptom from the approved N1B2 plan:

```text
N1B1 connects initially and then disconnects.
N1B2 candidate connects initially and then disconnects.
Stock firmware is the only known-good reference.
```

## Evidence inventory

Fill after running PR 207 scripts.

| Evidence set | Required | Path | Status | Notes |
|---|---:|---|---|---|
| Static stock firmware tree | Yes, if extracted stock firmware is available | TBD | NOT_CAPTURED | Known-good static reference. |
| Static N1B1 tree | Yes | TBD | NOT_CAPTURED | Failing sample 1. |
| Static N1B2 candidate tree | Yes | TBD | NOT_CAPTURED | Failing sample 2. |
| Static RestlessOS tree | Yes, if available | TBD | NOT_CAPTURED | Candidate source. |
| Static AOSP/Treble tree | Yes, if available | TBD | NOT_CAPTURED | Candidate source. |
| Runtime N1B1 capture | Yes | TBD | NOT_CAPTURED | Android mode adb only. |
| Runtime N1B2 capture | Yes | TBD | NOT_CAPTURED | Android mode adb only. |
| Runtime stock capture | Optional | TBD | NOT_CAPTURED | Only if a stock-running Titan 2 is available without reflashing. |

## Disconnect timeline

The final report must include the disconnect timeline for each failing sample:

| Sample | Last good ServiceState/DataConnectionState | First bad state | Evidence file | Notes |
|---|---|---|---|---|
| N1B1 | TBD | TBD | TBD | TBD |
| N1B2 | TBD | TBD | TBD | TBD |
| Stock | TBD | TBD | TBD | Optional comparable window if available. |

## Static candidate differences

| Candidate | Category | Present in stock | Present in N1B1 | Present in N1B2 | Priority | Notes |
|---|---|---:|---:|---:|---|---|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD |

## Root-cause classification

Mark every applicable class with evidence. Leave non-applicable classes as
`NO_EVIDENCE_YET`, not `NO`, until the evidence supports that conclusion.

| Class | Status | Evidence | Candidate source for fix |
|---|---|---|---|
| product package selection | NO_EVIDENCE_YET | TBD | TBD |
| privileged permission missing | NO_EVIDENCE_YET | TBD | TBD |
| framework overlay/config | NO_EVIDENCE_YET | TBD | TBD |
| CarrierConfig/APN | NO_EVIDENCE_YET | TBD | TBD |
| IMS/radio/vendor service | NO_EVIDENCE_YET | TBD | TBD |
| radio HAL / VINTF mismatch | NO_EVIDENCE_YET | TBD | TBD |
| SELinux denial | NO_EVIDENCE_YET | TBD | TBD |
| SIM state / carrier provisioning | NO_EVIDENCE_YET | TBD | TBD |
| Settings or Network Manager policy | NO_EVIDENCE_YET | TBD | TBD |
| Treble/AOSP composition gap | NO_EVIDENCE_YET | TBD | TBD |
| stock vendor dependency gap | NO_EVIDENCE_YET | TBD | TBD |

## PR 208 handoff checklist

Before PR 208 changes anything, this report must name:

```text
ROOT_CAUSE_CLASSIFICATION_COMPLETE=YES
CANDIDATE_SOURCE_SELECTED=YES
AOSP_SOURCE_NEEDED=YES_OR_NO
RESTLESSOS_SOURCE_NEEDED=YES_OR_NO
STOCK_SOURCE_NEEDED=YES_OR_NO
NO_SPECULATIVE_MODULES=YES
NETWORK_MANAGER_DUPLICATION_BLOCKED=YES
```

Every PR 208 module, overlay, permission, sepolicy, or vendor binding must cite a
row from this report.
