# Titan 2 milestones — active roadmap (2026-10-12)

Milestones track completed engineering outcomes, **not script version numbers**. A milestone passes only its defined acceptance criteria; remaining unknowns stay visible.

| Milestone | Status | Acceptance / remaining work |
|---|---|---|
| **M1: known-good boot and rollback controls** | **PASS_HISTORICAL** | Stock recovery; C3A V01.00.14 boot and N1F C3A-derived five-app system_a build/flash/boot. Preserve exact hashes and restore procedures. |
| **M2: October 11 Atlas-inspired hybrid-super runtime checkpoint** | **PASS_RUNTIME / PARTIAL_PROVENANCE** | Android boots, ADB diagnostics, SIM enumeration and transient cellular registration observed. Preserve operator-reported flash and temporary ADB-triggered cellular activation followed by renewed disablement; this is a diagnostic failure, not a reliable enablement workaround. Link flash journal/artifact to runtime; do not confer R3 offline boot authority. |
| **M3: R1/R2 and cellular root-cause closure** | **IN_PROGRESS** | R1 static receiver proof and approved one-action remediation design. R2 five stock imports SHA/ELF checked; recursive closure/namespace and installed target binding pending. LTE/RIL instability independent and not causally closed. |
| **M4: controlled integrated image** | **NOT_AUTHORIZED** | Freeze actually running parent; select target partition topology and OEM IMS placement; full static safety qualification; explicit build authorization; image hashes/seal after build. |
| **M5: governed runtime qualification and release** | **NOT_AUTHORIZED** | Mode-aware, fail-closed Titan deployment; boot/IMS registration/calls/SIM/data stability and recovery regression. No flash authority from this roadmap. |

## Milestone rules

- Every engineering handoff reads [CURRENT_ENGINEERING_STATE.md](CURRENT_ENGINEERING_STATE.md) and [EVIDENCE_INDEX.md](EVIDENCE_INDEX.md) **before** proposing another script.
- Separate `OBSERVED`, `HOST_HASH_VERIFIED`, `STATIC_CANDIDATE`, `OPERATOR_REPORTED`, `UNBOUND`, `FAIL` and `NOT_AUTHORIZED`.
- A later report never retroactively changes an earlier artifact's authority file. Add a dated superseding evidence record after verifying exact provenance.
- PR #339 is the existing IMS1/CW1/AtlasOS **draft** research vehicle; do not merge it as production IMS qualification.
- Avoid new broad audits when prior evidence already answers the question. The shortest path to M4 is preserving the actual October 11 experiment, verifying its artifact/installed partition topology and resolving only remaining R1/R2 native admission blockers.
- No local dirty worktree reset, cleanup or source edits; no build, device or flash merely from documenting these milestones.
