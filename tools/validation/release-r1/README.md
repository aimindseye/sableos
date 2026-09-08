# Sable R1 release validation

`SABLE_R1_R0R3_RELEASE_PREFLIGHT.py` is the current read-only Panther release-engineering inventory/gate.

Execution lineage:

```text
SABLE_R1_R0_RELEASE_PREFLIGHT.py      HISTORICAL BASE / DO NOT EXECUTE DIRECTLY
SABLE_R1_R0R1_RELEASE_PREFLIGHT.py    SUPERSEDED / KNOWN RECURSION DEFECT
SABLE_R1_R0R2_RELEASE_PREFLIGHT.py    SUPERSEDED / LIVE TARGET-IDENTITY DEFECT
SABLE_R1_R0R3_RELEASE_PREFLIGHT.py    CURRENT EXECUTION ENTRYPOINT
```

R0R3 binds the historical R1-R0 base by exact SHA-256 and keeps the non-recursive closure/`finally` lifecycle introduced in R0R2. It fixes target-files device identity using the exact partition-scoped property contract from the pinned GrapheneOS 2026081300 `platform_build` source:

```text
SYSTEM/build.prop          ro.product.system.device
VENDOR/build.prop          ro.product.vendor.device
PRODUCT/etc/build.prop     ro.product.product.device
ODM/etc/build.prop         ro.product.odm.device
SYSTEM_EXT/etc/build.prop  ro.product.system_ext.device
```

It also retains the indented `CN=GrapheneOS` parser correction. Conflicting non-generic partition identities or OTA-vs-partition conflicts fail closed rather than being coerced to Panther.

R0R3 does not build, generate keys, sign, generate OTAs, or contact a device. See:

- `docs/SABLE_R1_R0_RELEASE_ENGINEERING_PREFLIGHT.md`
- `docs/SABLE_R1_R0R1_PREFLIGHT_CORRECTION.md` — historical R0R1
- `docs/SABLE_R1_R0R2_PREFLIGHT_CORRECTION.md` — historical R0R2
- `docs/SABLE_R1_R0R3_PREFLIGHT_CORRECTION.md` — current correction

Use the existing sablectl virtual environment:

```bash
PY="$HOME/.venvs/sablectl/bin/python"

PYTHONDONTWRITEBYTECODE=1 "$PY" -m pytest \
  tools/validation/release-r1/test_release_preflight.py \
  tools/validation/release-r1/test_release_preflight_r0r2.py \
  tools/validation/release-r1/test_release_preflight_r0r3.py -q

PYTHONDONTWRITEBYTECODE=1 "$PY" \
  tools/validation/release-r1/SABLE_R1_R0R3_RELEASE_PREFLIGHT.py
RC=$?
echo "R1_R0R3_RC=$RC"
```

Current full validation cardinality is 38 tests:

```text
test_release_preflight.py        9
test_release_preflight_r0r2.py  11
test_release_preflight_r0r3.py  18
TOTAL                            38
```

R0R1 tests are retained only as historical evidence because that suite passed while its executable still recursed at runtime; they are not part of the current gate.

Exit `3` means the audit completed without parser/runtime errors and genuine release blockers remain. `ERROR=0` is required before R1-R0 is closed as an inventory.
