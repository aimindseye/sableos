# PR347 next-build source workspace

**Current build must continue untouched:** PR346 at `7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab`, AOSP workspace `/srv/sable-build/workspaces/titan2-track-b/android`.

**Development only:** `titan2/nextbuild-q25-app-conformance-20261021`, draft PR347 targeting the PR346 branch. Do not checkout this branch over the running canonical checkout or over the AOSP project workspaces.

## Work performed in this first, bounded implementation slice

- Q25 `model/CommandQuery.kt` and `privacy/AllAppsInteraction.kt` exact upstream originals integrated into SableLauncher Soong.
- Search command prefixes `? /apps @ # ! /settings /hub`, ranked recent local apps, best-match app row, and public Android Settings destination actions.
- All Apps keyboard Search and type-to-letter; granted-permission filter chips using the existing LauncherApps permission summary (not AppOps/recent-use reporting).
- Source review against original 23-row Q25 ledger in `Q25_APPLICATION_SCOPE_20261021.md`.
- Fail-closed source readiness manifest `Q25_SOURCE_READINESS.json` plus gate `check-ready.py` inserted **on this branch only** before the next integrated AOSP command.

## Host-only validation (no Android compile)

```bash
python3 -B -m unittest -v build/titan2/nextbuild/test_ready.py
python3 -B build/titan2/nextbuild/check-ready.py --report
python3 -B build/titan2/nextbuild/check-ready.py --require-ready
# The previous command is EXPECTED to exit 78 while scope remains open.
bash tests/titan2/q25-nextbuild/run-policy-smoke.sh
```

The pure Kotlin test compiles only the Q25 source policies plus the locally authored static permission-chip policy with `kotlinc`; it never builds Android, changes caches or contacts a device. It requires `kotlinc`/Java on PATH. The exact portable Kotlin policies were reconstructed by Git SHA1 and **compiled with kotlinc-jvm 1.9.0 / JRE 21** on the assistant host; the test jar printed **Q25_PORTABLE_POLICY_SMOKE=PASS_28**. This is a pure JVM smoke, not Android16 Soong/Compose compilation or runtime acceptance. Android16 Soong/Compose compilation remains **NOT RUN** for this branch.

## Verified assistant-host regression evidence

- Exact `check-ready.py` Git blob `d5f100afbfd5deff51bbe0e528a4b097bb6d41c9` reconstructed and Python bytecode compiled successfully.
- Exact `test_ready.py` Git blob `6fcebd246b478c5f46a3b96092396b7a445964c8` reconstructed and bytecode compiled.
- Exact readiness JSON Git blob `90e5e5818d92af68de9aae521e972822ee16004f` reconstructed.
- **10/10** standard-library Python tests PASS (0.023s test run on disposable local fixture): 23-row identity, required release HOLDS, row changes, invalid statuses, missing/hash-drift/symlink/path-escape evidence, driver invocation contract.
- Gate `--report` PASS/OPEN; `--require-ready` actual exit code 78 with `HOLD_Q25_AND_IMS_SCOPE_OPEN`.
- One short 5-process gate benchmark on this assistant fixture: **5.040s total, 1.008s/process** with Python interpreter startup overhead; not an ai-g732 timing prediction. A longer 40-process loop exceeded runtime limit; no result claimed.
- Exact host-only `run-policy-smoke.sh` Git blob `0864b4de2906b0f6a481d9641976b79e5b5f7d41` reconstructed; `bash -n` PASS. The Kotlin smoke source blob `a2c2e9d3a1c00cd3690525ab0dc811b667345de7` matched and the 28 JVM assertions PASS. Original upstream Git blobs for Q25 Command `76d67ab365ec20fc9d54ca7afbeba82638f7efa4` and All Apps `18591715002707aa5878266c34f795e357e7b573` were matched exactly; permission-chip blob `ccadb18da0815e1adf714f4b260ddd598c3297dc` matched. Full Android `m`/Kotlin Compose compile NOT EXECUTED.

## Next source work; NOT done in this slice

**Do not construe this PR as complete Q25 application parity.** The original 23 conformance rows cover Sable Start three-page Home/Glance/Hub, filter/slot/privacy UI, Global Command and provider owners, Hub, Messages, Phone, Contacts, Lockscreen, QS, Settings, SetupWizard, Mobile Manager, secure profiles, connectivity, Camera, Browser, Files, Mail/Calendar, Media, utilities and Tools. The portability/owner map documents the precise remaining work, and all 22 applicable row statuses currently remain `open` until qualified evidence is committed. Five original product owner decisions are unresolved.

The selected effective PhhIms/Iwlan source, actual G1/G2/G3 service/ABI/permissions, restricted SMS role, HOME/Quickstep role and selected APK hashes also remain **open**; no image/IMS/device/flash qualification is asserted.

**Full next build intentionally blocked before CI/Soong.** Source-only edits and targeted host policy tests are permitted in this dedicated branch; integrate the remaining implementation and evidence before another full `sable.sh` run.
