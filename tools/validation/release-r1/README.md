# Sable R1 release validation

`SABLE_R1_R0R2_RELEASE_PREFLIGHT.py` is the current read-only Panther release-engineering inventory/gate.

Execution lineage:

```text
SABLE_R1_R0_RELEASE_PREFLIGHT.py      HISTORICAL BASE / DO NOT EXECUTE DIRECTLY
SABLE_R1_R0R1_RELEASE_PREFLIGHT.py    SUPERSEDED / KNOWN RECURSION DEFECT
SABLE_R1_R0R2_RELEASE_PREFLIGHT.py    CURRENT EXECUTION ENTRYPOINT
```

R0R2 binds the original R1-R0 script by SHA-256 and corrects three physical-host harness issues without changing the release-blocker policy:

- indented `CN=GrapheneOS` in upstream `script/generate-keys`;
- target product identity being read from generic `SYSTEM/build.prop` instead of target-files OTA/product metadata;
- R0R1 monkeypatch self-recursion caused by the replacement calling mutable `BASE.find_build_properties` after patching it.

R0R2 captures the original base function before patching, invokes it through a closure, and restores all patched base globals in `finally` after every run.

It does not build, generate keys, sign, generate OTAs, or contact a device. See:

- `docs/SABLE_R1_R0_RELEASE_ENGINEERING_PREFLIGHT.md`
- `docs/SABLE_R1_R0R1_PREFLIGHT_CORRECTION.md` for historical R0R1 context
- `docs/SABLE_R1_R0R2_PREFLIGHT_CORRECTION.md` for the current correction and validation

Use the existing sablectl virtual environment so pytest is available:

```bash
PY="$HOME/.venvs/sablectl/bin/python"

"$PY" -m pytest \
  tools/validation/release-r1/test_release_preflight.py \
  tools/validation/release-r1/test_release_preflight_r0r2.py -q

"$PY" tools/validation/release-r1/SABLE_R1_R0R2_RELEASE_PREFLIGHT.py
RC=$?
echo "R1_R0R2_RC=$RC"
```

Expected current test cardinality is 20 tests: 9 base R0 tests plus 11 R0R2 adapter/integration tests.

Exit `3` means the audit completed without parser/runtime errors and release blockers were identified; that is the expected initial R1-R0R2 result. `ERROR=0` is required before R1-R0 is considered closed as an inventory.
