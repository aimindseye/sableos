# Sable R1 release validation

`SABLE_R1_R0_RELEASE_PREFLIGHT.py` is a read-only Panther release-engineering inventory/gate.

It does not build, generate keys, sign, generate OTAs, or contact a device. See `docs/SABLE_R1_R0_RELEASE_ENGINEERING_PREFLIGHT.md`.

Routine first run:

```bash
python3 tools/validation/release-r1/SABLE_R1_R0_RELEASE_PREFLIGHT.py
RC=$?
echo "R1_R0_RC=$RC"
```

Exit `3` means the audit completed and release blockers were identified; that is the expected initial R1-R0 result.
