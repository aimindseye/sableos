# PR342 A1S actual no-write refusal: archived Android linkfile; V1.1 exact repair

**2026-10-14 engineering lane**. Scope remains isolated A1; PR open/draft/unmerged. Source/image build, device, super and flash remain prohibited until actual qualified host-only build admission.

## Operator's real A1S V1 outcome

Operator verified A1S V1 outer package SHA256 PASS, 13 inner members PASS, Python AST PASS, Bash syntax PASS, and 29/29 synthetic tests PASS (0.133s). The plan returned no host I/O. Real one-use operation returned **`REFUSED_A1S_PREFLIGHT_NO_NEW_EVIDENCE`**, `reason=source_envsetup_not_regular`, `build_ready=false`, `systemimage=false`. This was a preflight refusal BEFORE creation of A1S receipt or Android shell release invocation. **Do not rerun old A1S V1**. Earlier A1R V1.2 generated all 61 PHH product files and `m -j4 nothing` returned zero before a Make `TARGET_RELEASE` empty-value parser failure; A1P 12 source payload/policy leaves and A1Q 3 independent Git stores remain completed. No repeat audits.

## Definitive cause from completed earlier archived-manifest work

A1D `n1f_p342_a1d_manifest_destinations_v1.py` recognizes archived October 03 `build/envsetup.sh` as an Android Repo `linkfile` attached to project `build/make`, source `envsetup.sh`, with literal target **`make/envsetup.sh`**. That means `build/envsetup.sh` must be a **SYMLINK**, not REGULAR. A1Q config-only driver previously permitted REGULAR or SYMLINK and its Android `m nothing` run completed once A1R restored generated products. A1S V1's new check `state(root+'/build/envsetup.sh')!='REGULAR'` contradicts the exact manifest. The current refusal is a gate bug, NOT proof the Android source lacks envsetup.sh or a new user-input requirement.

## A1S V1.1 narrowly corrected operator ZIP

Name `N1F_P342_A1S_EXISTING_GRAPH_RELEASE_ADMISSION_V1_1.zip`, exact **SHA256 `dce43729680e6aa76d0b57dd34ec4dff37d2d3138f722d332b20a47bf58a0a41`**, **49,772 bytes**, 14 ZIP members = 13 SHA-sealed members plus `SHA256SUMS.txt`. Main Python module `n1f_p342_a1s_postgraph_release_admission_v1.py` SHA256 **`53cdf68c02400d018b0d10380bab7a29252482f5fd7d7024cca9af901167803a`**; wrapper `n1f_p342_a1s_one_command_v1_1.sh` SHA256 **`4e996321b91bfd1832945abe48d7adb1a586e3c79b0b00e9c7efad725df44522`**. Existing A1D/A1M/A1O/A1P/A1Q/A1R Python imports are byte-for-byte unchanged; previous original A1S product variable and shell release checks otherwise unchanged.

The new preflight `require_archived_envsetup_link` demands `safe.classify_exact_leaf(root+'/build/envsetup.sh')` return SYMLINK with **exact `literal_target_not_followed=make/envsetup.sh`**, then independently demands source path `root+'/build/make/envsetup.sh'` be REGULAR with a no-symlink-ancestor walk. Refuse outside/absolute/other literal links, symlink target, symlink directory ancestors, missing target, or replacement with regular leaf. Do not follow an arbitrary link. This repair writes no Android source. It reuses A1R successful `m -j4 nothing` evidence, original strict C1/C3B config vars and 61 generated file hashes, and runs only existing A1R out-config `source build/envsetup.sh; lunch treble_arm64_bvN-bp4a-user` to confirm shell `TARGET_RELEASE=bp4a` and product/user identity. No `m nothing`, systemimage, repo, git, stock audit, generator or device. One-use A1S evidence directory only. The `.A1_INCOMPLETE_DO_NOT_BUILD` marker remains and `out-a1` absent.

**Local QA:** ZIP CRC PASS, 13/13 inner SHA256 PASS, Python AST/compile 8/8 PASS, Bash syntax PASS, **37/37 synthetic regressions PASS** original umask 077 and 022; **37/37 PASS on fresh extracted identical ZIP under umask 077 and 022**, plus internal SHA13, AST8, Bash syntax and I/O-free plan. Eight new focused tests: exact symlink positive, wrong/escaping/absolute links, missing target, redirected symlink target, replacement regular leaf, symlink directory ancestor, complete 61-file A1R preflight with correct linkfile, and an actual fake Android shell `lunch` through correct relative link with no `m` run. Synthetic 700-call nofollow linkfile check median **0.02938ms** p95 **0.05081ms**; 40-call complete 61-file evidence preflight median **2.86072ms**, p95 **3.35950ms**. Real ai-g732 Android lunch performance NOT measured. **A1S V1.1 actual host NOT EXECUTED.**

One operator action from outer-SHA-verified fresh extraction:

```bash
bash ./n1f_p342_a1s_one_command_v1_1.sh --authorize-a1s-existing-graph-release-check-only
```

Success `PASS_A1S_EXISTING_GRAPH_RELEASE_SHELL_CERTIFIED_HOST_IMAGE_CANDIDATE` indicates **scoped engineering host-only image-build candidate**, not build completion, production, boot or flash readiness. If refused before evidence, preserve original state; if one-use A1S evidence was created (success or incomplete), DO NOT rerun, preserve it. Only a separately controlled host-only systemimage driver may subsequently build and its resulting image requires post-build checks.

```text
A1P=ACTUAL_PASS_12_SOURCE_LEAVES
A1Q_GIT=ACTUAL_PASS_3_INDEPENDENT
A1R_V12=ACTUAL_PASS_61_GENERATED_FILES_AND_M_NOTHING_RC0
A1S_V1=ACTUAL_REFUSED_WRONG_REGULAR_FILE_ASSUMPTION_NO_WRITES
A1S_V11_LOCAL=PASS_ZIP_CRC_SHA13_AST8_BASH_TEST37_BOTH_UMASKS
A1S_V11_REAL_HOST=NOT_EXECUTED
BUILD_READY=NO IMAGE_BUILD=NO DEVICE=NO SUPER=NO FLASH=NO
```