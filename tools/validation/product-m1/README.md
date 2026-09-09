# Sable M1 validation

`SABLE_M1_ENGINEERING_PREFLIGHT.py` is the read-only gate for the Sable Start M1 engineering contract.

It validates the contract even before source exists. Once `packages/apps/SableStart` exists, it additionally performs a bounded source scan and Android manifest security review.

The validator intentionally uses only the Python standard library and performs no build, source mutation, device contact or network access.

Typical invocation from the repository root:

```bash
python3 tools/validation/product-m1/SABLE_M1_ENGINEERING_PREFLIGHT.py \
  --repo-root . \
  --contract product/m1/sable-start-engineering-contract-v1.json
```

Optional evidence JSON must name a new absolute path under `/tmp`; existing destinations and non-`/tmp` paths are refused.
