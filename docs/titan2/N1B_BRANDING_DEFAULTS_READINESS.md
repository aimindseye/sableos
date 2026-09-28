# N1B branding and default-surface readiness

Status: **N1B Phase 04 static readiness gate / no runtime claim**

This document defines the static boundary before N1B branding/default-surface
integration is allowed to move toward physical UX acceptance.

```text
N1B_BRANDING_DEFAULTS_READINESS=YES
N1B_PHASE=04
N1B_PHASE_NAME=BRANDING_AND_DEFAULT_SURFACE_INTEGRATION
SOURCE_MUTATION_AUTHORIZED=NO for gate execution
BUILD_AUTHORIZED=NO
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

## Required defaults posture

```text
SABLE_BRANDING_INTEGRATION_REQUIRED=YES
SABLE_DEFAULT_SURFACE_INTEGRATION_REQUIRED=YES
PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES
TITAN2_KEYBOARD_FIRST_PROFILE_GATED=YES
COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES
```

## Required user-facing checks before physical UX

```text
SABLE_APP_LABELS_REVIEW_REQUIRED=YES
SABLE_ICONS_REVIEW_REQUIRED=YES
SABLE_THEME_PROPAGATION_REVIEW_REQUIRED=YES
SABLE_BROWSER_LABEL_POLICY_REVIEW_REQUIRED=YES
SABLE_HUB_DEFAULT_SURFACE_REVIEW_REQUIRED=YES
```

## Explicit non-goals

This phase does not contact hardware and does not claim runtime correctness.

```text
RUNTIME_LABEL_VALIDATION=NO
PHYSICAL_UX_ACCEPTANCE=NO
IMAGE_BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

## Promotion rule

Phase 04 can pass only as a readiness/static gate. N1B still requires Phase 05
keyboard-first setup and launcher binding, Phase 06 physical UX acceptance, and
Phase 07 full CI before any image build candidate.

```text
N1B_PHASE_04_PROMOTES_TO_PHASE_05_ONLY=YES
N1B_PHASE_04_DOES_NOT_AUTHORIZE_IMAGE_BUILD=YES
N1B_PHASE_04_DOES_NOT_AUTHORIZE_FLASH=YES
```
