# IMS1-D9.6 correction: retained D1R2 image-specific classpath evidence already exists

Operator D9.6 output (2026-10-11): `PASS_RETAINED_D1R2_REFERENCE_CENSUS_IMAGE_AUTHORITY_UNQUALIFIED`, 141 references. This is an evidence *locator*, not proof of an image SHA-256 or runtime classpath.

**Do not create another workspace, rerun image extraction, or scan for D1R2 classpaths.** Existing image-exact evidence root:
`/srv/data/sable-build/evidence/titan2/n1i-c2r2-d1r2-image-exact-delta-v6-2/20261008T131657Z`

Exact retained paths (within root) cited by `SHA256SUMS.txt`:
- `D1R2/classpaths/bootclasspath.pb`
- `D1R2/classpaths/systemserverclasspath.pb`
- `D1R2/classpath-and-libraries.txt`
- `D1R1/classpaths/bootclasspath.pb` and `D1R1/classpaths/systemserverclasspath.pb` as comparison controls
- `b2-input-pack-v1-1-20261008T141244Z/d1r2-mtk-bootclasspath-resolved.txt`
- `b2-input-pack-v1-1-20261008T141244Z/d1r2-mtk-bootclasspath-symbolic.txt`
- `b2-input-pack-v1-1-20261008T141244Z/bootclasspath-parse-summary.env`

`D1R2/rdump.log` cites an existing extracted path under `<root>/extract/D1R2/system/etc/classpaths/bootclasspath.pb`; the log reported the absolute extraction path existed when D9.6 ran. The D9.6 `reference_absolute_exists` field was empty for *relative* references, **not** evidence of their absence. The root archive's seal SHA-256 is `01cbb96ae8564c32c18c6f5b036a31487d08a1382b829a27b8cb26bdfee5c021` for `SHA256SUMS.txt` itself; this is **not** the hash of D1R2 `system.img` or of the classpath protobuf.

Next step: verify these exact files exist and validate their individual lines in the existing SHA256SUMS, decode D1R2 protobufs using the already established `packages/modules/common/proto/classpaths.proto` from protected CW1 workspace, and compare schema-decoded stock vs D1R2 entries. Do not infer full merged runtime classpath: APEX fragments, SDK bounds, uses-library visibility and installed-image identity remain separate gates. No build, network, source mutation, device or flash; PR #339 remains draft.