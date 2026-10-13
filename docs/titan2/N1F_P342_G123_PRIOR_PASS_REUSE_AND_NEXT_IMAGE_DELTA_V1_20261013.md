# PR #342 — G1/G2/G3 existing PASS reuse and next-image delta V1

Date 2026-10-13. **Supersedes imprecise blanket OPEN wording** in earlier PR #342 roadmap summaries. These are *separately scoped historical successes*, **not** complete final-image admission for a new October 3-derived build. Sources reviewed: closed/unmerged PR #339 operator comments (original “Update PR 339 Findings” lane), active PR #342 and main SableOS built-in C1/E4 host tool contracts. No new source, compile, image, network, phone or flash work was performed.

## Crucial correction: PASS already done

| Gate | Previously finished (reusable PASS at original scope) | Exactly what is still open |
|---|---|---|
| G1 | M4 selected product graph capture **six packages, two boot JARs, two configured-JAR location overrides, source/OUT capture binding**; selected R1/B1 post-state, C1/PHH source; M4 complete system image and **11/11 embedded member hashes**; embedded `skip_mount.cfg` source/staging byte match plus compatibility symlink | *Next* Oct03-derived image exact source-to-build/effective installed embedded IMS payload, effective product/system_ext/skip mount, final seal; cannot transfer failed M4 content verdict blindly |
| G2 | M11 ImsService APK cryptographic SableOS platform signer `c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8` **PASS**; manifest `com.mediatek.ims` and declared `android.uid.phone` PASS; M4 `bootclasspath.pb` semantic API36 **exactly one boot record for each** of the two MediaTek JARs; embedded XML/CIL/file-context file hashes included in 11/11 | *Next* image final cert/UID/runtime classloader, merged/effective SELinux and privapp/permission admission, mount/init consumer semantics; file presence/CIL alone insufficient |
| G3 | Five R2 library exact SHA/architecture, **56 direct DT_NEEDED**, **19 bounded Bionic**, **four direct unversioned symbol/version observations** (V28), six M4 ELF SONAME/architecture/NEEDED inspections and build-time linker protobuf metadata recorded | Full transitive strong-symbol/version reachability and actually effective IMS classloader/linker namespace including APEX/vendor allowed public/LLNDK, plus correct installed paths. Old partial PASS not global ABI proof |

**Key historical citations:** [G1 capture binding PASS](https://github.com/aimindseye/sableos/pull/339#issuecomment-5497725672); [B1 source and G1 source PASS](https://github.com/aimindseye/sableos/pull/339#issuecomment-5497674970); [M4 skip-mount staging bytes PASS](https://github.com/aimindseye/sableos/pull/339#issuecomment-6154056789); [M11 APK signer+manifest PASS](https://github.com/aimindseye/sableos/pull/339#issuecomment-5497763741); [API36 BCP PASS](https://github.com/aimindseye/sableos/pull/339#issuecomment-5502520401); [M4 11/11 content PASS](https://github.com/aimindseye/sableos/pull/339#issuecomment-5502638731); [G3 V28 four GNU symbols](https://github.com/aimindseye/sableos/pull/339#issuecomment-6134453980); [M4 six ELF metadata PASS](https://github.com/aimindseye/sableos/pull/339#issuecomment-5502768842); [engineer final-image criteria](https://github.com/aimindseye/sableos/pull/339#issuecomment-5508562816). Source is archived operator assertions, not independently re-run now.

**Additional already-qualified context:** M11 targeted build **14,094 actions PASS** and a later complete frozen M4 system.img SHA256 `261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce` size **3,194,466,304 bytes**, with 11/11 embedded SHA and two enabled bootclasspath records. The physically flashed M4 `system_a` boot **FAILED_RECOVERY**. Neither M11 nor that exact finished M4 image should be rebuilt merely to rediscover their historical PASS, and M4 is **not a verified new booting parent**.

Selected distinct Oct03 N1F host parent `system.img` size **3,200,540,672** SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a` was independently rehashed once **PASS_HISTORICAL_REFERENCE_ONLY** under approved B1. That proves retained host bytes equal historical receipt, not Oct03 same-session physical `system_a` readback, other seven slot-A companion bytes, postflash LP/VAB/AVB or matched restore.

## Next deliverable scope and quality

Operator ZIP **`N1F_P342_G123_REUSE_V1.zip`** outer SHA256 **`ad7ffeea5d5fbd00d256946d3b86136d326227c632a4aba7aaf4a391a4486850`**. Five internal payload members + SHA256SUMS manifest. Main `n1f_p342_g123_reuse_v1.py` SHA256 **`22204623501c637077cd95772fee170e07db97e8eac94d6c0cd47c926adfa0cf`**; test `test_n1f_p342_g123_reuse_v1.py` SHA256 **`003af98c8843e134d0b4a41e8a58167a5dbeb75e4f54aeda7d62e6385a3503a3`**. Python AST PASS both; **20/20** local synthetic safety/tests PASS, full process 1.38s/98,696 KiB peak. One thousand synthetic classify calls median **0.00199ms**, p95 **0.00215ms** (not ai-g732 host/file timing). ZIP integrity/internal manifest PASS. Python >=3.10 standard library and `unzip`/`sha256sum` transfer tools only; **no AOSP binaries, external connector, install or privileged tools**.

This is a read-only **report-only historical reuse classifier** over a SHA-pinned bundled JSON ledger. It **does not** revalidate on-host source/image bytes and cannot confer a newly passed G1/G2/G3 final gate. It has no inspection or mutating mode and refuses unrecognized arguments. Output label `PASS_CATALOG_INTEGRITY_ONLY_NO_NEW_ENGINEERING_ADMISSION` is deliberately limited.

## Targeted path to next image without repetitive work

1. Reuse G1 source/capture, G2 signer/BCP, G3 identities/direct symbols, M11, frozen M4 content and existing TF flash regression results **at their exact source/image scope**; no broad recensus or rehash.
2. Specify **exact** Oct03-derived target source and intended integrated R1/B1/C1/IMS/R2 delta. Create a reviewed no-write construction manifest and future admission tests against *new* artifact; do not import 5 R2 without the G3 precise outstanding closure.
3. Independently bind Oct03 companions, LP/Virtual A/B, AVB/restore and the necessary image/boot-path equivalence before any offline whole-super design can be called qualified.
4. Only under **separate** user source/build permission, produce an isolated system image, then check only final-image differences for G1/G2/G3. Offline super repack requires **separate** authority and LP/AVB/restore proof. Physical device/flash requires an even later separate authorization and fail-closed rollback semantics.

### Restoration R0C gate not widened

Operator confirmed R0C ZIP SHA and **22/22** regression PASS, then `PLAN_ONLY_NO_FILESYSTEM_ACCESS` with `entry_cap=256`, `match_cap=96`. This is **not** actual R0C directory execution or approval. Prior R0 cap=64 REFUSED, and R0B exactly seven boot/AVB direct leaves = NOT_PRESENT_AT_THIS_EXACT_ROOT; none are global absence. New 256-entry filtered listing still needs **separate authorization**.

```text
G1_M4_SOURCE_GRAPH_STAGING_EMBEDDED_CONTENT=PASS_PRIOR_SCOPE
G2_M11_CRYPTO_SIGNING_M4_API36_BOOTCLASSPATH=PASS_PRIOR_SCOPE
G3_R2_IDENTITIES_DIRECT_EDGES_SYMBOLS_M4_ELF=PASS_PRIOR_SCOPE
G1_G2_G3_NEXT_IMAGE_ADMISSION=OPEN_TARGET_DELTA
OCT03_PARENT_B1_HOST_HASH=PASS_HISTORICAL_REFERENCE_ONLY
OCT03_PHYSICAL_COMPANIONS=UNBOUND_7_OF_7
R0C_AI_G732=PLAN_ONLY_22_OF_22
R0C_256_NAME_INSPECTION=NOT_AUTHORIZED
SOURCE_MUTATION=NO BUILD=NO REPACK=NO NETWORK=NO DEVICE=NO FLASH=NO
```
