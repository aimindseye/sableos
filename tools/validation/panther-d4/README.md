# Panther D4 B2 validation script archive

These scripts are retained as historical engineering/evidence tools for the 2026-09-08 Panther D4 B2 closure sequence.

They are **not** a generic release API. Later development should prefer `tools/sablectl/` for repeatable post-boot validation.

## Retained milestone scripts

```text
R7R7  fs-verity BuildManifest named-input fidelity
       PASS / boundary closed

R8R4  ART producer-causality investigation
       BOUNDED_FAIL at missing C2 Ninja producer evidence
       substantive finding: all five residuals ART_ONLY

R9    preserved-data flash preflight
       PASS

R10R3 target-files-only staged exact flash
       flash PASS
       Android boot PASS
       exact BuildManifest PASS
       historical script final BOUNDED_FAIL due post-boot adb/stdin loop bug
```

The intermediate R10/R10R1/R10R2 scripts are intentionally not promoted as reusable tools; their bounded failures and lessons are documented in `docs/PANTHER_D4_B2_PHYSICAL_VALIDATION.md` and the D4 roadmap.

See `docs/PANTHER_D4_B2_PHYSICAL_VALIDATION.md` for the physical outcome and the distinction between successful device deployment and the final host-harness defect.

`SHA256SUMS` binds the exact archived script bytes.
