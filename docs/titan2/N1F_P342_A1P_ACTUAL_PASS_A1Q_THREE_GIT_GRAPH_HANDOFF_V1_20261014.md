# PR342 — A1P actual PASS; A1Q exact three Git alternate stores and config-only Android graph

Date: 2026-10-14, engineering lane. PR open/draft/unmerged. User requested a concrete next deliverable that does not repeat completed provenance checks, and requires all genuine PRE-build qualifications before host-only `systemimage`. No flash/super/device authority.

## Actual prior operator state (DO NOT REPEAT)

AI-G732 A1P real `PASS_A1P_OFFLINE_PAYLOAD_AND_POLICY_STAGED_BUILD_HELD`: 12 A1 source leaves created (6 C1 pinned stock APK/JAR/XML, 5 C3B unsigned APKs, 1 stock CIL-derived `property.te`), evidence `/.A1P_SINGLE_PASS_BUILD_PREP_NO_BUILD_V1`, no-build marker preserved, out-a1 absent, no build/network/device/flash. One bounded archived repo census `991/991` HEAD MATCH, no head mismatches, elapsed 0.34s; precisely **3 alternate-object project stores** remain `device/phh/treble`, `external/libsrtp2`, `prebuilts/vndk/v29`. `.repo` absent. A1P is ONE-USE DONE. A1O actual 6/6 C1 payloads streamed from two exactly pinned EROFS partition images and SHA-match. A1F–A1L source post accepted. Avoid any further stock hash, app bundle, policy import, or 991 HEAD census.

Main GitHub SableOS legacy C1 `run-n1i-c1-cellular-isolation.sh` explicitly rejects absent `.repo` as an old driver policy, whereas prior N1F direct envsetup/lunch/get_build_var/make systemimage driver does not implement that artificial precondition. It would be incorrect to fabricate `.repo` or run `repo init/sync` just to satisfy the old combined driver; use direct exact A1 configuration. Historical PR339 closed and its M4 physical image failed Recovery; never reuse it.

## External A1Q one-use single workflow

`N1F_P342_A1Q_THREE_GIT_OBJECTS_GRAPH_V1.zip` exact **SHA256 `4d776fbf1210dafa3825c9b899d5f4610c96017203bb2b94db35b889ae11e42a`**, **39259 bytes**, 12 archive members (11 internal SHA sealed + `SHA256SUMS.txt`). Main Python `n1f_p342_a1q_three_git_objects_graph_v1.py` SHA256 **`5aeffe93740b53f9ec707c8100dc41ae6e3cc40bf8b8568b4df5bff9e6d1e118`**; one-command Bash wrapper SHA256 **`8561a3001079975faeb91b1062e74a86e3a1f4c56d302bea9885eaaa36a324f1`**. Existing A1D/A1M/A1O/A1P production modules included **unchanged exact SHA pins**.

One opt-in `bash ./n1f_p342_a1q_one_command_v1.sh --authorize-a1q-exact-three-git-repacks-and-graph-only` from independently SHA-checked fresh ZIP. It prechecks completed A1P receipt+12 staged bytes+frozen A1 source pins and preserved A1 no-build marker/absent out/.repo, binds the three Git source HEADs to SHA-pinned Oct03 archived manifest; **only within those three selected A1 `.git/objects` stores** uses `git repack -a -d --no-write-bitmap-index` deliberately without `--local` to copy borrowed reachable objects; atomically backs up original `alternates` files into one-use isolated A1 evidence and checks independent `git fsck --full --connectivity-only --no-reflogs`, unchanged HEAD, and reachable object closure with alternate files absent. Never modifies original protected donor, M4 or canonical SableOS repositories. No retry/automatic rollback/cleanup if partial; preserve all evidence/alternate backups.

After those exact three checks, config-only Android `OUT_DIR` is a **private `.A1Q_THREE_OBJECTS_GRAPH_NO_IMAGE_V1/out-config`**, not `out-a1`. Runs `source build/envsetup.sh`, `lunch treble_arm64_bvN-bp4a-user`, 11 exact `get_build_var` validations (product/release/Android16/embedded system_ext, 11 C1/C3B modules, two boot JARs and overrides, marker copy, C1 SELinux owner), and Android phony `m -j4 nothing` to generate/evaluate Soong/Kati graph **WITHOUT systemimage**. Complete diagnostics in one-use `config-graph.log`, `config-vars.tsv`, `RECEIPT.json`; no network fetch explicitly invoked, no mounts, device, super, or flash. The exact status on success is `PASS_A1Q_THREE_PROJECTS_SELF_CONTAINED_ANDROID_CONFIG_GRAPH_ONLY`; `build_ready=true` denotes **scoped engineering host-only image-build preflight**, not production, boot or flash readiness. If actual config fails, `INCOMPLETE_STOP_PRESERVE_SOURCE_AND_BACKUPS` with build_ready=false and log reason. No generic audit-only PASS.

## Local QA and limitations

Actual generated ZIP CRC PASS and all 11/11 SHA256 member checks PASS. Python AST+compile 6 files PASS; wrapper Bash syntax PASS. **16/16 focused tests PASS** with `umask 077` and `022`; **fresh extracted exact ZIP 16/16 PASS** under both. Tests include actual small borrowed-object Git repositories, one end-to-end three-repository local detach/fsck/backup fixture, wrong SHA/missing source/one-use refusal and fake Android `lunch`/`m nothing` graph generation with required exact variable checks. Plan-only 1000-call synthetic timing median **0.000425ms**/worst **0.000747ms**, not an actual real repository/object/Android graph benchmark. Real ai-g732 A1Q NOT RUN; real 3 Git repack or platform config timings unknown. Per-Git command and graph subprocess timeouts exist; no promise that live Soong will succeed if real source graph is defective.

No rerun of completed A1F–A1P source stages. `m nothing` config is not the final `systemimage` and compiled SELinux, final G1/G2/G3 system image and physical boot/PHH marker visibility remain post-image/pre-device proof. The historical 369 patch composition is not retroactively declared byte-equivalent to every old image; only actual selected A1 source pins and its generated graph are admitted for a host engineering build candidate.

```text
A1P_OPERATOR=PASS_STAGED_12
A1P_ARCHIVED_HEADS=PASS_991_OF_991
A1P_ALTERNATES=EXACT_3
A1Q_LOCAL_PACKAGE=PASS_ZIP_SHA11_AST6_BASH_TEST16_BOTH_UMASKS
A1Q_AI_G732=NOT_EXECUTED
ANDROID_SYSTEMIMAGE=NOT_EXECUTED
DEVICE=NO SUPER=NO FLASH=NO
```