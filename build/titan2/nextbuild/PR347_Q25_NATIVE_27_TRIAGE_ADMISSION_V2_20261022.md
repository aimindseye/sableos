# Q25 26-patch actual AI-G732 triage — 27-source consolidated V2
2026-10-22 | Draft PR347 | **Review-only, NOT Android-compiled or image qualified**

## Exact input evidence
- Actual user/operator `TB2_PR347_REMAINING_Q25_26_PATCH_TRIAGE.zip`: SHA256 `21e88b85d17b7eb9ccfd3cf488d14bf71c05a029bdfa764aeca99f170174fcbb`, ZIP CRC PASS.
- Original captured Android16 owner ZIP `TB2_Q25_A16_OWNER_SNAPSHOT.zip`: SHA256 `a287e8e06daa2cf867aa2bdeaa174c7d0c12ecedf770c9f9b9f534f8829661aa`, 34 verified source files.
- Original combined unified patch `SOURCE_DIFF_NEXTBUILD_REVIEW_ONLY.patch`: SHA256 `7e54a1db98fc1d3448a459456fcabec158a03463fd5ba6ab2c4899c29985991a`.
- Operator source triage: **10/26 source context passes**, **16 holds**, **27 union source paths** = 18 existing preimage edits + 9 new paths. Scratch mode, no source/image/device mutation.

## Previously admitted (4)
`systemui-qs-base`, `systemui-qs-card`, `files-policy`, `files-keys`.

## Additional scratch-context passes (6)
| Patch | Feature, exact source boundary |
|---|---|
| `systemui-notification-core` (0301) | Keyboard notification-row commands + test, prerequisite for 0302 |
| `systemui-alt-shade` (0302) | Alt+Down route via PhoneWindowManager/SysUI (NOT global Alt+Space Command) |
| `systemui-toggle` (0303) | Focused QS Space toggle and Alt+Enter details |
| `keyguard-clock` (0305) | Lockscreen clock and unlock text |
| `systemui-led` (0501) | Framework notification light and tests |
| `dialer-in-call-keys` (0703) | In-call M/S/D shortcuts, **not** 0704 Space answer |

## Holds (16)
- **2 Android16 context mismatches:** `systemui-hints` (0304 PIN/controller/Keyguard indication), `dialer-space-answer` (0704 InCallActivity + XML new-file collision / context). Must adapt to exact Android16 owners, not fudge patch context.
- **3 owner absent at captured Q25 paths:** browser Jelly policies 1041/1042 and first SetupWizard 0401. Does not prove no browser/first-boot component in installed image; authoritative owner still unidentified.
- **3 security/device-authority holds:** Settings Mobile Manager policy/pages (AppLock/Focus/private-space with no privileged enforcement), Q25-specific keyboard backlight.
- **8 dependency holds:** Settings setup-only and seven downstream SetupWizard patch stages. Do not auto-create a fake privileged wizard or incomplete dependency chain.

## Combined sealed assistant handoff
`TB2_PR347_Q25_NATIVE_27_CONSOLIDATED_V2.zip`: SHA256
`aab99ea72edf3169fc6bfeadad452a10b0fdd2d8fb584631b70c7af404d23908` (822,367 bytes, 13 ZIP members).

Contains original two *byte-identical* input ZIPs; `ADMITTED_27_REVIEW_ONLY.zip` (27 exact source postimages, a replayed patch and 27 before/after SHA pins); full hold matrix; read-only drift checker; create-only re-seal; no Android-source apply code. Tests are self-contained with no network, no device, no image:
- **16/16 Python regressions PASS**, including exact reapplication of the 27-path unified diff to the 34-source snapshot, identical postimage check, old source hash drift/new-file collision/symlink/ZIP-path/duplicate/tamper holds.
- **47/47 pure-Java assertions PASS** compiled with real `javac`: 25 for QS/shade/Dialer policies plus 22 existing original Q25 Files policy assertions.
- Bash syntax PASS; ZIP CRC, packaged SHA256SUMS (12 member inputs) PASS.
- Entire outer ZIP was independently extracted and its SHA checks, host verification, and tests rerun PASS (0.324s for 16 Python tests in extracted fixture).
- **No** actual Android16 SystemUI/Files/Dialer Soong module build, no AOSP system image, no device/flash/IMS registration.

**Operational** (read-only only):
```bash
cd ~/Downloads
unzip -q TB2_PR347_Q25_NATIVE_27_CONSOLIDATED_V2.zip
cd TB2_PR347_Q25_NATIVE_27_CONSOLIDATED_V2
sha256sum -c SHA256SUMS.txt
bash operator.sh test
ANDROID_ROOT=/srv/sable-build/workspaces/titan2-track-b/android bash operator.sh verify
```
`ANDROID_ROOT` verifies 18 exact old preimages and nine expected absent new paths without writing. A mismatch is a **HOLD**, not a mandate to clean/reset/overwrite the Android source. There is no live apply/promote subcommand; the sealed postimages are for a separate next-build source revision once all native security and owner integrations are agreed.

## Build boundary
Full PR347 Q25 source acceptance remains OPEN (23 conformance rows; previously recorded 30 pending source-admission requirements + one N/A). New fixes still required: global Alt+Space, 0304 Keyguard safety/indications, 0704 Telecom-aware Space answer, installed browser and first-boot owner, real AppLock/Vault/Freezer/profile privileges, SMS default role/restricted grants and selected IMS G1/G2/G3. Do **not** use PASS_SCRATCH_CONTEXT_ONLY as evidence of compile or installed runtime.

Frozen PR346 remains exactly `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab` and its interrupted Ninja out artifacts are untouched.
