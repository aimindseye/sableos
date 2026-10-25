# PR347 remaining Q25 owner closure: Command + Keyguard bounded implementation (2026-10-22)

## Status and safety boundary

**PARTIAL IMPLEMENTATION; NOT ALL REQUESTED ITEMS COMPLETE.** User requested one combined deliverable for global Alt+Space Command, Keyguard keyboard, actual Browser and first-boot ownership, privileged security/profiles, SMS role, and IMS G1/G2/G3. Historical PR346/PR347 source and prior tests were reviewed; no duplicate Q25 Dialer, prior PIN mapping, Native25 or IMS receipts were re-run or replaced. Real AI-G732 Native25 `services`, `SystemUI`, `DocumentsUI` targeted `MODULES_PASS` is preserved at the corrected PWM source SHA256 `5b45a3a980af5854c4f52b056ee64fe2d9a9f27b8d2cdc6cbbead8a576204b08`.

### Newly authored, byte-verified source patches

1. `build/titan2/nextbuild/patches/PR347_GLOBAL_ALT_SPACE_COMMAND_REVIEW_ONLY.patch` (SHA256 `626241621f6260777af96a4e4061463873bf5facf07eae8d0b8f9149b5544e8a`) patches one existing `frameworks/base/services/core/java/com/android/server/policy/PhoneWindowManager.java` against **the exact earlier corrected/compiled source SHA** `5b45a3a980af5854c4f52b056ee64fe2d9a9f27b8d2cdc6cbbead8a576204b08`; final SHA256 `6ebb07b1241222d51c5401ff6165046d708c790bc953cab030313d36f8fa01ad`. Route a recognized, nonvirtual physical Alt+Space press to the already exported **explicit** `org.sableos.launcher/org.sableos.start.SableStartActivity` action `org.sableos.start.action.OPEN_COMMAND` via the input policy handler, rejecting unidentified/virtual keyboard, competing modifiers, held/repeated keys, current user locked, active keyguard and unfinished setup. If target activity isn't installed/exported at exact class and package, leave the key to the foreground app. Existing Android input consumer handles down/up pairing. **Full IME/text-field precedence not proven on device.**
2. `build/titan2/nextbuild/patches/PR347_KEYGUARD_PHYSICAL_ESCAPE_REVIEW_ONLY.patch` (SHA256 `ddc793b721f2b78643c35fd5919deb5f072082028abe7ff03b58ac7626432a06`) patches `frameworks/base/packages/SystemUI/src/com/android/systemui/keyguard/domain/interactor/KeyguardKeyEventInteractor.kt` against exact owner snapshot SHA256 `e8c63bc4a642615f6b9afaff9cc01ce1d7d73e14b7dffad19dfe29fd30189cb0`, postimage `bea9759c81e251bf6d1a1da4b606985b15cf21c197482d1a6dd165fdd911681e`. Physical full-keyboard Esc delegates to the **existing** Keyguard Back/bouncer path. Virtual/unidentified/nonfull devices and credential handling remain unchanged. **Does not represent full Q25 0304 parity.**

### Chat handoff

`TB2_PR347_COMMAND_AND_OWNER_CLOSURE_V1.zip` exact SHA256 `6086458c3b3f28239922bfb7aacd1076724e5dd55a3c9bb148add1fb6e8afd6f`; 145,818 bytes; 15 packaged members; SHA256SUMS and ZIP CRC PASS. Contains both original and modified source copies with exact SHA pins, two review patches, two guarded one-file staging/backup/restore operators, a two-owner atomic-preflight wrapper, 20 host Python tests, 18 real Java assertions over the exact new framework switch case and 14 Kotlin assertions over the exact new Keyguard method, plus machine-readable remaining gate matrix.

Validation: **20/20** Python regression tests PASS (~6.7s including a real Kotlin compile), `javac` exact case PASS_18, `kotlinc` exact method PASS_14, Python bytecode and Bash syntax PASS, both `git apply --check` and actual scratch replay match expected postimages. Only host-side code/test work. No Android source mutation, AOSP compile, image, device, IMS runtime, flash performed by assistant for these two patches.

Operator on ai-g732 (existing Track B, preserved `out/`, **explicit stage mutation**; no extra workspace or full source audits):
```bash
cd ~/Downloads && unzip -q TB2_PR347_COMMAND_AND_OWNER_CLOSURE_V1.zip
cd TB2_PR347_COMMAND_AND_OWNER_CLOSURE_V1
sha256sum -c SHA256SUMS.txt
bash operator.sh test
bash operator.sh plan
EVIDENCE="/srv/sable-build/evidence/titan2/pr347-command-keyguard-$(date -u +%Y%m%dT%H%M%SZ)"
bash operator.sh stage "$EVIDENCE"
bash operator.sh compile "$EVIDENCE"
cat "$EVIDENCE/RESULT.json"
```
Inside external `tmux`. Stage checks **both** source fingerprints before touching either, backs up each exact original byte sequence externally, rolls Command back if Keyguard stage errors, and compiler targets only `m -j4 services SystemUI` against the existing incremental `out/`; no systemimage. This is a **candidate pending AI-G732 actual module compilation**.

### Still genuinely OPEN — cannot safely fake completion

- **Browser:** Q25 Jelly source absent on native A16 checkout and selected installed user-facing browser unknown; WebView engine is not a browser. Need the effective installed APK and its source owner, then integrate keyboard/tab/reader behavior there.
- **First boot:** Lineage SetupWizard source absent, Sable Setup is *post-provision checklist*; actual privileged wizard/provisioning/FRP owner has not been bound. Must not replace with arbitrary activity.
- **Privileged AppLock/Vault/Freezer/Dual/profiles:** no proved server-side launch blocking, CE/profile isolation, package suspension and notification/recents redaction. An app Settings toggle/storage-only boolean does not constitute security enforcement.
- **SMS:** Sable Messages is a read-only provider observer with hard-restricted `READ_SMS` and `ACTION_SENDTO` composition delegation, not necessarily the default SMS app; `WRITE_SMS` cannot be force granted. Need actual selected RoleManager/default SMS owner, installer allowlisting, user grants and inbound delivery role tests.
- **IMS:** selected PhhIms is a **source candidate**, not effective G1 service/JAR/privapp/signing/classloader proof, G2 native linker ABI proof, or G3 vendor IPC/registration/VoLTE/DSDS runtime proof. Existing historical OEM/Phh reports apply to their prior source/image scope and must not be promoted as current PASS.
- **Keyguard extra 0304:** PIN/IME and keyguard hints beyond safe Esc/retained Titan PIN owner remain context-sensitive and device/runtime unqualified.

Thus **do not alter `Q25_SOURCE_READINESS.json` to green, bypass `check-ready.py`, run full image/flash or merge PR347** on this host-only candidate. PR346 pinned head `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab` is untouched remotely. The existing Track B source/out intentionally contains the previously authorized compiled Native25 changes.
