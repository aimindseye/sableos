# Sable R1 release validation

`SABLE_R1_R0R1_RELEASE_PREFLIGHT.py` is the current read-only Panther release-engineering inventory/gate.

It supersedes direct execution of `SABLE_R1_R0_RELEASE_PREFLIGHT.py` for the first physical-host R1-R0 audit. The R0R1 layer binds the original R1-R0 script by SHA-256 and corrects only two parser defects found on the ThinkPad:

- indented `CN=GrapheneOS` in upstream `script/generate-keys`;
- target product identity being read from generic `SYSTEM/build.prop` instead of target-files OTA/product metadata.

It does not build, generate keys, sign, generate OTAs, or contact a device. See `docs/SABLE_R1_R0R1_PREFLIGHT_CORRECTION.md` and `docs/SABLE_R1_R0_RELEASE_ENGINEERING_PREFLIGHT.md`.

Use the existing sablectl virtual environment so pytest is available:

```bash
PY="$HOME/.venvs/sablectl/bin/python"

"$PY" -m pytest \
  tools/validation/release-r1/test_release_preflight.py \
  tools/validation/release-r1/test_release_preflight_r0r1.py -q

"$PY" tools/validation/release-r1/SABLE_R1_R0R1_RELEASE_PREFLIGHT.py
RC=$?
echo "R1_R0R1_RC=$RC"
```

Exit `3` means the audit completed without parser/runtime errors and release blockers were identified; that is the expected initial R1-R0R1 result.
