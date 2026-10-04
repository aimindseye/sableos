# Panther D4 B2 validation script archive

This directory keeps the final/relevant 2026-09-08 Panther D4 B2 validation tooling. It is **not** the ongoing validation API; new post-boot work belongs in `tools/sablectl/`.

## Checked-in executable scripts

```text
R9
  PANTHER_P1B_D4_B2B2R9_preserved_data_flash_preflight.sh
  preserved-data/device readiness preflight
  RESULT=PASS

R10R3
  PANTHER_P1B_D4_B2B2R10R3_preserved_data_flash_execution.sh
  fail-closed historical stub; it performs no device or flash operation
  the originally checked-in R10R3 blob is corrupted and is preserved byte-for-byte at:
    archive/PANTHER_P1B_D4_B2B2R10R3_preserved_data_flash_execution.corrupt
  preserved corrupt Git blob:
    c1e600a98b3dc285a585d8098d426f8a236a27d8
  historical validation records still document the successful B2 deployment and later bounded
  post-boot failure, but the damaged executable archive is not trusted as reusable deployment code

run_sablectl_b2_smoke.sh
  convenience wrapper for the canonical B2 target-files + sablectl smoke suite
  read-only post-boot validation

test_panther_d4_validation_static.sh
  regression guard for the canonical `panther-target_files.zip` filename
```

`SHA256SUMS` binds the checked-in executable scripts/stubs. The corrupted R10R3 historical blob is bound by its preserved Git blob id above rather than reconstructed or executed.

## Historical milestone scripts identified by validation records

```text
R7R7 fs-verity named-input fidelity
f131a03908608e91996d0d3af64ab1e8f08fd789655949a254be96070aae31c8
PASS / boundary closed

R8R4 ART producer-causality investigation
79661c608b0aadd4c91486ca660ef904152d7a4bb53530c7bc700e1485062e39
BOUNDED_FAIL at missing C2 Ninja producer evidence
substantive finding: all five residuals ART_ONLY
```

The intermediate R10/R10R1/R10R2 harnesses are intentionally not promoted as reusable tools. Their bounded failures and lessons are captured in `docs/PANTHER_D4_B2_PHYSICAL_VALIDATION.md` and `docs/PANTHER_D4_ROADMAP.md`.

Future physical validation should prefer `sablectl` suites plus explicit, separately reviewed deployment tooling rather than extending these historical shell harnesses.
