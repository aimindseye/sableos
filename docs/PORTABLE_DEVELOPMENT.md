# Portable SableOS development

This repository is intended to be sufficient for Sable-owned source, tests and
build orchestration. It intentionally does not redistribute GrapheneOS/AOSP or
Pixel proprietary vendor files.

## New machine

Choose a durable root. The default is:

```bash
export SABLEOS_ROOT=/srv/data/sableos
mkdir -p "$SABLEOS_ROOT"
git clone https://github.com/aimindseye/sableos.git "$SABLEOS_ROOT/repo"
cd "$SABLEOS_ROOT/repo"
```

Bootstrap the exact upstream release:

```bash
NETWORK_FETCH_AUTHORIZED=YES \
  ./build/panther/bootstrap.sh
```

Follow `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` to verify the GrapheneOS signed
tag and provision Pixel vendor files with `adevtool`.

Once the canonical SableStart snapshot is complete:

```bash
SOURCE_MUTATION_AUTHORIZED=YES \
  ./build/panther/sync-sablestart.sh
```

Run no-build tests:

```bash
./build/gates/sablestart-r3-prebuild.sh

WS="$SABLEOS_UPSTREAM" \
  ./tests/sablestart/host/run_unit_tests.sh
```

Build only SableStart:

```bash
BUILD_AUTHORIZED=YES \
  ./build/panther/build-sablestart.sh
```

Build the Panther target-files set when authorized:

```bash
BUILD_AUTHORIZED=YES \
  ./build/panther/build-target-files.sh
```

## Current portability gap

The 2026-09-11 R3 review extract contained exact full text for the files already
committed under `src/android/packages/apps/SableStart`, but only hashes for these
four unchanged baseline files:

```text
res/values/strings.xml
src/com/sable/start/SableStartActivity.kt
src/com/sable/start/bridge/SableStartNative.kt
src/com/sable/start/model/AppEntry.kt
```

Therefore `sync-sablestart.sh` deliberately refuses to claim a complete portable
snapshot until those exact four files are captured from the validated workspace
and committed.

On the validated machine:

```bash
APP_DIR=/srv/data/sableos_panther_graphene_2026081300_workspace/packages/apps/SableStart \
DEST=/path/to/sableos/src/android/packages/apps/SableStart \
  ./build/panther/capture-sablestart.sh
```

Review the resulting diff and hashes, then commit the four missing files to main.
After that closure, a fresh machine can reproduce the complete SableStart module
from this repository plus the exact upstream GrapheneOS/vendor inputs.
