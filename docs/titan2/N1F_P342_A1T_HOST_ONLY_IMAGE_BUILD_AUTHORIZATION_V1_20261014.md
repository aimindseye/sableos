# PR342 — A1T explicit host-only systemimage build authority and one-use driver

Date 2026-10-14. Operator explicitly said: **"i authorize image build. provide commands to run image build"**. This grants host-only Android 16 `make systemimage` for the already-qualified isolated A1 source checkout; it **does not** grant device contact, ADB/fastboot, repartitioning/super manipulation, slot operations, flash, release signing, network fetch, new source stages, or clean/clobber.

## Current real-host evidence (reuse, do not rerun)

- A1P 12 original IMS/C3B/policy source leaves staged PASS. A1Q 3 alternate-object Git stores made independent and verified; 991 archived project HEADs matched. A1R V1.2 61/61 PHH generated product registration files restored via pinned generator, `m -j4 nothing` returned 0; A1R post-graph `get_build_var TARGET_RELEASE` was empty, which was a false negative for shell release identity.
- A1S regression-test isolation incident accidentally created one-use A1S receipt, then improper shell `set -u` caused `build/envsetup.sh: line 26: TOP: unbound variable`. Original A1S receipt MUST stay `INCOMPLETE_A1S_PRESERVE_RELEASE_EVIDENCE` and is not reclassified as PASS. No attempts to rerun A1S tests or certify.
- **Actual operator independent release probe subsequently PASS**: `A1S_PRESERVED_STATE=PASS`, `TARGET_PRODUCT=treble_arm64_bvN`, `TARGET_RELEASE=bp4a`, `TARGET_BUILD_VARIANT=user`, `A1_RELEASE_PROBE=PASS_NO_IMAGE_BUILD`. Thus source/configuration/release conditions are sufficient to start an engineering host-only image build; compiled artifact remains unproven.
- Operator instructs two host-only Ubuntu diagnostic patterns **nonblocking when build commands otherwise succeed**: `Build sandboxing disabled due to nsjail error.` and `mkdir: '/system': Permission denied` (possibly repeated). Preserve raw messages, no fail from lines alone. Continue exit-code/artifact/SELinux checks. Note separate Panther host sandbox policy is not altered.

## Exact new external A1T deliverable

Operator script **`N1F_P342_A1T_HOST_ONLY_SYSTEMIMAGE_V1.sh`** (not installed into SableOS source) SHA256 **`affcf36ea0e0b53538ff0284db2d3247295f59f2bdc4ad3e044a9fa3f22cc688`**, **7727 bytes**, Bash syntax PASS. One-use explicit authorization **`--authorize-a1t-host-only-systemimage`**, optional `--jobs 8` (1–32 supported, default 8). Full script was locally mock-executed after replacing **both hardcoded A1 path occurrences** with a random temporary fixture root; production source root is explicitly forbidden inside test copy. Under BOTH umask 077 and 022, a mock envsetup/lunch/get_build_var/`make systemimage` PASS produced a mock image with SHA receipt and one-use evidence, a mock build exit 7 propagated exactly, missing auth refused before writes, and a second invocation refused `A1T_one_use_evidence_preexists_NO_RERUN` without deleting or overwriting anything. **4 end-to-end fixture scenarios PASS, plus 4 missing-authority + 4 duplicate-invocation refusals**. Mock runtimes ranged approximately 0.94–1.19 seconds each (process startup and fake Android only; NOT real build performance). Static scope asserts one `make systemimage` goal and no executable flash/ADB/repo sync/cleanup commands.

Frozen hardcoded A1 input: `/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android`. Atomically reserves `.A1T_HOST_ONLY_SYSTEMIMAGE_V1/` **outside Android source** as the only new build evidence, with `out` as fresh `OUT_DIR`, `systemimage.log`, `BUILD_SCOPE.txt`, `BUILD_RC.txt`, and on success `IMAGE_RESULT.txt` with output SHA256 and bytes. Leaves original `.A1_INCOMPLETE_DO_NOT_BUILD` marker exactly present; this is **an explicitly authorized image-build exception** and does not silently relabel source as globally complete. Original `/out-a1` must remain absent and no `.repo` is fabricated.

Before first evidence write, driver confirms immutable one-use receipts: A1P `PASS` stage12 with `build=false`, A1Q incomplete GRAPH but completed 3 Git stores and `systemimage=false`, A1R incomplete POSTGRAPH variable parser but generated61 and `systemimage=false`, A1S incomplete with its original rc1 `systemimage=false`, and all 3 alternates absent. Does **not rehash stock partitions, repack Git, re-stage apps, regenerate policy, rerun `m nothing`, or rerun A1S**. After explicit auth, shell disables nounset for Android envsetup (`set -eo pipefail`), unsets foreign TOP/GIT context, sources envsetup, `lunch treble_arm64_bvN-bp4a-user`, requires shell product/release/variant, Make Android16 and partition copyouts, all 11 C1/C3B PRODUCT_PACKAGES, boot JAR/override, marker and SELinux graph references, then executes **ONLY `make -j8 systemimage`**. Does not treat known host diagnostics as failure. Exit status captured from build subprocess through `tee` pipefail. Output expected at `<A1T evidence>/out/target/product/tdgsi_arm64_ab/system.img`; only on actual `make` rc0 plus nonempty image records SHA256/size and `PASS_SYSTEMIMAGE_HOST_ONLY`. A failure leaves original logs and output as-is and no auto retry/cleanup/rollback. A partial or completed build requires new human review before any attempt to reuse the evidence directory.

## Operator invocation

```sh
cd "$HOME/Downloads"
printf '%s  %s\n' 'affcf36ea0e0b53538ff0284db2d3247295f59f2bdc4ad3e044a9fa3f22cc688' 'N1F_P342_A1T_HOST_ONLY_SYSTEMIMAGE_V1.sh' | sha256sum -c -
bash -n N1F_P342_A1T_HOST_ONLY_SYSTEMIMAGE_V1.sh
bash N1F_P342_A1T_HOST_ONLY_SYSTEMIMAGE_V1.sh --authorize-a1t-host-only-systemimage --jobs 8
```

For long remote builds start/attach a dedicated tmux session if desired. The command does not launch a device/flash workflow. If it returns PASS, separately assess image GSI type, C1/C3B signed APK identity, IMS platform cert, bootclasspath, SELinux compiled contexts and G1/G2/G3 image integrity before any device authorization. **This A1T build permission alone is not production nor physical boot/flash eligibility.**

```text
A1SOURCE_PREBUILD=ACCEPTED_FOR_HOST_ENGINEERING_BUILD
A1T_HOST_IMAGE_BUILD_AUTHORIZED_BY_USER=YES_EXPLICIT
A1T_LOCAL_SCRIPT=PASS_BASH_SYNTAX_STATIC_SCOPE_MOCK_RUNS
A1T_REAL_AI_G732=NOT_EXECUTED
SYSTEMIMAGE=NOT_EXECUTED
SUPER=NO DEVICE=NO FLASH=NO
```