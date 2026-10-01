# Titan 2 N1D C3 product-parse qualification R1

Status: **TrebleDroid-generated control product; parse only; non-release**

Date: 2026-10-01

The retired handcrafted C3 product is no longer parsed.

The exact target is:

```text
treble_arm64_bvN-bp4a-user
```

The parse gate first verifies the pinned TrebleDroid preparation state, then
sources Android envsetup, selects the generated product, and runs
`soong_ui --dumpvars-mode`.

Required identity:

```text
TARGET_PRODUCT=treble_arm64_bvN
TARGET_BUILD_VARIANT=user
PRODUCT_DEVICE=tdgsi_arm64_ab
PRODUCT_BRAND=google
PRODUCT_MODEL=TrebleDroid vanilla
```

No target compilation, network fetch, device contact, flash, target-files, or
OTA packaging is authorized by parse.

Parse output is isolated beneath:

```text
/srv/sable-build/workspaces/titan2-n1d/out-c3-td-parse/
```

Evidence is sealed beneath:

```text
/srv/sable-build/evidence/titan2/n1d-c3-trebledroid-parse/
```

A passing parse proves the pinned generated product resolves. It does not make
the control product release-eligible.

Execution:

```bash
bash build/titan2/qualify-n1d-c3-product-parse.sh \
  --authorize-product-parse
```
