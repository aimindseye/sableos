# Titan 2 / Titan 2 Elite Sable image composition (retired record)

> **Retired in C3B D1b. Not operational.** Nothing in this document is a build, staging or integration procedure.

Earlier lab revisions of this repository described a parallel image composition: handcrafted product makefiles under a
`product/` tree, copied into a separate vendor path, importing presigned prebuilt APKs and assigning their own `ro.sable.*`
properties, with a standalone HOME application. That model was rejected by the canonical architecture and its files were
removed in D1b.

What replaced it:

- Product composition, signing, partitions, properties and the final image are owned by the canonical C3B engineering lane
  (release track N1D, baseline phase C3B, `aimindseye/sableos`). This repository supplies source modules, tests,
  interface requests and provenance only.
- HOME is Launcher3/Launcher3QuickStep hosting Sable Start (IR-002). There is no standalone HOME package here.
- No presigned or prebuilt APKs and no signing material are accepted. Unsigned release builds are source qualification only.
- Needed facts from the removed files (default IME, key policy, permissions, Mini Mode evidence) are kept as requirements in
  `docs/C3B_PRODUCT_INTERFACE_EVIDENCE.md` and `docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv` (IR-004, IR-005, IR-006).
- Candidate modules are listed in `docs/C3B_PRODUCT_SOURCE_MODULES.tsv`; all are NOT_ADMITTED until the canonical lane
  admits them (IR-011).
- Retired paths are listed in `docs/C3B_PRODUCT_RETIRED_PATHS.tsv`; `build/titan2/qualify-c3b-product-source.sh` fails if any
  reappear.
