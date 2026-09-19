# SableOS UI/UX contract

Status: active R8 product contract  
Contract version: 2  
Design implementation schema: `SableDesignContract.SCHEMA_VERSION = 2`

## Purpose

SableOS uses one visual and interaction language across launcher, system surfaces and first-party apps. Individual screens may specialize their content, but they must not invent independent navigation, typography, spacing, corner, color or state conventions.

The design is influenced by the clarity and information hierarchy of Microsoft Metro/Modern UI without copying Windows branding or layouts. SableOS should feel direct, lightweight and recognizably its own product.

## Appearance contract

R8-A closure requires one shared appearance model for Sable-owned Compose surfaces.

Required modes:

```text
Follow system
Light
Dark
```

Required accent policy:

- accent selection is bounded to the approved `AccentPreset` set;
- arbitrary unrestricted color entry is not part of the R8 baseline;
- Sable Blue is the reset/default accent;
- accent is semantic state/orientation, not decorative fill everywhere.

Required reset behavior:

```text
appearance mode -> Follow system
accent          -> Sable Blue
local overrides -> cleared
```

`Follow system` is the normal default unless a surface has an explicit reviewed exception. Sable-owned screens should consume shared semantic color roles from `SableTheme`; a production surface must not silently create an unrelated hard-coded dark/light theme. Content-specific bounded color remains allowed for information that inherently uses color, such as game values or album artwork, provided contrast and non-color state cues remain accessible.

## Core principles

1. **Content first.** Large readable titles, strong section hierarchy and minimal decorative chrome.
2. **Flat, structured surfaces.** Prefer rectangular or lightly rounded surfaces with little or no elevation. Standard corner radius is capped at 6dp.
3. **Sable accent as orientation and state.** Accent color marks selection, focus, progress and important actions. It is not used as decoration everywhere.
4. **Consistent spacing.** Screen edges, section gaps, rows and controls use the shared `SableSpacing` scale rather than ad-hoc dp values.
5. **Human names in product UI.** App lists show app names. Package names, component names and internal identifiers belong in diagnostics/developer surfaces only.
6. **Visible state.** Selected, disabled, active, warning and destructive states must be visually distinguishable without relying on color alone.
7. **Touch accessibility.** Interactive targets are at least 48dp, text must remain usable with Android font scaling, and controls require meaningful accessibility labels.
8. **Fast restrained motion.** UI motion uses 120/180/240ms timing classes and should explain navigation or state changes rather than decorate them.
9. **Theme consistency.** The R8 first-party color-phone baseline is dark: black/near-black backgrounds, dark raised surfaces, light text and Sable Blue for primary state/action. Light mode is deferred until it can be qualified across the whole product; individual apps must not silently follow the host light theme and split the product appearance.
10. **Truthful branding.** User-facing product branding should say SableOS where SableOS owns the surface. Internal package/API identifiers and technically truthful provider/service ownership references are not blindly renamed.

## Shared primitives

The canonical Compose source is:

```text
src/android/shared/sabledesign/
```

It is consumed by:

- the Gradle `:design` module used by R8 first-party apps;
- the Soong-built `SableStart` launcher through `:sable_design_shared_srcs`.

Shared primitives currently include:

- `SableTheme`
- `SableDesignContract`
- `SableSpacing`
- `SableSize`
- `SableColorTokens`
- `SableScreen`
- `SableScrollableScreen`
- `SablePanel`
- `SableActionButton`
- `SableHeroHeader`
- `SableValuePanel`
- `SablePageHeader`
- `SableSectionHeader`
- `SableListRow`
- `SableTile`
- `SableDivider`
- `applySableDarkSystemBars`

Screens should extend these primitives before introducing local visual conventions.

## Screen rules

### Start / app listing

- Display the page as **Start**.
- Display launcher entries by app label only.
- Do not show package names in the normal list.
- Keep the primary app list fast, vertically scannable and compatible with one-handed use.
- Future pinned/live content must use the same tile/state primitives rather than a separate visual system.

### Quick settings / pulldown / notifications

- Use flat Sable tiles with clear active/inactive states.
- Keep the most common controls reachable in the first expansion.
- Do not overload tiles with secondary text unless it conveys current state.
- Notifications, media controls and quick settings must share spacing, typography and surface rules.
- Long-press or secondary action behavior must remain consistent across tiles.

### Setup / first boot

- Use the Sable page-header hierarchy and SableOS branding.
- Remove legacy GrapheneOS product-facing names from the normal setup journey where SableOS owns the copy.
- Preserve internal identifiers and references that must remain technically accurate.
- Each step should have one obvious primary action and a clearly distinct secondary/back action.

### Settings and system dialogs

- Section titles, rows, toggles, warnings and destructive actions must use the same hierarchy and spacing as first-party apps.
- Security/privacy explanations remain explicit; visual cleanup must not hide technical meaning.
- Search/result rows display human-readable labels first.

#### Applications / Application Security & Privacy

The Applications surface is a strategic SableOS privacy/security surface, not only a restyled stock app list.

- The Applications list exposes a concise privacy/security summary under each app name based on **currently granted/effective access**, not every permission merely declared in the manifest.
- Summaries prioritize sensitive access such as Camera, Microphone, Location, Contacts, Phone/SMS, Nearby devices/Bluetooth, Photos/Media/Files, and high-impact special access such as Accessibility, Device admin, VPN, Notification access, Usage access, Draw over other apps, Install unknown apps, and unrestricted background/battery exceptions where relevant.
- Keep the list scannable: show up to three sensitive access labels, then `+N more`; show `No sensitive access` when none is currently granted.
- Tapping an application opens **Application Security & Privacy**, the Sable detail surface for effective authority and package transparency.
- The detail surface should progressively expose:
  1. identity, installer/update ownership and signing lineage;
  2. runtime permissions, AppOps and special access;
  3. component inventory and exported attack surface;
  4. local library/tracker/privacy signals;
  5. storage, data-use and background-execution context;
  6. bounded local security/privacy history and security-relevant update deltas.
- The UI must distinguish evidence classes where ambiguity matters: `DECLARED`, `ENFORCED`, `OBSERVED`, `INFERRED`, and `UNKNOWN`.
- A declared permission must not be presented as observed use; a detected tracker/library must not be presented as proof that the code executed or transmitted data.
- Color is supplemental only: normal granted access uses secondary text; exceptional/high-impact access may use Sable accent/warning treatment, but the capability name and state remain explicit.
- Existing Android enforcement authorities remain authoritative. The UI should deep-link to or request narrow typed operations from PermissionController, AppOps, PackageManager and other appropriate platform services rather than becoming a generic privileged package manager.
- AppManager is a capability/design reference only. SableOS independently implements these concepts at Android/AOSP boundaries and does not inherit AppManager's root/ADB super-application model or copy GPL implementation into Apache-licensed platform components.

### First-party apps

- Calculator: Basic, Scientific and Converter are modes within one product shell. The phone UI uses a dark calculator display, filled touch-first keypad surfaces and an accent hierarchy for operators/results rather than desktop-style form controls.
- Games: each game should present as a professional color-phone game rather than a developer test card. Sudoku uses visible cell borders and stronger 3×3 boundaries; Minesweeper uses explicit covered/revealed/flagged tile states and visible board structure; 2048 uses a bordered board, value-specific color tiles and swipe-first movement. Shared game screens may be developed together, but the product target remains separate Sudoku, Minesweeper and 2048 launcher APKs.
- Media: use a dark, immersive media-library/player hierarchy influenced by Zune/modern Windows media design while retaining Sable typography, spacing and state rules. Album/now-playing art may use richer color than ordinary system surfaces; playback and source state must remain truthful rather than displaying invented metadata. Local media favorites, playlists, queue ordering and Media preferences are stored on-device and operate only on files the user explicitly added. Up Next edits must apply to the active Media3 queue rather than a disconnected mock list. Live-radio presets and favorites are managed locally: users can name, save, play, favorite, edit and remove explicit HTTP(S) stream URLs without a background recommendation/history service. A future radio-directory search must be an explicit network feature with its provider and privacy boundary made visible.
- Reader: reading surfaces may reduce chrome, but navigation, settings and dialogs remain Sable-consistent. The current Sable color-phone tranche uses the same dark baseline; the upstream E-ink-specific theme remains a separately selected compatibility mode rather than the visual default.

## Rollout sequence

```text
UI1  shared Sable Design System + Start reference screen
UI2  Calculator + Media + touch-first game-screen migration
UI2G separate Sudoku / Minesweeper / 2048 launcher APKs
UI3  Reader/Text Reader composition and reading controls
UI4  SystemUI pulldown / quick settings / notifications / media controls
UI5  SetupWizard + Settings + Application Security & Privacy + system dialogs + visible branding cleanup
UI6  lock screen / remaining system surfaces / accessibility and motion polish
```

The sequence is implementation order, not permission for later screens to invent temporary design languages. New work should use this contract immediately.

## Qualification rules

- Shared design source changes must trigger Android compile, static analysis, quality/coverage and APK artifact qualification.
- `SableDesignContractTest` seals stable preference values and core accessibility/geometry constraints.
- Product-image integration remains a separate gate; a successful standalone Compose build does not prove SystemUI/SetupWizard integration.
- Visual review is required in addition to compile/static gates before a screen is called UI-complete.
