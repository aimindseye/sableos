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

## Host requirements

GrapheneOS documents Ubuntu 24.04 LTS, Ubuntu 24.10, Debian bookworm and Arch Linux as supported build hosts. The validated Sable run used the GrapheneOS Android build system with Node.js 24 LTS for `adevtool` vendor extraction.

At minimum, install the normal GrapheneOS source/build tools for your host. On Debian/Ubuntu the GrapheneOS guide begins with:

```bash
sudo apt install repo yarnpkg zip rsync
```

Also ensure the Android build dependencies listed by GrapheneOS are installed (`git`, `gnupg`, `openssh`, `diffutils`, `fontconfig`, a font package, `hostname`, `openssl`, `unzip`, and the normal compiler/runtime host support).

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

## 3. Apply the Sable-specific source delta

Clone this SableOS repository separately, then apply the bounded D2+D3 source delta:

```bash
cd /path/to/sableos

python3 patches/android-17-grapheneos-2026081300/apply_sable_branding.py --self-test

python3 patches/android-17-grapheneos-2026081300/apply_sable_branding.py \
  --source /srv/data/sableos_panther_graphene_2026081300_workspace apply

python3 patches/android-17-grapheneos-2026081300/apply_sable_branding.py \
  --source /srv/data/sableos_panther_graphene_2026081300_workspace verify
```

The applicator enforces the exact validated heads for `SetupWizard2`, `Settings`, and `frameworks/base`, exact pre-change boot-logo assets, exact final dirty scope and exact Sable binary asset hashes.

## 4. Build the validated development target-files package

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

The `vendorbootimage vendorkernelbootimage target-files-package` target set matches the GrapheneOS Pixel 7 build requirement and the validated Sable run.

The exact validated target-files reference was:

```text
out_graphene_control/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target-files.zip
SHA-256: 746fb6c6168d56b18285199649343210453301e32408e2bc456b86dbdd5f3fe8
```

Do **not** require this target-files SHA on a different host as a universal correctness condition. The project has proven semantically equivalent host/build-environment residuals such as filesystem metadata, BTF encoding and empty-data filesystem UUID nondeterminism. Treat the D3 SHA as the validated reference artifact, then audit deltas on a new host.

## 5. Mandatory build-log audit

A successful final `m` status is necessary but not sufficient. Audit the complete build log before artifact/deployment gates.

Capture candidate lines without blindly treating every textual `warning` or `Failed to read` as a correctness failure:

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

## 6. Expected Sable source identity

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

## 7. Validated D3 image identities

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

## 8. Deployment is a separate authorized operation

Do not treat the build procedure as authorization to flash a device. The validated D3 physical test needed `system_b`, `product_b`, and matching `vbmeta_b` together because D3 `vbmeta` binds the regenerated PRODUCT hashtree.

The final validated physical-gate script names and SHA-256 values are recorded in `PANTHER_D3_VALIDATION.md`. Device deployment remains a separately authorized operation and the state-bound deploy scripts must not be blindly reused against a different slot/partition state.

## References

- GrapheneOS build documentation: https://grapheneos.org/build
- GrapheneOS manifest repository: https://github.com/GrapheneOS/platform_manifest
- Canonical Sable delta: `patches/android-17-grapheneos-2026081300/`
- D3 validation record: `docs/PANTHER_D3_VALIDATION.md`
