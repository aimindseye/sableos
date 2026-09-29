# N1B2 app profile binding

Titan2/N1B2 app and APK work must be bound to `platform_sable` before it is
treated as valid for product composition or image work.

This file intentionally does not authorize an image build, public artifact,
device contact, flash, adb, fastboot, or production signing.

## Source of truth

The required source of truth is:

- `platform_sable/docs/`
- `platform_sable/docs/device-capabilities/`
- `platform_sable/docs/design/`
- `platform_sable/docs/design/artifacts/`

Titan2 app profiles must follow the Titan2 capability profile, the platform
design documents, and approved Titan2 visual artifacts.

## Machine-readable manifest

The machine-readable manifest is `docs/titan2/N1B2_APP_PROFILE_BINDING.tsv`.

Each row binds one surface to:

- `surface`
- `capability_doc`
- `design_doc`
- `visual_confirmation_doc`
- `approved_artifact`

The binding is valid only when all referenced files exist in the checked-out
`platform_sable` repository.

## Policy

For N1B2, an app or system surface is not ready for APK or product-profile work
unless it has:

- `PLATFORM_SABLE_DOCS_BOUND=YES`
- `DEVICE_CAPABILITY_PROFILE_BOUND=YES`
- `DESIGN_UX_DOC_BOUND=YES`
- `VISUAL_CONFIRMATION_BOUND=YES`
- `APPROVED_ARTIFACT_BOUND=YES`
- `PANTHER_NO_REGRESSION=YES`
- `APK_BUILT=YES`
- `IMAGE_BUILD_AUTHORIZED=NO`

## Panther protection

Titan2 keyboard-first UX must be profile-driven. Common app source must not fork
by device model. Panther remains the touch-first reference path.

## Image build posture

This binding gate is pre-image work. It exists to prevent generic or placeholder
Titan2 apps from entering N1B2 composition without `platform_sable`
traceability.
