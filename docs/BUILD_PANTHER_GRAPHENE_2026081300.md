# Building SableOS for Pixel 7 from GrapheneOS 2026081300

This is the currently validated development-build procedure for SableOS on Pixel 7 (`panther`). It reproduces the source model used for the D3 physical validation completed on 2026-09-07.

## Canonical source model

SableOS now uses the exact signed GrapheneOS `2026081300` Android 17 release as its Android/Pixel substrate, with a bounded Sable-specific delta applied on top:

```text
GrapheneOS 2026081300 exact source revisions
        +
Sable-specific audited source delta
        =
SableOS Panther Android 17 development build
```

This supersedes the earlier pure-AOSP Panther reconstruction workspace as the canonical build substrate. The old workspace remains historical forensic/reference evidence only.

The validated baseline is recorded in:

```text
patches/android-17-grapheneos-2026081300/BASELINE.lock
```

## Canonical R8 local build driver

For current R8 work on `ai-g732`, the normal local build entry point is no
longer a hand-written shell command sequence. GitHub Actions validates the
repository build contract and renders a source-bound
`sableos-panther-r8-build.sh` artifact.

The canonical host-tool root is:

```text
/srv/data/sable-host-tools
```

The tool versions and paths are defined by
`build/config/r8-host-tools.env`; the build/workspace layout and release label
are defined by `build/config/r8-release.env`.

Before the first build on an existing host, run the one-time migration:

```bash
HOST_TOOL_MIGRATION_AUTHORIZED=YES \
  bash build/host/migrate-r8-final-v1-host-tools.sh
```

Then verify:

```bash
bash build/host/verify-r8-host-tools.sh
```

After the corresponding GitHub workflow passes, use the uploaded driver artifact
for that exact commit. The driver defaults to tmux and runs the application
builds, Reader/Mail composition, exact APK freeze, R8 source/product
preparation, exact `vendor/sable` inventory validation, a focused
`m SableStart` Soong preflight, the combined application/Settings/SystemUI
module gate and the final Panther build. It never authorizes device contact or
flashing.

The historical D3 commands below remain substrate/reference evidence and are
still useful for forensic comparison, but they are not the normal R8 local
entry point.

## Host requirements

The validated Sable run used the GrapheneOS Android build system with Node.js 24 LTS for `adevtool` vendor extraction.

At minimum, install the normal GrapheneOS source/build tools for your host. On Debian/Ubuntu the GrapheneOS guide begins with:

```bash
sudo apt install repo yarnpkg zip rsync
```

Also install the normal Android/GrapheneOS host dependencies for the selected distro (`git`, `gnupg`, `openssh`, `diffutils`, `fontconfig`, fonts, `hostname`, `openssl`, `unzip`, and the required compiler/runtime support).

Validated vendor-tool Node version:

```text
v24.20.0
```

The project validation host used:

```text
/srv/data/sable-host-tools/node-v24.20.0-linux-x64/bin/node
```

A different Node 24 LTS point release should be treated as a new host-environment input and audited rather than assumed byte-reproducible.

## 1. Download the exact signed GrapheneOS release

```bash
mkdir -p /srv/data/sableos_panther_graphene_2026081300_workspace
cd /srv/data/sableos_panther_graphene_2026081300_workspace

repo init \
  -u https://github.com/GrapheneOS/platform_manifest.git \
  -b refs/tags/2026081300
```

Verify the signed GrapheneOS manifest tag using the GrapheneOS allowed-signers file:

```bash
mkdir -p ~/.ssh
curl https://grapheneos.org/allowed_signers > ~/.ssh/grapheneos_allowed_signers

cd .repo/manifests
git config gpg.ssh.allowedSignersFile ~/.ssh/grapheneos_allowed_signers
git verify-tag 2026081300
cd ../..
```

The signed tag resolves to:

```text
tag object: 5189230024ffe0048e0c351d5101c6b3f8b43eac
manifest commit: 84536744f0c06cccbcfa2110e9c937671ddc3278
```

Sync:

```bash
repo sync -j8
```

Seal the exact synced manifest:

```bash
repo manifest -r > /tmp/grapheneos-2026081300-pinned-manifest.xml
sha256sum /tmp/grapheneos-2026081300-pinned-manifest.xml
```

Validated project reference:

```text
c50f0096f538e604aa008e8ab4e3f1a3739f142c60c878a32f402c11eb406572
```

If the generated pinned manifest does not match, inspect the revision differences before continuing. Do not silently build a different source baseline and call it the validated D3 source.

## 2. Extract Pixel vendor files

GrapheneOS uses `adevtool` for Pixel vendor extraction. From the Android source root:

```bash
export PATH=/srv/data/sable-host-tools/node-v24.20.0-linux-x64/bin:$PATH
node --version
# expected on the validated host: v24.20.0

yarn --cwd vendor/adevtool/ install
adevtool generate-all -d panther
```

Proprietary Pixel vendor/firmware files are not redistributed by this SableOS repository. Use the vendor extraction procedure for the exact GrapheneOS release and device.

## 3. Prepare the exact Sable D2+D3 delta

Clone this SableOS repository separately. Before applying the delta, ensure these exact binary assets exist in:

```text
patches/android-17-grapheneos-2026081300/assets/
```

Required files:

```text
sableos_setupwizard_icon.png
sableos_boot_fallback_mask_448x605.png
```

Verify them before touching the Android source tree:

```bash
cd /path/to/sableos/patches/android-17-grapheneos-2026081300
sha256sum -c assets/SHA256SUMS
```

Expected hashes:

```text
eed1b1277a77fa1f94b514585622c403c85c95191cfa3ba90edf526d02e5aea7  sableos_setupwizard_icon.png
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e  sableos_boot_fallback_mask_448x605.png
```

Do not recompress or regenerate these while claiming the exact D3 reference identity. Any byte change is a new source input and requires a new artifact audit.

## 4. Apply and verify the Sable-specific source delta

```bash
cd /path/to/sableos

python3 patches/android-17-grapheneos-2026081300/apply_sable_branding.py --self-test

python3 patches/android-17-grapheneos-2026081300/apply_sable_branding.py \
  --source /srv/data/sableos_panther_graphene_2026081300_workspace apply

python3 patches/android-17-grapheneos-2026081300/apply_sable_branding.py \
  --source /srv/data/sableos_panther_graphene_2026081300_workspace verify
```

The applicator enforces the exact validated heads for `SetupWizard2`, `Settings`, and `frameworks/base`, the exact pre-change Graphene boot-logo mask, the unchanged shine asset, the exact final dirty scope and the exact Sable binary asset hashes.

Expected dirty scope:

```text
packages/apps/SetupWizard2:
 M res/layout/activity_finish.xml
 M res/layout/activity_welcome.xml
 M res/values/strings.xml
?? res/drawable-nodpi/sableos_icon.png

packages/apps/Settings:
 M res/values/strings_app_exploit_protection.xml
 M res/values/strings_ext.xml

frameworks/base:
 M core/res/assets/images/android-logo-mask.png
```

## 5. Build the validated development target-files package

The validated D3 build used `userdebug/test-keys`. It is a development artifact, not a production release-signing recipe.

```bash
cd /srv/data/sableos_panther_graphene_2026081300_workspace
source build/envsetup.sh

export OUT_DIR=out_graphene_control
export BUILD_DATETIME=1788580150
export BUILD_NUMBER=2026090500
export SOONG_NINJA=ninja
export SOONG_INCREMENTAL_ANALYSIS=false

lunch panther-cur-userdebug

m -j8 \
  vendorbootimage \
  vendorkernelbootimage \
  target-files-package \
  2>&1 | tee /tmp/sableos-panther-d3-build.log
```

The `vendorbootimage vendorkernelbootimage target-files-package` target set matches the validated Pixel 7 D3 build.

Exact validated target-files reference:

```text
out_graphene_control/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target-files.zip
SHA-256: 746fb6c6168d56b18285199649343210453301e32408e2bc456b86dbdd5f3fe8
```

Do **not** require this target-files SHA on a different host as a universal correctness condition. The project has proven semantically equivalent host/build-environment residuals such as filesystem metadata, BTF encoding and empty-data filesystem UUID nondeterminism. Treat the D3 SHA as the validated reference artifact, then audit deltas on a new host.

## 6. Mandatory build-log audit

A successful final `m` status is necessary but not sufficient. Audit the complete build log before artifact/deployment gates.

Capture candidate lines without blindly treating every textual warning as a correctness failure:

```bash
grep -Ein \
  'warning|warn:|error|fatal|failed to read|deprecated|undefined reference|neverallow' \
  /tmp/sableos-panther-d3-build.log \
  > /tmp/sableos-panther-d3-build-warning-candidates.txt || true
```

Classify each candidate into:

```text
BENIGN_INFO
KNOWN_ENVIRONMENT
ACTIONABLE_WARNING
BUILD_CORRECTNESS_RISK
```

The validated D3 run contained non-D3 API-37 compiler/R8/resource warning families and packaging probes. The contextual audit found zero D3-relevant warnings and zero unresolved build-correctness risks. Keep the evidence rather than suppressing those warnings.

## 7. Expected Sable source identity

The current Sable delta changes only these seven source files:

```text
packages/apps/SetupWizard2/res/values/strings.xml
packages/apps/SetupWizard2/res/layout/activity_welcome.xml
packages/apps/SetupWizard2/res/layout/activity_finish.xml
packages/apps/SetupWizard2/res/drawable-nodpi/sableos_icon.png
packages/apps/Settings/res/values/strings_app_exploit_protection.xml
packages/apps/Settings/res/values/strings_ext.xml
frameworks/base/core/res/assets/images/android-logo-mask.png
```

Important exact assets:

```text
SetupWizard Sable icon:
eed1b1277a77fa1f94b514585622c403c85c95191cfa3ba90edf526d02e5aea7

Sable boot fallback mask:
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e

unchanged android-logo-shine.png:
73c2cb640b053c29ec8be308892759a33cd6ed5aa85283cca2a456d208ccd4fb
```

The fallback boot-animation implementation is intentionally unchanged. There is no runtime `bootanimation.zip`; `BootAnimation.cpp` falls back to the framework assets. The Sable mask is opaque and therefore visually occludes the existing shine asset while retaining the upstream renderer.

## 8. Validated D3 image identities

Reference artifacts from the physically booted D3 build:

```text
system.img
19656bad995fbdcacdb8cf283396dc69d636072bd6a88e4fb38da99aff9934af

product.img
711727133467b3b9eacae142a1af04b99907cf7c18f11892b625e0619e714c1b

system_ext.img
f4e0098c5801b6715c754d76eea4daf06f23992321ea60955dd523ed3d8524fe

vbmeta.img
cc284d3841c243a91d6a43efcf6aea81dc0cfa95d4107426c9c4112d0808a789
```

Changing `framework-res.apk` also regenerates its fs-verity metadata, the fs-verity `BuildManifest.apk` / V4 signature, and a PRODUCT auto-generated framework characteristics RRO. Those downstream changes were proven and are recorded in `PANTHER_D3_VALIDATION.md`.

## R8 UI product-integration builds

The D3 procedure above remains historical/canonical substrate evidence. Current R8 UI work adds an additional pre-build requirement defined by `R8_PIXEL_UI_PRODUCT_CLOSURE.md` and `RELEASE_VALIDATION.md`.

For an R8 final UI build, do not infer product completeness from the output-directory name, an incremental module build, or successful `target-files-package`. Before the long build begins, prove the exact application/system source and package set in the generated product graph.

In particular, the R8 gate must prove SableStart, Sable Calculator, three separate Sable game APKs, Sable Media and Sable Reader are integrated, and must classify retained/replaced Android packages such as `ExactCalculator`.

The current development R8 target remains:

```text
lunch panther-cur-userdebug
```

A preview-named `OUT_DIR` is not itself a failure, but it must never be treated as evidence that all accepted UI work is integrated.

## 9. Deployment is a separate authorized operation

Do not treat the build procedure as authorization to flash a device. The validated D3 physical test needed `system_b`, `product_b`, and matching `vbmeta_b` together because D3 `vbmeta` binds the regenerated PRODUCT hashtree.

The final validated physical-gate script names and SHA-256 values are recorded in `PANTHER_D3_VALIDATION.md`. Device deployment remains a separately authorized operation and the state-bound deploy scripts must not be blindly reused against a different slot/partition state.

## References

- GrapheneOS build documentation: https://grapheneos.org/build
- GrapheneOS manifest repository: https://github.com/GrapheneOS/platform_manifest
- Canonical Sable delta: `patches/android-17-grapheneos-2026081300/`
- Changed-file inventory: `patches/android-17-grapheneos-2026081300/CHANGED_FILES.md`
- Binary-asset hashes: `patches/android-17-grapheneos-2026081300/assets/SHA256SUMS`
- D3 validation record: `docs/PANTHER_D3_VALIDATION.md`
