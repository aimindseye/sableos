# SableOS Core Product Integration Track

Status: **planning companion to `ROADMAP.md`**.

This track turns the normative product model in `CORE_PRODUCT_MODEL.md` into staged implementation gates without disrupting the current Panther substrate bring-up.

The product principle is:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

## Dependency rule

The product track does not bypass platform bring-up.

```text
Panther substrate / V0 capability proof
        -> S1.7 semantic-service port
        -> modern Sable UI qualification
        -> core product integration
```

Individual product prototypes may be developed against mocks earlier, but they do not replace AOSP defaults until their Android/platform integration and physical-device gates pass.

## CP0 — Core product baseline

Status: **POLICY COMPLETE / IMPLEMENTATION NOT STARTED**.

Established by:

- `CORE_PRODUCT_MODEL.md`;
- ADR-0007;
- `AOSP_CAPABILITY_POLICY.md`;
- `RELEASE_VALIDATION.md`.

Outputs:

- strategic Sable-owned surface list;
- AOSP/default-app retain/replace matrix;
- product-stage build markers;
- Hub/AOD/Agent trust boundaries;
- multilingual/local-first voice dependency.

## CP1 — Shared semantic shell primitives

Prerequisite: modern renderer/framework qualification and stable Android lifecycle integration.

Build common semantics for:

- person;
- conversation;
- notification/attention item;
- action;
- search result;
- setting/capability;
- command;
- focus/navigation;
- voice/agent request.

Touch-first and keyboard-first presentation consume the same semantic model.

## CP2 — Sable Home + Hub foundation

Home:

- application/task launch;
- touch/keyboard navigation;
- explicit links to Hub/Search/Security/Agent;
- launcher replacement tested with rollback to reference Launcher3 during development.

Hub:

- Android notification/conversation ingestion;
- NOW / PEOPLE / APPS / LATER semantic views;
- application-authorized reply/actions;
- local evidence-based person linking;
- bounded local history;
- lock-screen/privacy redaction.

No private messaging-app database scraping.

## CP3 — Search + Security/Privacy integration

Search:

- Unicode/multilingual local search;
- apps, people, conversations, settings and authorized local content;
- typed command dispatch.

Security/Privacy:

- Secure Package Intelligence;
- application transparency;
- effective Permission/AppOps state;
- package/signing/component/privacy history.

## CP4 — Sable AOD / Glance

Prerequisite: physical display/doze/power baseline on target device.

Validate:

- time/date/battery;
- priority Hub indicators;
- privacy redaction;
- burn-in mitigation;
- display refresh/doze residency;
- battery impact;
- disable/failure behavior;
- touch/keyboard/device-specific wake integration where applicable.

AOD is presentation over the supported Android/vendor display/power stack.

## CP5 — Local-first Voice + Agent

Voice prerequisites are defined by `LANGUAGE_AND_VOICE_POLICY.md`.

Initial production voice requirement:

```text
English local STT/TTS = required
Hindi local STT/TTS   = required
```

Agent requirements:

- local-first/default model path where practical;
- explicit optional remote-provider policy;
- local user-controlled memory;
- typed capability allowlist;
- no generic root shell;
- no unrestricted other-app/private-files access;
- Hub/Search/Home integration through semantic actions;
- voice input/output through the shared Sable voice interface.

## CP6 — Product composition closure

Before release-candidate classification:

- intended default-app matrix is explicit;
- strategic Sable surfaces intended for the release are installed and validated;
- retained AOSP surfaces are intentionally retained;
- removed/replaced AOSP surfaces have capability-parity evidence;
- privacy/data-flow records are complete;
- multilingual/UI/Indic gates pass;
- Agent/Voice model/dependency provenance is sealed;
- AOD physical power/privacy gates pass where the device supports the feature;
- touch and keyboard interaction profiles consume common semantics;
- product image contains no accidental duplicate privileged implementation.

Typical closure markers:

```text
SABLEOS_CORE_PRODUCT_STAGE=RELEASE_CANDIDATE
SABLEOS_CORE_PRODUCT_MODEL=PASS
SABLEOS_DEFAULT_APP_MATRIX=PASS
SABLEOS_AOSP_FOUNDATION_PRESERVED=PASS
SABLEOS_LANGUAGE_BASELINE=PASS
```

Production adds the signing/security/privacy/update gates in `RELEASE_VALIDATION.md`.

## Current Panther status

Current Panther P1B work remains:

```text
SABLEOS_CORE_PRODUCT_STAGE=SUBSTRATE
```

CP0 policy exists now, but CP1+ does not become a blocker until the Panther V0/service/UI prerequisites are closed and Sable-owned user-facing components begin entering the product image.
