# R9 daily-driver visual design review

Status: **design-only Mac mini approval tranche / no Panther product plumbing**

Date: 2026-09-21

## Purpose

R9 expands from the existing launcher/UI closure into the first coherent daily-driver SableOS presentation. Per project methodology, visual language is approved on the Mac mini Pixel 7 AVD before production wiring, provider plumbing, platform mutation or a full Panther image.

This tranche is intentionally static-fixture driven. It must not be treated as runtime proof.

## Review scope

The non-product `sablestart-visual-review` APK contains `R9DailyDriverDesignReviewActivity` with these frames:

1. `icons` — proposed first-party/core-app icon family;
2. `start-dark` — dimensional Metro Start, dark;
3. `start-light` — same hierarchy, light;
4. `live` — proposed Live screen;
5. `calendar` — Sable Calendar visual direction;
6. `clock` — bounded Clock presentation;
7. `camera` — bounded Camera presentation;
8. `files` — bounded Files presentation;
9. `photos` — bounded Photos/Gallery presentation;
10. `browser` — bounded Vanadium presentation;
11. `messages` — final Sable Messages visual/copy direction.

The activity is excluded from the Panther product graph and uses static review data only.

## Icon source and adaptation

Base glyph geometry is derived from Phosphor Icons regular SVGs, pinned to:

```text
repository: https://github.com/phosphor-icons/core
commit:     2b75f3ad12b420c9504ef05df8d2564a28f8500e
license:    MIT
```

The review APK packages the upstream MIT notice at
`res/raw/phosphor_icons_license.txt`.

Sable does not ship raw stock icons as final brand identity. The review composes the glyphs into a Sable adaptive-icon language with:

- stable per-app identity accents;
- consistent optical scale;
- restrained rounded-square geometry;
- tonal depth and a bottom identity rail;
- matching treatment across launcher, Settings and Recents once approved.

## Tile direction

The review replaces the current saturated flat-tile pattern with **dimensional Metro**:

- information-first typography;
- 8dp restrained geometry rather than pill/card styling;
- a 3dp stable app-identity accent rail;
- subtle tonal gradient/elevation instead of a fully saturated rectangle;
- three bounded tile forms: compact 1x1, live 1x1 and wide 2x1;
- dynamic information only where useful;
- user Sable accent remains focus/selection state rather than randomly recoloring app identity.

The live fixtures deliberately use privacy-safe summaries:

```text
Messages  -> unread count, no message body
Mail      -> unread count, no subject/body
Calendar  -> next event/time
Weather   -> temperature/condition
Media     -> active track/playback
Phone     -> missed-call count
Photos    -> local count/state
```

## Design references

Sable adopts principles rather than another product's branding or source:

- Metro/Windows Phone: clean information hierarchy, typography and meaningful motion;
- modern Windows design: coherent hierarchy, restrained color, layering/elevation;
- Phosphor: consistent open-source glyph geometry only.

Production implementation remains Sable-owned.

## Approval boundary

Visual approval authorizes only the visual direction. It does not prove:

- CalendarProvider write/edit plumbing;
- alarm/timer platform behavior;
- camera capture pipeline;
- file-provider behavior;
- Gallery/MediaStore behavior;
- Vanadium runtime integration;
- live-tile provider refresh;
- SMS/MMS roles;
- Panther system theme propagation.

After approval, the next tranche ports the approved surfaces into production source, then adds real provider/role/lifecycle plumbing and gates.

User visual approval was received on 2026-09-21.

```text
R9_DAILY_DRIVER_VISUAL_DESIGN=APPROVED
R9_DAILY_DRIVER_PRODUCTION_PLUMBING_AUTHORIZED=YES
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```

The approval authorizes production implementation of the reviewed visual language.
It does **not** authorize a full Panther image yet. The image remains blocked until
the approved surfaces are ported into production source, real providers/roles/
lifecycle refresh are wired, and the new pre-image qualification gates pass.
