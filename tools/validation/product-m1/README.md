# Sable M1 validation

## M1-R0 — engineering/source contract

`SABLE_M1_ENGINEERING_PREFLIGHT.py` validates the Sable Start M1 engineering
contract. Before source exists it validates the contract itself; once
`packages/apps/SableStart` exists it performs a bounded source scan and Android
manifest security review.

## M1-R1 — static toolchain/renderer preflight

`SABLE_M1_R1_TOOLCHAIN_PREFLIGHT.py` binds the canonical Panther Android 17
workspace and inventories the local Rust, Cargo, rustfmt, Clippy, Clang, Soong,
JDK 21, Ninja and Android UI-interface substrate.

M1-R1 is deliberately read-only:

```text
BUILD_TOOL_EXECUTION=NO
BUILD_AUTHORIZED=NO
SOURCE_MUTATION_AUTHORIZED=NO
NETWORK_ACTIONS=NONE
SOURCE_IMPORT_ACTIONS=NONE
DEVICE_ACTIONS=NONE
RENDERER_SELECTED=NONE
```

It never runs build tools and never fetches renderer dependencies. Renderer
source absence is classified for later import review rather than silently
turning into a dependency choice.

Preferred invocation:

```bash
tools/validation/product-m1/run_SABLE_M1_R1_TOOLCHAIN_PREFLIGHT.sh
```

The runner binds the reviewed script and contract SHA-256 values before
execution. Evidence is written only to a newly-created root under `/tmp`.

Unit/adversarial validation:

```bash
python3 tools/validation/product-m1/test_sable_m1_engineering_preflight.py
python3 tools/validation/product-m1/test_sable_m1_r1_toolchain_preflight.py
```

See:

- `docs/SABLE_M1_START_ARCHITECTURE_AND_ENGINEERING_STANDARD.md`
- `docs/SABLE_M1_R0_ENGINEERING_GATE_20260909.md`
- `docs/SABLE_M1_R1_STATIC_PREFLIGHT.md`
