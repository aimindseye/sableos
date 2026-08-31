# S1.8 bramble Rust-UI qualification final evidence

Status: **CLOSED / HISTORICAL EVIDENCE**.

This record closes the Pixel 4a 5G (`bramble`) Android 14 Rust-UI framework qualification sequence. It is evidence for the platform transition to Pixel 7 (`panther`), not an instruction to continue dependency backports on Rust/Cargo 1.68.

Normative decisions:

- `adr/0002-rust-ui-framework-and-android-app-compatibility.md`;
- `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md`.

Transition record: `S1_8_PLATFORM_TRANSITION.md`.

## Frozen S1.7 guard

All F4 final guards passed with no Sable source mutation:

```text
main.rs      60e57eb9121ef88ffa1532c23eac6bf0fd5c1b2f6b3e60f4e35bef1f3c1b9155
power.rs     ab0fb13133f0c0773c19726c10fa5f95fd6105fd2eda4cf9215c948e30621543
power_ipc.rs 9bdf37270e4ff82b76c39aee0e7ba967ad1847ddd44af0b657f6872c219741ee
AIDL V1 .hash file SHA256
             0f88d12e0f72aa5bb7625f134ff7da2e86809b9b50e095e2ca38f2cb71f28650
```

No product image was built or flashed and no device state was changed by the framework probes.

## Platform toolchain

The bramble Android 14 tree uses:

```text
rustc 1.68.0-dev
cargo 1.68.0-dev
```

The qualification established that the limiting factor was the age of the selected Android/AOSP branch and its integrated compiler/dependency ecosystem, not Pixel 4a 5G's CPU architecture and not Rust's ability to target the device.

## Framework findings

### Vexo

Current Vexo was deferred from S1.8 on bramble because its dependency/toolchain floor is substantially newer than Rust 1.68 and its Android path still had important touch/accessibility/keyboard gaps at the pinned qualification point.

Vexo remains a long-term/fork/SableUI design reference.

### Slint 1.5

Slint 1.5 was the only credible near-term Android candidate close to the Android 14 platform compiler.

Captured facts:

```text
Slint 1.5.0
edition       2021
MSRV          1.70
Android       supported
```

The initial Rust-1.68 compatibility probe encountered a Cargo 1.68 workspace-feature behavior around `fontdb`, not a Rust-language incompatibility. Replacing inherited `default-features=true` behavior with explicit additive `fontdb` features restored the required filesystem/fontconfig APIs.

Result:

```text
S1_8F3_SLINT_CORE_RUST168=PASS
S1_8F3_FONTDB_DEFAULT_EQUIVALENT=PASS
```

Therefore Slint 1.5 core itself was proven able to compile under AOSP Rust 1.68 with bounded compatibility handling.

## F4 dependency-closure evidence

F4 then validated the next transitive compiler-side dependency edge.

Slint 1.5's compiler requests:

```text
codemap-diagnostic = { version = "0.1.1", optional = true }
```

Cargo had resolved `codemap-diagnostic 0.1.2`, whose MSRV is Rust 1.70. The temporary qualification lockfile was therefore pinned to the requested historical `0.1.1` release.

Observed result:

```text
S1_8F4_CODEMAP_PIN_OPERATION=PASS
S1_8F4_CODEMAP011_LOCK=PASS
S1_8F4_CORE_RUST168=PASS
```

The very next public-API build dependency blocker was:

```text
toml_edit 0.21.1 requires rustc 1.69 or newer
```

The public Slint API therefore did not complete on Rust 1.68, and the software-renderer Android and stock Android backend checks remained intentionally unexecuted because the prerequisite public crate had not closed.

This is the decisive F4 evidence. After two bounded compatibility repairs/pins, the next unrelated transitive dependency immediately imposed another newer compiler floor. Continuing would turn framework qualification into a sequence of dependency down-revs solely to satisfy a frozen end-of-life Android 14 platform.

## Final classification

```text
S1_8F3R1_F4_CAPTURE=PASS
S1_8F4_CORE_RUST168=PASS
S1_8F4_PUBLIC_RUST168=FAIL_CLASSIFY
S1_8F4_PUBLIC_BLOCKER=toml_edit_0.21.1_requires_rust_1.69
S1_8F4_ANDROID_SOFTWARE_RUST168=SKIPPED
S1_8F4_STOCK_ANDROID_RUST168=SKIPPED
S1_8F4_TMP_MUTATION_BOUNDED=PASS
S1_8F4_SABLE_SOURCE_MUTATED=NO
S1_8F4_BUILD_IMAGES_CREATED=NO
S1_8F4_FLASH_PERFORMED=NO
S1_8F4_TMUX_SAFE=YES
```

Project interpretation:

```text
BRAMBLE_UI_QUALIFICATION=CLOSED
BRAMBLE_S1_8_PRODUCTION_UI=NOT_LANDED
SLINT15_CORE_ON_AOSP168=PROVEN_WITH_BOUNDED_COMPATIBILITY
SLINT15_PUBLIC_ON_AOSP168=NOT_CLOSED
FURTHER_DEPENDENCY_DOWNREV_WORK=STOP
GLOBAL_AOSP_RUST_UPLIFT=NOT_APPROVED
VEXO_ON_BRAMBLE=DEFER
FRAMEWORK_SELECTION=REOPEN_ON_PANTHER
```

## Why the work stops here

The purpose of the bramble UI qualification was to determine whether Sable's product architecture should be constrained by the Android 14 integrated Rust toolchain. F4 answers that question: **no**.

The experiment proved both that useful modern Rust UI code can be close to compilable on Rust 1.68 and that public/runtime integration would accumulate increasingly artificial dependency pins. Maintaining those pins for an end-of-life device would make historical platform constraints choose the Sable UI framework.

That is explicitly rejected by ADR-0003.

## Next baseline

Pixel 7 (`panther`) is the active touch-first development reference.

Next gate: `PANTHER-P0`.

P0 must select the newest supported/reproducible Android baseline and inventory its exact platform Rust/Cargo/Clang/Soong, device/vendor/kernel and recovery boundaries before Sable source mutation.

S1.8 modern framework qualification then restarts on panther with:

- Slint;
- WaterUI;
- Project Robius + Makepad;
- Blinc;
- Vexo;
- Dioxus Native / Blitz where appropriate;
- `BUILD_SABLEUI` if no upstream path satisfies Sable requirements without disproportionate compromise.

The same semantic/UI core must remain suitable for the Metro-inspired touch-first Pixel profile and the BlackBerry/BB10-inspired Zinwa Q25/Q27 keyboard-first profile.

If the selected UI compiler differs from the Android platform Rust compiler, the boundary into Sable platform services must be stable C/NDK/AIDL rather than compiler-private cross-version Rust ABI.
