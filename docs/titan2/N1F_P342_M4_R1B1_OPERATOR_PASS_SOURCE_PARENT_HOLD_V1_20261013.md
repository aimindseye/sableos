# Titan 2 N1F PR #342 — actual M4 R1/B1 source PASS and source-to-booted-parent decision V1

Date: 2026-10-13. This is **documentation/evidence admission only**, not an Android image build, new artifact read or write authority.

## Accepted actual operator result — closes two-file source-state checkpoint

The actual ai-g732 operator executed the **previously explicitly authorized** two-file R1/B1 source-inspection mode of the SHA-verified `N1F_P342_R1B1_SOURCE_V1.zip` at `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`.

```text
R1B1_STATUS=PASS_TWO_SOURCE_STATES_IDENTIFIED_NOT_SOURCE_LINEAGE
SOURCE_ROOT=/srv/data/sable-build/workspaces/n1f-m4-localrepo/android
R1_PATH=frameworks/base/core/res/AndroidManifest.xml
R1_BYTES=541779
R1_SHA256=2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca
R1_STATE=POST_EXACT
B1_PATH=frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java
B1_BYTES=2547
B1_GIT_BLOB_SHA1=9d5108e0ddb8d4960d21cda021813b53dbbf4da8
B1_RAW_FILE_SHA256=2bc30b0df7c12eed9157aad57682562a4a0b928794ac55a8b650fa927d2fce1e
B1_STATE=POST_EXACT
TWO_FILES_READ=2 TOTAL_SOURCE_BYTES_READ=544326
R1_REAPPLY=NO B1_REAPPLY=NO
DIRECTORY_ENUMERATION=NO IMAGE_BYTES_READ=0
SOURCE_MUTATION=NO OUT_WRITE=NO NETWORK=NO BUILD=NO DEVICE=NO FLASH=NO
SOURCE_TO_IMAGE_LINEAGE_PROVEN=NO
G1_G2_G3_SELECTED_FINAL_IMAGE_ADMITTED=NO
```

The **one-time R1/B1 file read is executed and consumed**. It independently reaffirms [archived PR #339 official B1 PRE→POST source integration](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497674970) and isolated R1 POST. Source patches **must not** be re-applied.

## Historical source versus frozen image provenance — do not conflate

| Role | Previously sealed authority | Current decision |
|---|---|---|
| Oct03 actually Android-booted N1F source/image control | Source originally under `/srv/data/sable-build/workspaces/titan2-n1d/android`; separate archived booted `system.img` SHA `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a` size 3200540672 | **PASS_HISTORICAL_BOOT_AND_IMAGE_SHA**; offline planning parent only, seven Oct03 physical companions/LP/AVB/restore not bound |
| M4 source donor | Isolated reconstructed 991/991 C3A project worktrees; actual now-checked R1/B1 POST/POST | **PASS_SOURCE_BOUNDED**; source data only, not a boot-qualified new parent |
| M4 failed image | Full image `out-m4-g2-fullimage-01`, SHA `261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce` size 3194466304; 11/11 embedded member SHA and API36 classpath PASS; physical system_a write success, Android **FAIL_RECOVERY** | **NOT_BOOT_QUALIFIED**; no proven boot failure cause; no automatic reuse of M4 build/flash sequence |

Source mutations additionally pinned in PR339: C3B `base.mk` hash `9e197a490a61a5721b8bb881e93acbc451104957a9599895bc724cfb5768820b`, PHH board-base.mk Git blob `d8e43d683bb0f24118e073f178589ab6970507a5`, C1 product mk SHA `fb0d801edd470d13d68f4105586f8f18ac30c1255dd7fd1076bf02157c017c5e`, guard and marker SHA identities. These remain **historical scoped PASS**, not an assertion of complete post-build manifest lineage.

## Retired work and genuinely missing engineering delta

Do **not** redo R1 patch preview, B1 patch, 991-source reconstruction, M11 14094-action build, M4 final image hash, M4 11/11 contents or two bootclasspath JAR record checks, N1I-A A4 two receipts, C2 finite/native closure, five R2 input hashes/56 direct DT_NEEDED/19 Bionic/four direct GNU bindings, or historical Oct03 3.2GB SHA/run markers.

**Next non-duplicative work product:** a **source-to-parent/boot-critical-delta decision** from exact previously retained Oct03 original build-source manifest and *actual final* M4 build-source/exec receipt. Prior PR339 [partial M4 lineage pin](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5504302075) includes exact PHH/C3B and B1 states; it explicitly does **not** supply a complete finally built `repo manifest -r`/revision snapshot joined to the M4 image. The reviewed PR/repository evidence did not give an exact matching M4 final manifest receipt pathname; do not invent one, redo 991 census, run `find`, or silently read host files outside granted two-source scope. If an *existing exact named and capped small source/build log receipt* is identified, ask for a separate bounded approval before reading it. If not, retain `SOURCE_TO_PARENT_BRIDGE=UNBOUND`.

Review known boot-critical differences: legacy TrebleApp overlay source removal, PHH mtkmal guard/marker, PHH root-folder staging, `skip_mount.cfg` semantic priority, effective classpath and merged SELinux, C1 payloads; five R2 absent from M4 staging are **not proven cause of Recovery**. Further effective IMS privilege/runtime namespace and recursive versioned/native G3 remain distinct. A proposed R1+B1+C1 **host-only isolated** candidate, if one is later authorized, is explicitly **NON_FLASHABLE** pending new target-image and restore gates. No new full image build/repack/device command is approved here.

## Package and code QA

Provided **review-only** `N1F_P342_SOURCE_TO_PARENT_DECISION_V1.zip`, outer SHA256 `cedada92caab92b130268b477bac2aed31a95b17011948a824a795dc4997cf5d`. Contents: complete Markdown handoff, machine-readable JSON evidence/holds, README and SHA256SUMS. ZIP integrity, inner 3/3 SHA, JSON parse and 8 invariants PASS. It contains **no executable new script**; repeating an already-qualified source checker would be a regression in the work scope.

Existing frozen R1/B1 executable was **revalidated**, unchanged: outer SHA `d5d51bf25b725c6254cef39038caed60c486a0901893a33a7440a77e899dfa1b` PASS; inner 4/4 PASS; Python AST both PASS; 34/34 repeated local unit tests PASS (0.034s core, 0.81s process wall and 100488KiB RSS); README Bash syntax PASS. Synthetic **400 × 589866-byte** in-memory classifications median **0.5179ms**, p95 **0.7166ms** (assistant fixture only, not ai-g732 actual source-read time). The ai-g732 original actual regression run was 34/34 in 0.021s; actual source read duration not reported. Python >=3.10 stdlib; `sha256sum` and `unzip` are package distribution tools only.

```text
M4_SELECTED_R1_POST_EXACT=PASS
M4_SELECTED_B1_POST_EXACT=PASS
R1B1_PATCH_REAPPLICATION=FORBIDDEN_REDUNDANT
R1B1_READ_AUTHORIZATION=CONSUMED
SOURCE_TO_OCT03_BOOTED_PARENT_IMAGE=UNBOUND_FULL_LINEAGE
M4_FULL_IMAGE_BOOT=FAIL_RECOVERY
G1_G2_G3_NEXT_IMAGE=NOT_YET_ADMITTED
R0C_256_TEE14=NOT_AUTHORIZED
OCT03_PHYSICAL_COMPANIONS_LP_AVB_ROLLBACK=UNBOUND
SOURCE_MUTATION=NO BUILD=NO IMAGE_READ=NO NETWORK=NO DEVICE=NO FLASH=NO
```
