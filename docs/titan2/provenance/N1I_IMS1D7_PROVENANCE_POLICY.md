# N1I IMS1-D7 frozen artifact provenance policy

Status: **29/29 identity hashes host-verified on 2026-10-11; static-only**.

## Permanent lookup
The companion JSON is the canonical versioned analytical registry. Every row binds `id`, **case-sensitive absolute path**, SHA-256, role, identity evidence, and container-lineage limitation. Future scripts consume it directly, check selected paths/hashes, and **must not** recursively rediscover artifacts or replace a hash mismatch by filename. New input or genuine change requires a new version and explicit review.

## Cohorts are not interchangeable
- **N1B2 analytical stock**: `stock-2026041315-root`, labelled 2026041315 EEA. The label is **not** a cryptographic ZIP-to-partition-to-file proof.
- **Historical N1I-A TeleService**: retained for historical comparison; do not substitute for the N1B2 baseline.
- **D1R2 SableOS APKs**: from labelled D1R2 extracted image; enclosing assembled image linkage remains a separate gate.
- **CW1 telephony-common**: compiled independently; not asserted installed in the D1R2 image.
- **2026042212 TEE stock ZIP**: a separate corpus member; not asserted to be the source of analytical APKs.

## Evidence and qualified claims
The operator's IMS1-D7 execution reported `IMS1D7_REGISTRY_SCHEMA=PASS count=29 unique=29`, 29 PASS file SHA-256 identities, `IMS1D7_FAILURE_COUNT=0`, `IMS1D7_RESULT=PASS_PINNED_ARTIFACT_IDENTITY_ONLY`. Logs and original host evidence remain on ai-g732, not in Git.

Identity does **not** establish firmware cryptographic lineage, actual boot/system-server/application classpaths, manifest correctness, Android ABI compatibility, IMS registration, incoming-call performance, or SIM switching.

## Auditing discipline
Do not rerun IMS1-D2–D6 broad scans for these 29 identities. A gate should verify only pinned consumed files; halt on missing/mismatch. To establish newly relevant image lineage, consult retained metadata first and record the original ZIP/container SHA-256, partition extraction tooling and output hashes if established. Never invent missing links.

## Safety and publication
Registry and policy are text-only. Never commit OEM APK/JAR/DEX bytes or extracted images. No source mutation, full build, network fetch on ai-g732, device contact, reboot or flash is authorized by this documentation PR.
