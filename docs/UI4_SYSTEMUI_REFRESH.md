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


## UI4R1 implementation

UI4R1 is represented by the fail-closed applicator:

```text
patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py
```

It is bound to the exact five UI4R1 mutation files already present in
`UI4_SYSTEMUI_BASELINE.json`. The applicator refuses an unexpected
`frameworks/base` HEAD, unexpected source blobs, replacement cardinality,
or dirty source scope.

The visual delta is intentionally small:

- active Quick Settings tiles use the semantic primary-container surface rather
  than a fully saturated primary fill;
- active dual-target tiles use the same active surface while retaining a
  stronger primary toggle target;
- active and inactive tile surfaces use a common 6dp corner radius, with 4dp
  icon/toggle corners;
- compact Quick Settings grid spacing is 8dp;
- expanded Quick Settings content uses 16dp horizontal padding;
- brightness placement uses an 8dp vertical spacing class;
- footer surface corners are 6dp and footer action height is 48dp.

The applicator does **not** mutate tile state repositories/view models,
click/long-click routing, shade gestures, permissions, privacy indicators,
media session behavior, or accessibility semantics.

Static qualification is hosted in `.github/workflows/ui4-systemui-static.yml`.
That workflow compiles the applicator and runs its synthetic replacement and
pinned-mutation-set self-test without mutating an Android workspace.

Apply only from a SableOS checkout against the canonical Android workspace:

```bash
python3 patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py --self-test

python3 patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py \
  --source /srv/data/sableos_panther_graphene_2026081300_workspace apply

python3 patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py \
  --source /srv/data/sableos_panther_graphene_2026081300_workspace verify
```

UI4R1 remains source-qualified rather than product-qualified until the
canonical Panther tree is mutated under an authorized gate and SystemUI is
built/reviewed in product context.

## UI4R2 implementation

UI4R2 extends the cumulative SystemUI applicator with notification-shade
geometry only. Before the mutation was added, `packages/SystemUI/res/values/dimens.xml`
was sealed in `UI4_SYSTEMUI_BASELINE.json` at blob
`6f388d006b55ce7355a08ca1628baf5b6ec3c92c`.

The bounded delta is:

- notification outer corner radius: 28dp -> 6dp;
- normal inter-notification divider/spacing: 2dp -> 8dp;
- notification shade scrim corner radius: 32dp -> 6dp.

Existing grouped-child corner behavior remains unchanged, including the 4dp
adjacent-notification radius. Notification ranking, grouping, expansion,
dismissal, actions, heads-up behavior, focus/accessibility semantics, and
notification-provider/security behavior are unchanged.

The same `UI4 SystemUI static` workflow now self-tests the cumulative UI4R1
and UI4R2 mutation set. Product/runtime acceptance remains deferred to UI4R4.

## UI4R3 implementation

UI4R3 extends the cumulative SystemUI applicator with media-surface visual
alignment. Before mutation, the actual renderer
`packages/SystemUI/src/com/android/systemui/media/remedia/ui/compose/Media.kt`
was sealed in `UI4_SYSTEMUI_BASELINE.json` at blob
`e794506f7928cd44c8670719ba051fb7f8a90b28`.

The bounded delta is:

- media carousel/card clip radius: 32dp -> 6dp;
- media artwork/background clip radius: 32dp -> 6dp;
- output/device-chip surface, clip, and border radius: 12dp -> 6dp.

The media presentation model, album-art treatment, title/artist hierarchy,
carousel paging, swipe-to-dismiss, output-device routing, playback actions,
seek behavior, session state, false-touch handling, and accessibility semantics
remain unchanged. Touch-target geometry is not reduced.

The same `UI4 SystemUI static` workflow self-tests the cumulative UI4R1-R3
mutation set. Product build and runtime visual/accessibility acceptance remain
the UI4R4 gate.

## UI4R4 accelerated preview gate

UI4R4 combines source application, product build, packaging proof, inactive-slot
flash and runtime evidence into one development-preview handoff:

```text
build/panther/build-ui-preview.sh
build/panther/flash-ui-preview-inactive-slot.sh
build/panther/validate-ui-preview.sh
docs/UI_PREVIEW_BUILD_FLASH.md
```

The build gate syncs the shared Sable Design filegroup and SableStart, applies
or verifies the cumulative UI4R1-R3 SystemUI delta, builds a Panther userdebug
target-files package, and refuses flash readiness unless both `SystemUI.apk`
and `SableStart.apk` are present in target-files.

The flash gate preserves userdata and writes the coherent Android userspace set
to the inactive slot:

```text
system_<inactive>
product_<inactive>
system_ext_<inactive>
vbmeta_<inactive>
```

`vbmeta` is written last. The gate refuses a non-Panther device, locked
bootloader, active snapshot update, ambiguous fastboot device set, hash
mismatch, or missing explicit authorization.

This preview intentionally does not wait for UI5/UI6. Device feedback from
UI4R4 should feed those later system-surface tranches.

## First tranche acceptance

```text
UI4_R0_PINNED_SYSTEMUI_SURFACES=PASS
UI4_R1_QS_THEME_GEOMETRY=PASS
UI4_R2_NOTIFICATION_SHADE_GEOMETRY=PASS
UI4_R3_MEDIA_PLACEMENT=PASS
UI4_R1_R2_R3_ACCESSIBILITY_SEMANTICS_PRESERVED=PASS
UI4_R1_R2_R3_BEHAVIORAL_DIFF=NONE
UI4_R4_PRODUCT_BUILD_RUNTIME=REQUIRED
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
