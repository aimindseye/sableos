# Build Regression Policy

Every resolved build-process defect that can recur must become an executable
regression invariant. Conversation history and operator memory are supporting
context, not the enforcement mechanism.

The machine-readable registry is `build/BUILD_REGRESSIONS.tsv`. The executable
gate is `build/gates/build-regression-contract.py`.

## Required workflow

When a build failure is diagnosed and fixed:

1. identify the violated invariant, not only the immediate error message;
2. make the smallest source/process correction;
3. add or update one regression-ledger row;
4. add an executable assertion to the shared regression gate;
5. make the assertion fail against the old broken shape and pass against the
   corrected shape;
6. keep the gate wired into canonical local CI;
7. for supported Titan 2 builds, run the same gate before the release-specific
   build driver;
8. do not replace the invariant with comments or a release-specific wrapper.

A later release may supersede an invariant only by changing the ledger and the
gate together, with evidence explaining why the old invariant is no longer
valid.

## In-flight build transition rule

A regression fix or policy improvement committed after a build has already
started does **not** justify interrupting that running build.

The running build remains bound to its exact starting source commit and should
be allowed to finish unless it independently violates an existing safety
boundary. Its result qualifies only that source commit.

The newly added regression invariant applies to the next build and later
builds. Before the next build:

1. fetch the new source head;
2. run canonical CI against that exact head;
3. require the shared regression contract to pass;
4. invoke the canonical build entrypoint;
5. let the device adapter rerun the regression preflight immediately before
   the release-specific build implementation.

Do not mutate the active Android workspace merely to retrofit a new regression
check into a build that is already executing.

## Active Titan shell policy

For active Titan 2 build drivers and new Titan build helpers, do not use
`set -e`, `set -o errexit`, `set -o pipefail`, or the combined
`set -euo pipefail` pattern.

Use explicit return-code checks at the operation that matters. When output must
also be streamed to a log, prefer process substitution, for example:

```bash
make systemimage -j"$JOBS" > >(tee "$EVIDENCE/systemimage.log") 2>&1
build_rc=$?
[[ "$build_rc" -eq 0 ]] || fail "systemimage_rc=$build_rc"
```

`set -u` may be used to catch missing contract inputs, but AOSP
`envsetup.sh` / `lunch` sections may temporarily disable nounset when
required.

Historical sealed scripts are not mass-rewritten solely for style. The rule
applies to the active Titan build path and future Titan build drivers.

Tmux-launched Titan builds must set `remain-on-exit on`. A completed or failed
build session should remain attachable for inspection instead of disappearing
when the pane process exits.

## Current protected failures

The initial ledger captures regressions already encountered in the SableOS
engineering lane, including:

- local-CI stage log scans accidentally reporting success because `!` inverted
  the return code before it was captured;
- Gitleaks scanning unrelated local refs instead of only the qualified source
  commit;
- Titan 2 Android-16 authority drifting toward Android 17;
- caller scripts pre-creating output directories owned by delegated builders;
- Android workspace staging beginning before a cleanup trap was active;
- assuming SELinux property-context rows map one-to-one to property types;
- promoting the broad N1I-A A4 native audit superset into product prebuilts,
  causing duplicate Kati install targets and violating N1I-B2 import authority;
- hard-coding system_ext output paths instead of using
  `TARGET_COPY_OUT_SYSTEM_EXT`;
- reintroducing broad compatibility bypasses, device-write paths, or a
  registration/data delta into the cellular-isolation build;
- replacing canonical shared AOSP host tools with per-build discovery.
- piping verbose APK inspection commands directly into early-closing match
  pipelines. APK identity checks capture complete tool output before matching,
  and staged identity is checked before the expensive Android build;
- relying on shell-wide errexit/pipefail behavior instead of explicit return
  codes in the active Titan build path;
- losing the tmux session as soon as a build process exits, preventing
  post-failure/post-success inspection.
- allowing configured boot-jar module names to diverge from installed JAR stems
  without `PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES`, which can produce
  classpath metadata pointing at non-existent on-device filenames.
- allowing a release-specific Titan build path to bypass the shared build
  regression contract merely because a release-local contract or the central
  flash guard passed. Active release drivers must run the shared regression
  contract before source staging/mutation or build work;
- treating a collision-free module name as sufficient native admission. Native
  prebuilts must be checked against install destinations, not just module names.
  The N1I-C2 failure on `/system/lib64/android.hardware.drm-V1-ndk.so` proved
  that a unique Sable module can still collide with a platform-owned final path.
  Before the next C2 build, every frozen native target is compared against the
  exact sealed C1 image: byte-identical C1 targets are reused and therefore not
  listed in C2 `PRODUCT_PACKAGES`; C1-absent targets alone are installed from
  the frozen stock bundle; C1-present-but-different targets fail closed before
  Kati. The Kati install-graph audit remains a second-line verifier and is also
  captured automatically after a failed build when an install graph exists.

## Post-build reuse rule

When a long Android build completes successfully but a later read-only verifier
fails, do not rebuild by default. First determine whether the failure is in the
artifact or in the verifier.

If the build output is intact and the failure is verifier-only, use a checked-in
read-only post-build qualifier that binds explicitly to the original build
source commit and OUT directory. The qualifier may inspect and seal artifacts,
but it must not compile, mutate Android source, contact a device, or flash.

For N1I-C1 the canonical qualifier is:

```text
build/titan2/qualify-n1i-c1-postbuild.sh
```

## Scope

The ledger is intentionally small and evidence-driven. It is not a list of
every historical incident. Add an entry when the failure has a concrete,
repeatable invariant that future builds can check automatically.
