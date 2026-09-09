# Sable M1-R1 — static toolchain and renderer preflight

Status: **ready to run / read-only**.

Date: 2026-09-09

M1-R1 is the next gate after `SABLE_M1_R0=PASS_CLOSED`. It binds the actual
Panther Android 17 host/source toolchain before any Sable Start production
source, renderer import, Soong build, Cargo build, or device operation.

## Scope

This gate is intentionally static and read-only.

```text
SOURCE_MUTATION_AUTHORIZED=NO
WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
BUILD_TOOL_EXECUTION=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

The preflight does not execute `rustc`, `cargo`, `clang`, `soong_ui`, `ninja`,
Java, Gradle, or any renderer build. It does not import source and does not
perform network access. It inspects paths, symlink targets, executable bits,
file identities, source availability, and Android platform interface anchors.

## Canonical workspace

```text
/srv/data/sableos_panther_graphene_2026081300_workspace
```

The workspace must be an absolute, canonical, non-symlink directory and must
contain `.repo/manifest.xml`.

## Prior M1 binding

The contract binds:

```text
product/m1/sable-start-engineering-contract-v1.json
git_blob=ad751087dd5150a5d93aebb6ab460542e7cf7b4a

docs/SABLE_M1_R0_ENGINEERING_GATE_20260909.md
git_blob=9912834c690cbed1bce23cc0362b179ef98a032c
```

M1-R1 fails closed if either prior artifact differs.

## Toolchain inventory

Required static bindings:

```text
prebuilts/rust/linux-x86/current/bin/rustc
prebuilts/rust/linux-x86/current/bin/cargo
prebuilts/rust/linux-x86/current/bin/rustfmt
prebuilts/rust/linux-x86/current/bin/clippy-driver

prebuilts/clang/host/linux-x86/clang-stable/bin/clang
prebuilts/clang/host/linux-x86/clang-stable/bin/clang++

build/soong/soong_ui.bash
prebuilts/jdk/jdk21/linux-x86/bin/java
prebuilts/build-tools/linux-x86/bin/ninja
```

Each required executable is resolved without leaving the workspace, checked as
a regular executable file, and SHA-256 sealed. Rust and Clang version hints are
derived from their resolved prebuilt directory names without executing them.

## Android UI integration anchors

The static gate requires Android platform surfaces for:

- `ANativeWindow`;
- `android.view.Surface`;
- `android.view.Window`;
- accessibility;
- IME.

These are substrate-presence checks only. Passing them does not prove a renderer
has correct lifecycle, accessibility, IME, or frame behavior.

## Renderer candidates

The contract inventories local source for:

```text
Slint
Makepad
Dioxus Native / Blitz
Sable-owned renderer
```

No renderer is selected at M1-R1.

Candidate classification is limited to:

```text
LOCAL_SOURCE_PRESENT_REQUIRES_BUILD_QUALIFICATION
LOCAL_SOURCE_NOT_PRESENT_IMPORT_REVIEW_REQUIRED
DESIGN_OPTION_ONLY_NO_PRECOMMITTED_SOURCE
BLOCKED_LOCAL_SOURCE_PATH_ERROR
```

Absence of third-party renderer source is expected and non-blocking. M1-R1 must
never fetch dependencies or convert absence into an implicit dependency choice.

## Required next-phase evidence

A candidate can only be selected after a separately authorized build/runtime
qualification proves:

```text
OFFLINE_REPRODUCIBLE_BUILD
ANDROID_ACTIVITY_WINDOW_SURFACE_LIFECYCLE
TOUCH_SCROLL_FRAME_TIMING
TEXT_SHAPING_HINDI_RTL
ACCESSIBILITY_BRIDGE
IME_CLIPBOARD
DEPENDENCY_LICENSE_INVENTORY
BINARY_SIZE_RSS_IDLE_CPU
STARTUP_LATENCY
PRIVILEGE_DELTA_NONE
```

## Validation of this deliverable

```text
PY_COMPILE=PASS_2_OF_2
UNIT_ADVERSARIAL_TESTS=PASS_29_OF_29
RUNNER_BASH_N=PASS
NO_SUBPROCESS_IMPORT=PASS
NO_NETWORK_MODULES=PASS
NO_PROCESS_EXECUTION_CALLS=PASS
SYNTHETIC_SUCCESS_PATH=PASS_RC0
SYNTHETIC_MISSING_TOOL_PATH=PASS_CONTROLLED_RC3
```

The tests cover contract tampering, authorization inversion, prior-artifact
identity mismatch, workspace binding, symlink escape, missing/non-executable
tools, platform-interface absence, renderer source presence/absence, renderer
symlink escape, evidence-path restrictions, exclusive evidence creation, and
static no-network/no-process-execution properties.

## Artifacts

```text
product/m1/sable-m1-r1-toolchain-contract-v1.json
  sha256=0e447be147989eadc9d1257800e9f06cec2a93f61c8c7f65d8ffff574d66f1eb

tools/validation/product-m1/SABLE_M1_R1_TOOLCHAIN_PREFLIGHT.py
  sha256=bdc00d0d18bc6ad9ecfcb6b7f94d3ece564f462e47d0a2ec65305213ed4426fb

tools/validation/product-m1/test_sable_m1_r1_toolchain_preflight.py
  sha256=817a1b11622ba5d049d440204db7db0c28df6e013f8a855571e1e8f473b5cbf5

tools/validation/product-m1/run_SABLE_M1_R1_TOOLCHAIN_PREFLIGHT.sh
  sha256=0bc5a248aabe5a6b8e2b0f1cfc1238d7c623e1f976138a04332e99dfae55a466
```

Git blob identities of the exact reviewed payloads:

```text
product/m1/sable-m1-r1-toolchain-contract-v1.json
  git_blob=805d37edb4de15daccef8d8d456b837a0dd2c9bd

tools/validation/product-m1/SABLE_M1_R1_TOOLCHAIN_PREFLIGHT.py
  git_blob=4271c3c7b44ed4afa0f55d88fadeb59ced160bba

tools/validation/product-m1/test_sable_m1_r1_toolchain_preflight.py
  git_blob=c1e5a7a1d3d5d78ee1e443f718fa3185d5765669

tools/validation/product-m1/run_SABLE_M1_R1_TOOLCHAIN_PREFLIGHT.sh
  git_blob=fd9255e814e3182cfad94f83f83daf71617efea1
```

## Execution

From the tools checkout:

```bash
chmod 0755 tools/validation/product-m1/run_SABLE_M1_R1_TOOLCHAIN_PREFLIGHT.sh
tools/validation/product-m1/run_SABLE_M1_R1_TOOLCHAIN_PREFLIGHT.sh
```

Expected success disposition:

```text
SABLE_M1_R1_STATIC_TOOLCHAIN_PREFLIGHT=PASS
RENDERER_SELECTED=NONE
BUILD_TOOL_EXECUTION_ACTIONS=NONE
M1_R1_READINESS=READY_FOR_RENDERER_IMPORT_AND_BUILD_QUALIFICATION_PLAN
SABLE_M1_R1_RC=0
```

RC3 means a bounded static blocker. RC4 means validator/input error. Neither
permits source import, build execution, or device contact.
