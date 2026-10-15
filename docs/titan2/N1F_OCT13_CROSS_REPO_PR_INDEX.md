# Titan 2 — October 13 multi-repository documentation coordination

**Status:** October 13 coordination update. All 12 requested documentation-only companion PRs were explicitly authorized by the operator and subsequently merged using exact-head guards. This index does not authorize any image/source/device action. The private [hybrid-derived engineering contract](N1F_OCT11_HYBRID_DERIVED_RECONCILIATION_20261013.md) is sole governing technical plan.

## Retired authority

- [aimindseye/sableos PR #339](https://github.com/aimindseye/sableos/pull/339) — CLOSED without merge; historical Oct11/CW1/IMS/D1R2 research and Oct13 physical findings retained on branch.
- [aimindseye/sableos PR #340](https://github.com/aimindseye/sableos/pull/340) — independent D7 provenance PR; does not grant source/build/runtime/flash authority.

## Merged status/handoff PRs

| Repository | PR | State |
|---|---|---|
| `aimindseye/sableos` | [#342](https://github.com/aimindseye/sableos/pull/342) | PRIVATE_ACTIVE |
| `sableos-project/platform_manifest` | [#14](https://github.com/sableos-project/platform_manifest/pull/14) | MERGED_DOCS_ONLY |
| `sableos-project/packages_apps_SableStart` | [#26](https://github.com/sableos-project/packages_apps_SableStart/pull/26) | MERGED_DOCS_ONLY |
| `sableos-project/platform_sable` | [#53](https://github.com/sableos-project/platform_sable/pull/53) | MERGED_DOCS_ONLY |
| `sableos-project/vendor_sable` | [#14](https://github.com/sableos-project/vendor_sable/pull/14) | MERGED_DOCS_ONLY |
| `sableos-project/device_sable_panther` | [#12](https://github.com/sableos-project/device_sable_panther/pull/12) | MERGED_DOCS_ONLY |
| `sableos-project/build` | [#18](https://github.com/sableos-project/build/pull/18) | MERGED_DOCS_ONLY |
| `sableos-project/.github` | [#41](https://github.com/sableos-project/.github/pull/41) | MERGED_DOCS_ONLY |
| `sableos-project/device_sable_titan2` | [#27](https://github.com/sableos-project/device_sable_titan2/pull/27) | MERGED_DOCS_ONLY |
| `sableos-project/treble_restlessos` | [#5](https://github.com/sableos-project/treble_restlessos/pull/5) | MERGED_DOCS_ONLY |
| `aimindseye/titan2-temp` | [#36](https://github.com/aimindseye/titan2-temp/pull/36) | MERGED_DOCS_ONLY |
| `aimindseye/unihertz-titan2` | [#23](https://github.com/aimindseye/unihertz-titan2/pull/23) | MERGED_DOCS_ONLY |
| `aimindseye/unihertz-titan2-elite` | [#4](https://github.com/aimindseye/unihertz-titan2-elite/pull/4) | MERGED_DOCS_ONLY |

## Boundaries

- Each merged cross-repo PR changes **only README/profile entrypoint and a dated docs/ENGINEERING_STATUS_2026-10-13.md**, not executable source, build/deployment policy code or firmware.
- Public notices contain only high-level Titan 2 status, not private logs, device identifiers, proprietary artifacts, private source paths or signing details.
- Panther and Titan 2 Elite inherit NO Titan 2 qualification; Q25 and unrelated individual/device projects are deliberately untouched as out of scope.
- Operator explicitly authorized merge of all listed companion PRs except private #342; each companion PR passed the exact two-path diff allowlist and was merged via GitHub with an expected head SHA. #342 remains OPEN/DRAFT/UNMERGED.
- Closing #339 does not erase its Git history or promote its 39 research files; the new draft derives authority from re-reviewed evidence, not automatic cherry-pick.
