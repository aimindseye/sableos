# UI4 SystemUI refresh

Status: in implementation  
Base: GrapheneOS 2026081300 / Android 17  
Pinned `frameworks/base`: `aab06a8bd44c4c2b58eeec780fde83baa9d43a40`

## Goal

Apply the Sable UI/UX contract to the notification shade and Quick Settings without replacing Android SystemUI behavior.

UI4 is a bounded visual/product delta. The first tranche changes theme, spacing, shape and hierarchy only. It must preserve the upstream state models and interaction semantics for tiles, brightness, volume, notifications, privacy indicators, media sessions, accessibility and shade gestures.

## Product direction

The shade should follow the same Sable principles as Start and the first-party apps:

- content-first hierarchy;
- near-flat surfaces and restrained corner radii;
- Sable accent for active state rather than decoration;
- clear active/inactive Quick Settings state;
- strong typography and whitespace rather than heavy card chrome;
- consistent 48dp+ interactive targets;
- shared visual treatment across Quick Settings, notifications and media;
- no loss of privacy/security indicators or technical state.

The design remains Metro/Modern-UI influenced rather than a Windows clone.

## Initial source boundary

The exact upstream source/blob binding is recorded in:

```text
patches/android-17-grapheneos-2026081300/UI4_SYSTEMUI_BASELINE.json
```

The first implementation tranche is limited to the pinned Compose surfaces for:

- Quick Settings theme/context;
- Quick Settings content and overlay;
- compact Quick Settings grid composition;
- tile rendering, state-to-visual mapping and tile content geometry;
- footer actions;
- notification shade overlay/primitives;
- Quick Settings media geometry.

Any additional SystemUI source file must be added to the baseline ledger before mutation. UI4R0A extends that ledger to the exact compact-grid and tile-renderer sources reached by `TileGrid`, without authorizing behavioral changes.

## Non-goals for the first tranche

Do not change:

- tile availability or permission behavior;
- tile state repositories/view models;
- shade/scene gesture routing;
- notification ranking, dismissal or action behavior;
- privacy indicator logic;
- media session pipeline;
- brightness/volume semantics;
- notification listener/provider security;
- SystemUI package identity.

Behavioral changes require a later separately-qualified tranche.

## First tranche acceptance

```text
UI4_R0_PINNED_SYSTEMUI_SURFACES=PASS
UI4_R1_QS_THEME_GEOMETRY=PASS
UI4_R1_NOTIFICATION_SHADE_GEOMETRY=PASS
UI4_R1_MEDIA_PLACEMENT=PASS
UI4_R1_ACCESSIBILITY_SEMANTICS_PRESERVED=PASS
UI4_R1_BEHAVIORAL_DIFF=NONE
```

A source-level or standalone SystemUI build is not sufficient to call UI4 complete. Final acceptance requires Panther product build/integration and visual review on-device or emulator-equivalent product runtime.

## Rollout inside UI4

```text
UI4R0  source binding + mutation boundary
UI4R0A tile-renderer source binding required by UI4R1
UI4R1  Quick Settings theme / tile / slider / footer visual refresh
UI4R2  notification shade visual refresh
UI4R3  media control visual alignment
UI4R4  product build + runtime visual/accessibility review
```

The shared Sable design values remain the product authority, but SystemUI may use native SystemUI resources/tokens where directly importing the app Compose source would create an inappropriate dependency.
