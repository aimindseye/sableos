# Titan 2 Track B: integrated Q25/IMS pre-image gate — all current source gates and explicit holds

**Evidence date:** 2026-10-21 (actual owner ai-g732 outputs supplied). **Disposition: HOLD_PREIMAGE_GATES_OPEN**; no whole image, runtime qualification, device/flash or signature authorization.

## Completed existing host gates (do not rerun)
- Phase 12 source promotion: four A16 modified + three new sources, all SHA pinned. Real `source build/envsetup.sh; lunch treble_arm64_bvN-bp4a-userdebug; m -j4 SystemUI Dialer` EXIT 0 in 362.602s.
- Phase 13 source freeze: seven exact compiled-source files, snapshot SHA256 `ee7453e5c23194968b80ff82cfdc0d34464bfc8c2443b47a5e69917466a84da2`, 19,313-line successful Soong log SHA `8472ebaf144512b6133dd44b489f91fae2b21138acaf7eb9155cd4b3738fdc46`.
- Real combined source-native receipt `PASS_PHASE1_SOURCE_AND_PHASE2_NATIVE_COMPILE_ATTESTED`; verified frozen A16 source. Combined report Phase12 original SHA `5eb502b295ea3a02cff50697fc8866d4c3b28d3b1dbd43cc36aa518d7b3992d1`, source manifest `c2fa66c12ec09c246579ee6cd4776d0ea99d74f6b3d4f55d866e3001a5470704`.
- **Newest actual ai-g732 results:** isolated PR346 app quality Git worktree `/srv/sable-build/workspaces/titan2-track-b/q25-app-quality-pr346-257a037e88f2` prepared with explicitly authorized pinned fetch; `PASS_ISOLATED_PR346_SOURCE_7_MODULES` with six Git blob pins; canonical checkout unchanged at `7120a783ed418f2bb60651ff70793c602b419f25`. Subsequent actual combined `quality-plan` returned `QUALIFIED_7_APP_SOURCE_MARKERS_FOR_OFFLINE_QUALITY`. **Offline Gradle assemble/unit/lint/detekt/ktlint for seven apps has NOT RUN.**

## Reviewed upstream/design/reuse

- PR342: historic M4/G1 11/11 embedded payload hashes and skip_mount, M11/G2 platform signer, `android.uid.phone`, API36 configured boot JARs, R2/G3 direct 56 DT_NEEDED, 19 bounded Bionic cases and partial ELF metadata. These are **PASS_PRIOR_SCOPE**, not selected new-image G1/G2/G3. Physically flashed M4 **FAILED_RECOVERY**.
- PR344: current Track B source and IMS custody; PR345: Sonar CI-only (not proof of Android app/module/image or device); PR346: 26 upstream Q25 framework patch candidates + app source, many A16 installed-owner/security tasks remain incomplete. Q25 upstream `aimindseye/zinwaq25-sableos/docs/SABLEOS_GAP_REVIEW.md` records Q4 framework never built/flashed; don't copy Q25 patch authorizations blindly.
- **New design conflict detected on public shared `sableos-project/platform_sable`:** `docs/design/KEYBOARD_FIRST_SYSTEM_IMG_COVERAGE_AUDIT.md` specifies *SableLauncher HOME + Quickstep Recents-only*, while PR346 Track B custody preserves *Launcher3QuickStep HOME+Recents* and intentionally omits Q25 HOME removal. This is an explicit **Q01_HOME_RECENTS=OPEN** architecture decision, not an implementation detail. Design also mandates Sable Start three pages (Glance/Start/Hub) and actual profile-isolated Private Space/Dual/AppLock, not cloned APKs.
- Canonical Android16 `product/titan2/n1i-c1` OEM `ImsService`/Mediatek JAR/XML sources and Track B staged `vendor/sable/trackb13ims` FLOSS `PhhIms`/`Iwlan` are **separate**; don't co-install both or infer installed permissions from a source path. Existing historical `build/gates/n1i-c1-android16-contract.py` and `build/titan2/qualify-n1i-c1-postbuild.sh` can inform exact provider checks, not authorize this new Track B image. Current `build/devices/titan2.sh` N1B2 release remains AUDIT_ONLY_FAIL_CLOSED.

## Integrated next artifact — sealed offline auditor

`TB2_Q25_IMS_PREIMAGE_INTEGRATED_GATE_V1.zip`, local distribution SHA256 **`1170c3d41d2ba3ba8cd735332144f081f677a176aa131633361a1dfc1c2dc607`**, not committed as a binary. `preimage_gate.py`, `policy.json`, `operator.sh`, full source-implementation backlog, tests, README, engineering review, validation log, member SHA manifest. Python3/Bash syntax PASS; **27/27 synthetic regressions PASS (~0.27s)**; ZIP integrity and independent extracted tests PASS; local 100k bounded small SHA256 operations ~0.057s (not build performance). **This new operator has not run on ai-g732.**

- Read-only `plan` or read-only + one new output directory `audit` over known A16 `/srv/sable-build/workspaces/titan2-track-b/android`, isolated PR346 root, actual combined `COMBINED_RESULT.json` and isolated `PR346_QUALITY_SOURCE_RECEIPT.json`.
- It re-verifies seven CURRENT A16 native after-SHAs, fixed combined source/Phase12/log/freeze digests, isolated exact Git HEAD and six marker Git blob SHA1s, seven Gradle owners, optional actual `QUALITY_RESULT.json` and both matching log SHA256 with 35 task identities.
- Source-only inventory: 26 PR346 retained Q25 patches, installed-owner directories, FLOSS/OEM staged IMS candidate paths. **Stage path presence does not pass selected effective image graph, privileges, or ABI namespace.**
- The policy lists source/privileged-Q25/IMS/build preimage gates plus **postimage** exact embedded G1/G2/G3/AVB/LP and **runtime** SIM1/SIM2/DSDS/VoLTE and HOME/SMS acceptance. `--ims OEM|FLOSS` is documented *intent*, not proof of a selected provider.
- Expected honest status: `HOLD_PREIMAGE_GATES_OPEN`, process exit 78, `image_build_authorized=false`, `flash_authorized=false`. Only pre-existing native and source gates can PASS now; Gradle may PASS after real execution. Other source/security/IMS gates have no real owner-specific validators, thus CANNOT be declared complete from an unchecked JSON claim.

## Next local commands (after checksum/tests)
```bash
cd "$HOME/Downloads/TB2_Q25_IMS_PREIMAGE_INTEGRATED_GATE_V1"
sha256sum -c SHA256SUMS.txt
bash operator.sh test
ANDROID=/srv/sable-build/workspaces/titan2-track-b/android
QUALITY_SOURCE=/srv/sable-build/workspaces/titan2-track-b/q25-app-quality-pr346-257a037e88f2
COMBINED="$HOME/Downloads/TB2_A16_PHASE12_COMBINED_ACCEPTED_20261021/COMBINED_RESULT.json"
SOURCE_RECEIPT="$QUALITY_SOURCE/PR346_QUALITY_SOURCE_RECEIPT.json"
bash operator.sh audit \
  --android "$ANDROID" --sable-repo "$QUALITY_SOURCE" \
  --combined "$COMBINED" --source-receipt "$SOURCE_RECEIPT" \
  --ims UNSELECTED \
  --out "$HOME/Downloads/TB2_Q25_IMS_PREIMAGE_AUDIT_20261021"
```
Optional *earlier* combined operator `quality-run` must be separately executed on exact isolated source with `--ack RUN_OFFLINE_Q25_SEVEN_APP_QUALITY_ONLY` to make a real `QUALITY_RESULT.json` and logs, then rerun this auditor with `--quality-result .../QUALITY_RESULT.json`.

**Source fixes remain to be written and qualified:** Q25 actual installed UI owner modules and 3-page Sable Start vs Quickstep roles, app Privileged AppLock/Freezer/Vault/Dual profile backends, read_sms hardRestricted selected app grant, browser/settings/setup/camera/contacts/files and full product wiring; one IMS provider, selected source+product G1/G2/G3 delta with signer/SELinux/classpaths and complete ELF namespace, then only after image the embedded and runtime checks. Do not run `build/sable.sh` full image yet. No new image, flash, device, network or AOSP source mutation by the auditor.
