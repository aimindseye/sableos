# Titan 2 / Titan 2 Elite SableScreens (retired integration record)

> **Retired in C3B D1b. Not operational.** This document no longer contains any staging, composition or build procedure.

SableScreens (`apps/titan2/screens`) is a **prototype-only** 23-screen design catalog:

```text
PRODUCT_STATUS=PROTOTYPE_ONLY
RUNTIME_PRODUCT_REQUIREMENT=NO
QUALITY_EXEMPTION=NO
CANONICAL_INTEGRATION_STATUS=NOT_ADMITTED
```

It is not required in a product image and is not a HOME application. Earlier revisions of this lab staged presigned APKs
into a separate product tree through helper scripts and product makefiles; that integration model, the scripts and the
product tree were removed in D1b.

Current rules:

- Product composition belongs to the canonical C3B lane. This repository provides source only, never prebuilt or presigned APKs.
- The screens manifest must declare no permissions, no HOME intent filter and `allowBackup="false"`; the qualification gate
  (`build/titan2/qualify-c3b-product-source.sh`) enforces this together with the platform-module audits.
- Surface ownership and status are in `docs/C3B_PRODUCT_SURFACE_MATRIX.tsv`; ownership of every path is in
  `docs/C3B_PRODUCT_PATH_OWNERSHIP.tsv`; retired paths are in `docs/C3B_PRODUCT_RETIRED_PATHS.tsv`.
- Screen design documentation stays under `apps/titan2/screens/docs`.
