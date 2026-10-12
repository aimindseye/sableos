# October 12 Titan 2 execution order: LTE P0, IMS1-D P1, CW1 P2, OEM IMS P2

## Authority
Operator explicitly authorized **source mutation and device contact as needed**. This is not authority to build, reboot, change modes, flash or modify firmware. Preserve the active flashed image and dirty canonical repo; operate in an isolated Android tree only. October 11 ADB cellular enablement was temporary and failed to sustain registration.

| Lane | Status | What the existing evidence establishes | Next smallest action |
|---|---|---|---|
| **P0 LTE registration** | **OPEN_ROOT_CAUSE** | Prior GSI data teardown/rejection causes 11/13/15/114, while stock V01.00.14 control had zero cause 13 in retained capture. Earlier tray-1 stable data and IMS absent shows missing IMS alone is **not sufficient** to cause cause 13. Oct11 transient IN_SERVICE→OUT_OF_SERVICE after diagnostic ADB activation. Vendor `mtkNetworkIndication==NULL` is not a proven causal error (observed even in good window per N1I-B). | Compare **existing** Oct11 timestamps in `n1f-r3-r8m-radio-diagnostics-20261011` and prior stock/tray-1 captures before any new ADB. On an explicit later bounded device session, capture only modem rejection details, exact registration state transitions and framework/vendor callback timestamps; no radio property forcing or auto-healing. |
| **P1 IMS1-D** | **PARTIAL_STATIC / RUNTIME_UNBOUND** | Existing IMS1-A/B/C/D and D9.6 correction preserve APK/classpath methods and image-exact D1R2 `bootclasspath.pb`, `systemserverclasspath.pb` refs. D7 records 29 pinned artifact identities but doesn't establish current-image classloader/service binding. | Reuse retained protobufs/manifest and selected IMS01 module plan; decode exact bootclasspath/runtime classloader and service ownership only for the chosen derived N1F image. No new broad APK/DEX census. |
| **P2 CW1** | **PASS_COMPILE_DEX_STATIC; RUNTIME_DEFERRED** | CW1 isolated telephony-common compile and 4 DEX method definitions PASS; exact stock `invoke-super` static linkage PASS, semantics and incoming-call runtime still unknown. | Preserve warm out_cw1 and evidence; don't merge or add call-waiting patch to first radio-stability experiment. |
| **P2 OEM IMS** | **MINIMAL_ISLAND_DESIGNED; NOT_INSTALLED_IN_OCT11_RUNTIME** | `skip_mount.cfg` bypasses stock system_ext/product, making embedded `/system/system_ext` target necessary. Existing C1 `Android.bp` + product makefile already define OEM `ImsService`, 2 JARs, 3 XML configs and boot-jar location overrides. R1 source exact parent/pre-post SHA qualified. R2 five stock hashes and 56 direct NEEDED qualified; full namespace still open. | Use isolated R1 exact-source patch; qualify IMS01 source/build pins and R2 delta namespace from previously retained B2/C3A evidence before packaging. No historical D1R2 7-JAR/33-native expansion. |

## Exact R1 next mutation

The operator-validated source file at `frameworks/base/core/res/AndroidManifest.xml` has pre SHA256 `2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c` and expected one-line post SHA256 `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca`. Git pre blob `a7675341e1575039845d09c64fa22006612cca4a`. The approved one-line declaration is `<protected-broadcast android:name="com.mediatek.common.carrierexpress.operator_config_changed" />`, inserted after the existing `android.telephony.action.STK_SETUP_EVENT_LIST` declaration.

An independent no-network Python tool named `n1f_m4_r1_isolated_apply_v1.py` checks exact pre/post SHA before writing **only that manifest** with `--apply`; it refuses the known canonical Android tree and requires an isolated tree. The tool is distributed to the operator outside GitHub and does not bootstrap or mutate an Android checkout. On-disk patching does **not** authorize building or flashing. No IMS module, R2 lib or device command is included.

## Go/no-go

```text
R1_EXACT_SOURCE_PATCH=AUTHORIZED_OPERATOR_SCOPE_IN_ISOLATED_TREE_ONLY
P0_LTE_CAUSE13=NOT_ESTABLISHED_NETWORK_VS_MODEM_VS_FRAMEWORK
P1_IMS1D=STATIC_PARTIAL_RUNTIME_BINDING_PENDING
P2_CW1=COMPILED_STATIC_PASS_RUNTIME_DEFERRED
P2_OEM_IMS=DESIGN_READY_BINARY_NAMESPACE_PENDING
SOURCE_MUTATION_AUTHORIZED=YES_EXACT_R1_ISOLATED_ONLY
READONLY_DEVICE_DIAGNOSTICS_AUTHORIZED=YES_SEPARATE_TARGET_SESSION
BUILD_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

## R1 execution result — operator confirmed on ai-g732

The isolated `frameworks/base` Git worktree was created at `/srv/data/sable-build/workspaces/n1f-m4-ims01/android/frameworks/base` from the preserved N1F project commit `dfb660a1fd590efed475f388870032d2d416403b` (detached). **This is a single-project source worktree, not a standalone Android build root.**

Operator output proves:

```text
R1_EXACT_PATCH=PASS
R1_POST_SHA256=2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca
ORIGINAL_N1F_SOURCE=UNCHANGED
R1_ISOLATED_SOURCE=PASS
 M core/res/AndroidManifest.xml
N1F_M4_R1_RESULT=PASS_SOURCE_ONLY
BUILD_EXECUTED=NO
FLASH_EXECUTED=NO
```

The only changed line adds the `com.mediatek.common.carrierexpress.operator_config_changed` protected broadcast after `android.telephony.action.STK_SETUP_EVENT_LIST` in `core/res/AndroidManifest.xml`. `git diff --check` passed. **Do not commit or cherry-pick into the canonical Android parent yet.** Before compiling, explicitly establish a full build source namespace that consumes this isolated `frameworks/base` tree without mutating the retained source or CW1 workspace; preserve exact parent SHA and `skip_mount.cfg`. R2 namespace still blocks five native libs, and P0 LTE service stability remains open.

## N1F known-build output reuse gate v1 — operator results (2026-10-12)

Read-only gate `PASS_READ_ONLY_KNOWN_PATH_STATE`. Exact N1F build driver `build/titan2/run-n1f-c3a-derived-c3b5-r2.sh`, source `/srv/data/sable-build/workspaces/titan2-n1d/android`, output `/srv/data/sable-build/workspaces/titan2-n1d/out-c3a-td`, product `tdgsi_arm64_ab`, lunch `treble_arm64_bvN-bp4a-user`, build ID `BP4A.251205.006`, goal `systemimage`. Output and product directories and workspace `system.img` exist.

**Crucial image identity split:** workspace system image SHA256 `ea10fc487a1d13be4440ef3b01321f9c5f05fd0933b94774b996d8fefa046468`, while the preserved Oct03 N1F artifact `/srv/data/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img` independently passed its sealed hash `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`. The current workspace image is **not** the sealed N1F image; its provenance cannot be inferred from path or Android version. Do not replace the sealed control or reuse this output for a build without exact current build-graph provenance.

The R1 isolated exact one-line Git worktree remains PASS, original Android source clean, complete isolated build namespace NOT_ESTABLISHED, `BUILD_OUTPUT_REUSE=UNDECIDED_DO_NOT_WRITE`, original combined driver forbidden (requires flash authorization and modifies/restores original checkout), no build run. Recommended design: preserve `out-c3a-td` as potentially contaminated historical output; use a distinct M4 OUT_DIR only when a complete isolated source namespace and explicit build authorization exist. No further broad filesystem discovery.

## Offline local-object source reconstruction pilot PASS (2026-10-12)

Operator ran `n1f_m4_offline_reconstruction_pilot_v1_1.py` preflight (`PILOT_PREFLIGHT=PASS_NO_WRITE`) and `--create-pilot`; exact four local-object project reconstructions passed:

- `frameworks/base` HEAD `dfb660a1fd590efed475f388870032d2d416403b`, isolated R1 manifest replay qualified.
- `build/soong` HEAD `6725416b1cce7fe6080a863cee69ebc615701ca2`, retained C3A diff replay qualified.
- `device/phh/treble` HEAD `bbaf0c2ba33c15c574d9be4ad3b10895b702880f`, exact untracked `rom.mk` with SHA-256 `ab0ec737342d41d562816fce73e8694e35ce32e09db74c12ea115efa3619d592` replay qualified.
- `treble_app` HEAD `15b30c1a9cac951236db59e66a3ef8222872dfe8`, tracked `sdk/.knownPackages` diff replay qualified.

`PILOT_REPLAY=PASS_4_PROJECTS`, `ORIGINAL_SOURCE_CHANGED=NO`, `BUILD=NO`, `NETWORK=NO`, `DEVICE=NO`, `FLASH=NO`. Pilot source is `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`. There is **no `.repo` metadata yet and 987 remaining projects are not materialized**. Git alternates rely on retained local objects; this is not an independently archived object database. The next safe operation is a guarded **resume-only** reconstruction for the remaining pinned project paths using the already sealed 991-row C3A project ledger, without deleting or re-cloning the four qualified pilots. Validate project paths, independent Git metadata, object availability and pinned HEADs before any repo metadata integration. No build or flash authorization is implied.

## Offline M4 source reconstruction — 991/991 PASS (operator, October 12)

The bounded `n1f_m4_remaining_987_offline_v1.py` preflight passed and `--create-rest` populated all 987 remaining project worktrees, preserving the previously qualified four-project pilot. Source authority was the sealed C3A revision ledger at `/srv/data/sable-build/evidence/titan2/n1d-c3a-trebledroid-prep/20261001T152117Z-trebledroid-stage`. Reported `C3A_SEALED_LEDGER=PASS rows=991`, `FOUR_EXISTING_PILOTS=PASS`, `M4_991_PROJECT_HEADS=PASS`, `M4_REMAINING_987=PASS`, and `M4_OFFLINE_987=PASS_SOURCE_ONLY`. Target source: `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`. Existing C3A patch transfers and R1 isolated worktree were qualified by the pilot. `REPO_METADATA=NOT_CREATED`; do **not** claim the reconstructed source has passed lunch/Soong/product graph validation. Build, network, device, reboot and flash were not executed. Existing original N1F/CW1 checkout and outputs remain preserved. Next action: evaluate direct Android build tree qualification and only create minimal .repo metadata if actually required by the original driver or required build tooling; do not trigger a 991-project re-sync.
