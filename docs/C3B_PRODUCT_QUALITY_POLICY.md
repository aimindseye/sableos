# Code-quality policy (enforced from D2)

Canonical SableOS applies Detekt and Ktlint to maintained Android modules (`aimindseye/sableos`, `apps/r8/android`,
`config/detekt.yml`). This repository now enforces the same tools (D2):

```text
Detekt Gradle plugin = 1.23.8
Ktlint Gradle plugin = 14.2.0
Ktlint engine        = 1.8.0 (android code style via .editorconfig, android=true)
Detekt config        = config/detekt.yml, byte-exact copy, provenance in config/DETEKT_PROVENANCE.env
QUALITY_EXEMPTION    = NO   (applies to apps/titan2/platform and apps/titan2/screens, including the SableScreens prototype)
```

Enforcement is final, not report-only: Detekt `ignoreFailures=false`, Ktlint `ignoreFailures=false`, `buildUponDefaultConfig=true`,
`parallel=true`, `outputToConsole=true`. The operator full gate runs `assembleRelease test lint detekt ktlintCheck` in both Gradle
roots. The canonical Detekt rules are never edited here. Where a canonical rule cannot be satisfied without a risky rewrite of
uncompiled Compose code, a narrowly scoped source-level `@Suppress` with a `// reason:` comment is allowed only within the budget in
`config/QUALITY_SUPPRESSION_BUDGET.tsv` (enforced by the static gate, tracked as KL-025). Ktlint is never suppressed.

Supply chain: each Gradle graph has its own reviewed `gradle/verification-metadata.xml`, generated once by the operator with
`build/titan2/bootstrap-gradle-verification.sh --authorized-online-bootstrap`. After that, qualification is offline and strict
(`--offline --dependency-verification=strict`). SableOS verification metadata is never copied.

Test wording (do not shorten to "unit tests PASS"):

```text
JVM_SHIM_TESTS=PASS_OR_FAIL
TEST_FRAMEWORK=LOCAL_JUNIT_COMPAT_SHIM
GRADLE_JUNIT_TESTS=NOT_RUN_TOOLCHAIN_UNAVAILABLE   (developer lane; the operator runs the real Gradle tests)
```

History: D1a/D1b documented the policy without a plugin dependency graph (`D1_NEW_DETEKT_DEPENDENCY=NO`, `D1_NEW_KTLINT_DEPENDENCY=NO`).
