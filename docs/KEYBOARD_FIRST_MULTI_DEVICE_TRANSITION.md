# Keyboard-first multi-device transition

Status: **active architecture / execution plan**

Date: 2026-09-24

## 1. Frozen Panther reference

Pixel 7 / Panther R9 is the accepted touch-first reference. Active feature
development is on hold.

```text
qualified source  6f1d6d2f0f2525067874238c4b797ad58f2bcbc6
target-files SHA  08ef429c7f9eef17de7ddad4ce9baa81911950e8d34b6751b6e4588f66821502
physical status   PASS
future role       regression / maintenance / architecture reference
```

A later common feature may be regression-tested on Panther, but Panther is no
longer the default target that drives product design.

## 2. Active device order

```text
Titan 2        PORTABILITY / N0 keyboard-first active target
Titan 2 Elite  PORTABILITY candidate; independent physical proof required
Q27            RESEARCH / future product candidate
Panther        frozen reference
Bramble        historical reference
```

A PASS on one Titan-family device does not imply PASS on the other.

## 3. Build command contract

Keep the existing canonical operator interface:

```text
build/sable.sh <device> <release> <function> [options]
```

Do not add a physical serial to build identity. Builds are keyed by:

```text
device class + release + source + toolchain + product inputs
```

Device serial is mandatory only for device-contact functions:

```text
flash
accept
device-probe / capture operations
```

Examples:

```bash
bash build/sable.sh panther R9 show-artifact --build-source <sha>
bash build/sable.sh titan2 R10 ci full
bash build/sable.sh titan2 R10 build --tmux
bash build/sable.sh titan2 R10 flash --build-source <sha> --serial <serial> --preserve-data --authorize
bash build/sable.sh titan2 R10 accept --serial <serial> --suite keyboard
```

The existing aliases and device adapters are the correct architectural base.
Unqualified adapters remain present but fail closed.

## 4. Generalize artifacts before generalizing flashing

The current registry and flash pipeline are Panther target-files/A-B-fastboot
oriented. Multi-device support should separate common evidence from
device-specific deployment.

Common artifact descriptor:

```text
device
release
support_level
artifact_kind
source_commit
tool_source_commit
build_profile
image/member hashes
stock/vendor basis when applicable
required bootloader/vendor state
build evidence directory
```

Expected artifact kinds include:

```text
target-files
full-device-images
gsi-system-image
system/product bundle
device-specific recovery/boot bundle
```

The registry key remains device + release + source. It never uses the physical
serial.

## 5. Split common deployment policy from transport

Common layer owns:

- explicit authorization;
- selected-serial exact-once binding;
- artifact hash verification;
- evidence directory/seal;
- preservation/no-wipe policy;
- post-boot smoke contract;
- failure recovery rules.

Device adapter owns:

```text
expected ro.product.device
partition model
A/B / virtual-A/B / single-slot semantics
fastboot vs fastbootd vs vendor-specific transport
which images are writable
stock/vendor partitions that must be preserved
vbmeta/AVB requirements
restore path
boot timeout
post-flash device-specific acceptance
```

Do not enable Titan mutation by reusing Panther's A/B flashall assumptions.

## 6. Interaction architecture

Common semantics stay shared:

- Sable Launcher inventory/search/peek/app-context model;
- Sable Hub / Messages / People;
- Calculator, Games, Media, Reader, Text Reader, Mail, Weather, Calendar;
- Settings appearance and Network Manager semantics;
- privacy/security permission summaries;
- design tokens, typography, accent roles and system appearance;
- local CI, artifact provenance and acceptance evidence model.

Keyboard-first profile changes presentation and navigation, not application data
ownership.

Required keyboard-first primitives:

```text
visible deterministic focus
D-pad / arrow movement
Enter/Space activation
Back/Escape
printable-key type-to-search
stable focus restoration
shortcut/command palette
no focus traps
touch as secondary input
square/near-square responsive layout
hardware-key discoverability
```

## 7. System applications that should be baked into keyboard-first images

### Sable Camera

Camera should become a common Sable system application for keyboard devices.

Reuse the proven standard Camera2/vendor HAL path. Keep sensor capability, HAL
capability, app-visible capability and system privilege as separate facts.

Architecture should follow the Titan 2 research direction:

```text
camera-core/
camera-capabilities/
device-profiles/
ui/
platform-integration/
```

Titan 2 research has already proven ordinary-app rear/front capture, high
resolution JPEG and rear RAW/DNG. Hidden tele/logical camera work remains a
system-app integration question.

Grant `SYSTEM_CAMERA` only per device when physical evidence proves that it is
required and valuable.

### Sable Keyboard / input

Bake an offline-capable Sable keyboard/IME into keyboard-first system images so
text input remains available during setup, recovery-like workflows and without
network dependencies.

Keep two concerns separate:

```text
IME / text composition
    layouts, symbols, compose/dead keys, emoji, language input

physical-keyboard platform adapter
    keylayout/keycharacter maps, Fn/Sym behavior, shortcut mapping,
    keyboard backlight/vendor keys, pointer/trackpad behavior
```

Do not put device-specific scan-code quirks into the common IME.

## 8. Reuse from Panther vs change for keyboard devices

Reuse:

```text
Sable application set and package identities
SableLauncher semantic model
Quickstep/Recents where substrate supports it
Settings-hosted appearance authority
Network Manager model
SystemUI branding and Sable design roles
Hub/People/Messages data model
Reader/Text Reader/Media/Mail
artifact registry / CI / evidence discipline
Android security and vendor service boundaries
```

Change/adapt:

```text
launcher layout + focus/navigation
SystemUI geometry and focus
physical keyboard mapping/service
default IME and setup integration
camera application/system-camera policy
display/inset/cutout handling
device-specific boot/vendor/AVB integration
telephony/IMS acceptance
flash/restore strategy
secondary/rear display behavior where present
```

## 9. Pixel-family support

Do not fork the common product for each Pixel.

Each supported Pixel gets a bounded `device_sable_<codename>` adapter and
manifest/product binding. Prefer a rolling small set of currently maintainable
Pixels rather than promising every Pixel generation.

Qualification remains per-device for:

- boot/vendor/firmware identity;
- camera and telephony;
- power/thermal;
- display/input;
- target-files/images and flash;
- physical daily-driver/runtime evidence.

Panther stays useful as a frozen regression reference even after a newer Pixel
becomes PRIMARY.

## 10. Non-Pixel support model

Retain the existing assurance levels:

```text
N0_GSI_USERSPACE_LAB
N1_INTEGRATED_VENDOR_BSP_PORT
N2_PRODUCTION_QUALIFIED
```

Titan 2 and Titan 2 Elite start at N0. A booting GSI is not N1/N2.

N0 should preserve stock kernel/vendor/ODM/firmware and prove Sable userspace,
keyboard-first UX and app compatibility.

N1 adds owned device/product/VINTF/SELinux/vendor integration where feasible.

N2 additionally closes update/security lifecycle, AVB/signing/rollback,
recovery/restore, firmware provenance and production runtime acceptance.

## 11. Repository ownership

Recommended transition:

```text
aimindseye/sableos
    private integration + release orchestration + pre-publication work

sableos-project/*
    canonical public reusable source and architecture
```

Do not move the private monorepo wholesale.

Migrate a component only after:

1. source/upstream provenance is explicit;
2. license/notices permit publication;
3. secret/private-path/raw-evidence scan is clean;
4. no device serials or unreviewed vendor diagnostics are committed;
5. independent build/test instructions exist;
6. the destination repository has a clear ownership boundary;
7. the integration manifest pins the public source revision.

Long-term target: the private repo shrinks to release/integration metadata or is
archived once the complete product can be reconstructed from public repositories
plus explicitly private binary/evidence inputs.

## 12. Immediate implementation sequence

```text
K0 repository/status reconciliation
K1 artifact descriptor generalized beyond target-files
K2 flash driver split into common policy + device transport adapter
K3 Titan 2 read-only bring-up + stock restore contract
K4 keyboard-first SableLauncher profile
K5 Sable Keyboard / physical-keyboard adapter
K6 Sable Camera normal system-app baseline
K7 Titan 2 N0 image/build/flash qualification
K8 Titan 2 Elite independent K3-K7 sequence
K9 Q27 only after shipped-hardware acceptance
```
