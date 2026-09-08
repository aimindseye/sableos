# Panther D4 B2 validation script archive

This directory keeps a small, reviewable subset of the 2026-09-08 Panther D4 B2 validation tooling. It is **not** the ongoing validation API; new post-boot work belongs in `tools/sablectl/`.

## Checked-in executable scripts

```text
R9
  PANTHER_P1B_D4_B2B2R9_preserved_data_flash_preflight.sh
  preserved-data/device readiness preflight
  RESULT=PASS

run_sablectl_b2_smoke.sh
  convenience wrapper for the canonical B2 target-files + sablectl smoke suite
  read-only device validation
```

`SHA256SUMS` binds those checked-in executable bytes.

## Historical milestone scripts retained outside this reusable subset

The exact historical bytes remain identified by their original SHA-256 values and validation records:

```text
R7R7 fs-verity named-input fidelity
f131a03908608e91996d0d3af64ab1e8f08fd789655949a254be96070aae31c8
PASS / boundary closed

R8R4 ART producer-causality investigation
79661c608b0aadd4c91486ca660ef904152d7a4bb53530c7bc700e1485062e39
BOUNDED_FAIL at missing C2 Ninja producer evidence
substantive finding: all five residuals ART_ONLY

R10R3 target-files-only staged exact flash
11224ddb1dc712014480ea7fc0626a8d658264f0d6eec067866ba4a8260bbf63
flash PASS; Android boot PASS; exact BuildManifest PASS
historical script final BOUNDED_FAIL due post-boot adb/stdin loop bug
```

The intermediate R10/R10R1/R10R2 harnesses are not promoted as reusable tools. Their bounded failures and lessons are captured in `docs/PANTHER_D4_B2_PHYSICAL_VALIDATION.md` and `docs/PANTHER_D4_ROADMAP.md`.

Future physical validation should prefer `sablectl` suites plus explicit, separately reviewed deployment tooling rather than extending these historical shell harnesses.
