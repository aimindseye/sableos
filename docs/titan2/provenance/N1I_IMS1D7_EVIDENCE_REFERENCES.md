# IMS1-D7 evidence references and qualification boundaries

| Evidence | Retained location/reference | Meaning |
|---|---|---|
| IMS1-D7 operator execution | User-provided 2026-10-11 console transcript, 29 PASS records | Identity validation; no classpath or ABI claim |
| IMS1-D6 host result | `/srv/data/sable-build/evidence/titan2/n1i-ims1d6-canonical-registry-v1/20261011T140000Z-2513906` | First 7 pins and 22 observed stock JAR hashes |
| IMS1-D4 candidate binding | `/srv/data/sable-build/evidence/titan2/n1i-ims1d4-targeted-binding-v1/20261011T134456Z-2513746` | Known APK candidate hashes and path evidence |
| N1B2 stock extraction | `/srv/data/sable-build/evidence/titan2/n1b2-cellular-static/20260929T131259Z/stock-2026041315-root` | Analytical files, not proven container linkage |
| D1R2 extracted comparison | `/srv/data/sable-build/evidence/titan2/n1i-c2r2-d1r2-image-exact-delta-v6-1/20261008T130601Z/extract/D1R2` | Candidate SableOS APKs |
| Stock corpus | [stock corpus seal](../../TITAN2_STOCK_FIRMWARE_CORPUS.md) | 2026041315 EEA and 2026042212 TEE are different stock ZIPs |
| Project path registry | [N1I path registry](../N1I_CELLULAR_EVIDENCE_PATH_REGISTRY_20261011.md) (currently PR #339 branch) | Retained stock framework paths and CW1 context |
| IMS1-A/B/C review | [PR #339](https://github.com/aimindseye/sableos/pull/339) | IMS1-B 7,078 callsites; IMS1-C partial classpath; not ABI clearance |
| IMS1-C current local evidence | `/srv/data/sable-build/evidence/titan2/n1i-ims1c-consolidated-v1` | Consume pinned summary and callsite files; do not interpret zero rows as success |

**No raw proprietary binaries are included in this PR.** Full local evidence should be preserved on ai-g732. References here are traceability pointers, not claims that the complete original evidence was independently fetched by GitHub.
