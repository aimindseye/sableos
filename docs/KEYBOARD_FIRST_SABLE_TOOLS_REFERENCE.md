# Keyboard-first Sable Tools reference

Status: **accepted keyboard-device product/reference direction; not part of the Panther R8 build blocker**

Date: 2026-09-19

This document defines a common Sable Tools direction for physical-keyboard devices, initially Titan 2 and later Zinwa Q27.

The product goal is inspired by the utility/power-user culture of BlackBerry/BB10 devices while remaining native to Android/SableOS security, service ownership and permission boundaries.

## Reference repository

Reviewed reference:

~~~text
repository: bb10root/bb10tools
revision: 68d2e42a471b46b53ff5567edac4293ef0f3d5d6
license: GPL-3.0
role: BB10/QNX engineering and device-tooling reference
~~~

The repository describes itself only as "Various small tools for BB10", but its tree contains a broad set of engineering utilities and experiments, including:

- launcher patching;
- autorun/launch support;
- NVRAM record access, backup and mutation;
- QNX procnto/kernel patch work;
- radio/PPS data parsing;
- MMC/storage and low-level device helpers;
- signature-generation tooling;
- file-transfer client/server experiments;
- memory read/write and dump scanning;
- ELF/signature indexing and extraction;
- root-certificate/SCEP experiments;
- security/path-trust/insecure-state experiments.

This makes it valuable primarily as a **capability/reference inventory**, not as code to copy wholesale.

Because bb10tools is GPL-3.0, SableOS treats its implementation as behavioral/architectural reference by default unless a separate licensing review approves direct reuse.

## Sable product interpretation

The useful BB10 lesson is not "ship root exploits".

The useful lesson is:

> A keyboard-first device benefits from a compact, fast, discoverable toolbox for understanding and controlling the device without requiring a desktop for every routine diagnostic.

For SableOS, this becomes:

~~~text
Sable Tools
  -> normal user/device utilities
  -> keyboard-first interaction
  -> explicit read-only diagnostics
  -> bounded user-authorized maintenance actions

Developer / Service tools
  -> deeper platform evidence
  -> explicitly enabled
  -> read-only by default
  -> privileged action only through existing owning Android/Sable services
~~~

The toolbox is common application/product semantics. Titan 2 and Q27 may add hardware adapters, but should not fork the common tools application.

## Proposed Sable Tools sections

### DEVICE

Show:

- device/product/build identity;
- Android/Sable build fingerprint;
- security patch level;
- boot slot;
- verified-boot/lock state;
- uptime;
- architecture/page size;
- kernel identity;
- display geometry/density;
- device-support/assurance class.

Normal users should be able to copy/export this report.

### KEYBOARD

Keyboard-first devices should expose first-class input diagnostics:

- physical input-device inventory;
- effective Android keylayout/key character map;
- keycode/scancode viewer;
- Shift/Ctrl/Alt/SYM meta-state viewer;
- repeat/long-press timing;
- shortcut viewer;
- layout/language mapping;
- key test surface;
- pointer/touch-surface state where present.

Future user-facing remapping must map hardware to stable semantic actions and remain behind reviewed policy. Do not implement runtime root/bind-mount keylayout replacement as the normal Sable architecture.

### RADIO / CONNECTIVITY

Read-only status and export:

- SIM/eSIM presence where Android permits;
- carrier/network registration;
- mobile generation/state;
- IMS registration capability/state;
- Wi-Fi identity/state;
- Bluetooth state;
- VPN state;
- IP/DNS/default route summaries;
- signal information exposed by supported Android APIs.

The bb10tools radio/PPS parsing work is a conceptual reference for structured radio-state inventory. SableOS should consume supported Android/vendor interfaces rather than parse unrelated BB10 formats.

### STORAGE

User-safe information:

- filesystem/storage capacity;
- user-data usage;
- removable/user-selected storage where supported;
- app/media/document categories where Android exposes them;
- partition/slot summary in Developer mode;
- storage-health information only where a supported API exists.

Low-level raw MMC writes are not a normal Sable Tools feature.

### APPS / PROCESSES

Integrate with the existing Sable Application Security & Privacy direction:

- installed package inventory;
- user/system classification;
- version/signing/install-source;
- permissions/AppOps summary;
- exported components;
- native-library/ABI inventory;
- running-process/service information where platform access permits;
- direct route to App Security & Privacy and Android controls.

Do not introduce a second competing app-security model.

### LOGS / REPORT

One keyboard-accessible report/export flow:

- Sable build/device report;
- selected Android diagnostic state;
- input/keyboard report;
- network/radio report;
- application inventory;
- recent user-authorized log capture;
- optional bugreport handoff where supported.

Reports should be explicit about potentially sensitive content and require user intent before sharing.

### FILE TRANSFER

bb10tools contains a simple custom TCP file-transfer experiment. Sable should take the usability lesson, not the protocol.

Preferred Sable behavior:

- Android Sharesheet;
- USB/MTP where appropriate;
- user-selected document providers;
- Nearby/standard Android transfer mechanisms when available;
- explicit authenticated local transfer only if Sable later has a justified product requirement.

Do not ship an unauthenticated always-on custom file server.

### RECOVERY / MAINTENANCE

Safe, bounded actions may include:

- reboot to Android-defined targets only when the platform/user policy allows it;
- open system update/recovery settings;
- export diagnostic/recovery information;
- validate current slot/build identity;
- show rollback/recovery instructions.

Destructive actions must remain separately authorized and owned by the proper Android/Sable service. Sable Tools must not become a generic raw-flash/NVRAM/memory-write frontend.

## Explicit non-goals

The following bb10tools-style mechanisms are reference-only and are **not** normal SableOS product features:

~~~text
arbitrary physical/kernel memory read/write
runtime kernel/process patching
security/trust bypass
set-insecure operations
arbitrary NVRAM deletion/write
boot/security downgrade bypass
certificate-chain forgery
path-trust unlocking
raw storage/MMC mutation
unauthenticated remote command/file servers
exploit persistence/autorun
~~~

If a future engineering lab needs a low-level research utility, it must be separately scoped, source-reviewed, development-only, and excluded from production images by default.

## Keyboard-first UX

Sable Tools itself is keyboard-first on Titan 2 and Q27.

Required baseline:

- printable-key search/filter from the top-level tools list;
- deterministic visible focus;
- Up/Down/Left/Right navigation;
- Enter activation;
- Back/Escape return;
- Tab/Shift+Tab traversal where appropriate;
- copy/export shortcuts;
- no touch required for core diagnostics;
- touch remains a secondary path;
- dense information views remain readable and accessible;
- command/search names are semantic and stable across hardware.

The same semantic tool can present a touch-first layout if Sable Tools is later shipped on Panther, but Panther does not require this app for the current R8 final-build gate.

## Titan 2 role

Titan 2 N0 work should use Sable Tools development to turn repeated manual qualification commands into reusable product/engineering surfaces.

Initial Titan value:

- keyboard event inspector;
- keymap/KCM/keyboard-state report;
- display/input geometry;
- VINTF/vendor/device summary;
- radio/IMS acceptance state;
- partition/slot/build identity;
- exportable diagnostics.

T0 read-only shell evidence remains authoritative before those tools themselves are trusted.

## Zinwa Q27 role

Q27 should consume the same Sable Tools app and semantic contracts if/when the device reaches active qualification.

Q27-specific work belongs in adapters for:

- keyboard hardware/keymap;
- programmable/special keys;
- pointer/touch surface;
- display geometry;
- radio/vendor capability;
- firmware/partition differences.

Do not create a separate Q27 toolbox app simply because the hardware differs.

## Relationship to Sable Settings

Sable Tools and Settings should not duplicate ownership.

~~~text
Settings
  -> normal configuration and policy

Application Security & Privacy
  -> application-specific security evidence and Android control routes

Sable Tools
  -> device diagnostics, keyboard/device inspection, reports, bounded utilities
~~~

A Tools row may deep-link into Settings/App Security where that surface owns the action.

## Privilege model

Default posture:

~~~text
READ_ONLY_BY_DEFAULT=YES
NO_NEW_SHARED_UID=YES
NO_AMBIENT_ROOT_DAEMON=YES
NO_ACCESSIBILITY_AUTOMATION_FOR_PLATFORM_OWNED_ACTIONS=YES
NO_RAW_DEVICE_NODE_ACCESS_FROM_UI=YES
~~~

When a privileged operation is justified, the UI requests a narrow operation from the existing owning Android/Sable service. The Tools app should not accumulate broad hardware authority merely for convenience.

## Acceptance markers

Common:

~~~text
SABLE_TOOLS_COMMON_ARCHITECTURE=PASS
SABLE_TOOLS_READ_ONLY_DEFAULT=PASS
SABLE_TOOLS_SECURITY_BOUNDARY=PASS
SABLE_TOOLS_REPORT_EXPORT=PASS
~~~

Titan 2:

~~~text
TITAN2_SABLE_TOOLS_KEYBOARD_UI=PASS
TITAN2_SABLE_TOOLS_INPUT_DIAGNOSTICS=PASS
TITAN2_SABLE_TOOLS_DEVICE_REPORT=PASS
~~~

Q27, when hardware is active:

~~~text
Q27_SABLE_TOOLS_KEYBOARD_UI=PASS
Q27_SABLE_TOOLS_INPUT_DIAGNOSTICS=PASS
Q27_SABLE_TOOLS_DEVICE_REPORT=PASS
~~~

These markers do not imply N2 production support by themselves.
