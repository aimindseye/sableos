# IMS1-C static triage checkpoint — 2026-10-11

Qualification: `PASS_BOUNDED_STATIC_TRIAGE_RUNTIME_AND_ART_LINKAGE_NOT_VERIFIED`

This checkpoint reflects the operator's ai-g732 run and an independently rehashed uploaded ZIP's seven report members. It does **not** assert complete ART classpath resolution or IMS service runtime correctness.

## Results
- 7,078 carried-forward IMS1-B call sites.
- 3,059 deduplicated feature/method/opcode keys.
- 2,512 references have exact method definitions in the supplied **single** candidate telephony-common DEX JAR.
- 4,566 references remain `UNRESOLVED_CANDIDATE_CLASSPATH_INCOMPLETE`.
- Candidate DEX containers: 1; duplicate candidate class definitions: 0.
- Stock `ImsService.apk` and `MtkTeleService.apk`: `NOT_PROVIDED_PATH_UNRESOLVED`.
- Full bootclasspath order, inherited member resolution, app uses-library accessibility, binary manifest service metadata and runtime behavior: **not qualified**.

## ai-g732 evidence root
`/srv/data/sable-build/evidence/titan2/n1i-ims1c-consolidated-v1/`

| Relative file | SHA-256 |
|---|---|
| `APK_SERVICE_BINDINGS.json` | `decd37d464036ad5b75999e3e42bc9903ec1f9b0f6d3a125ba6a502137fb860b` |
| `CALLSITE_RESOLUTION.tsv` | `d81ed455f0c86b1bb9aed5a469188cde7d4252634d7ee31f6e125d116b9f6170` |
| `CANDIDATE_DUPLICATE_CLASSES.tsv` | `ce3a726d279f0aac153c4c698f4a8a883bb01fd265d110ab73582b901d2ffcda` |
| `CANDIDATE_PROVIDER_MANIFEST.json` | `af59b651a8b3f84b65651829e3b1a67b8d2553c9e667c0880b023ad0c116c71f` |
| `EXACT_METHOD_TRIAGE.tsv` | `104fbb3ec677bf3d378b733a2dcf7e8ce4d08bb1414596882adf82cdf0d35004` |
| `README.md` | `ca0bdcb6aa22ed8051d60ce714ed8a4dd8de15f14665c059d287e7024dbb68d2` |
| `SUMMARY.json` | `44e6c8c2ccba8f105e19aac93224b8ef5da99d7c9a33ce284597dc144c18e0de` |

## High-impact boundary
All 4,566 unresolved call sites are unresolved **against an incomplete candidate provider set**, not demonstrated ABI errors. A declaration present in one DEX is likewise not proof of runtime accessibility.

The triage contains static references in IMS, incoming-call and SIM-switching code. Their presence does not prove path reachability on-device. For example, high-frequency `log` callsites should not outrank MMTEL service-binding problems solely by frequency.

## Next consolidated gate: IMS1-D
1. Bind exact stock OEM APKs and their SHA-256; extract service/receiver/permissions and `uses-library` via `aapt2 dump xmltree` (binary AXML), rather than assume a manifest XML parser will work.
2. Recover authoritative stock and candidate bootclasspath, system-server classpath, app shared-library order and enabled package composition.
3. Feed classpath and target APKs to `build/titan2/n1i-b2-members.py` to evaluate invoke-kind, inheritance and access. Deduplicate unique failures by caller/invocation/owner/name/proto with source SHA evidence.
4. Rank actionable failures, distinguish source ABI patches from product integration/configuration, and preserve AtlasOS comparisons as hypotheses.
5. Do not build, modify protected checkouts, contact device or flash without separate authority.
