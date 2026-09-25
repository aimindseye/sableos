# SableOS UI/UX contract

Status: active R8 baseline + R9 launcher-extension product contract  
Contract version: 4  
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

`Follow system` is the normal default unless a surface has an explicit reviewed exception. R9 uses one Settings-owned global appearance authority at `content://org.sableos.appearance/appearance` for `Follow system` / `Light` / `Dark` plus the bounded Blue / Green / Purple / Orange / Slate accents. SableLauncher and Sable-owned apps consume/edit that state through the shared appearance contract; standalone app qualification falls back to Follow system + Sable Blue when the provider is unavailable. A production surface must not silently create an unrelated hard-coded dark/light theme. Content-specific bounded color remains allowed for information that inherently uses color, such as game values or album artwork, provided contrast and non-color state cues remain accessible.

## Core principles

1. **Content first.** Large readable titles, strong section hierarchy and minimal decorative chrome.
2. **Flat, structured surfaces.** Prefer rectangular or lightly rounded surfaces with little or no elevation. Standard corner radius is capped at 6dp.
3. **Sable accent as orientation and state.** Accent color marks selection, focus, progress and important actions. It is not used as decoration everywhere.
4. **Consistent spacing.** Screen edges, section gaps, rows and controls use the shared `SableSpacing` scale rather than ad-hoc dp values.
5. **Human names in product UI.** App lists show app names. Package names, component names and internal identifiers belong in diagnostics/developer surfaces only.
6. **Visible state.** Selected, disabled, active, warning and destructive states must be visually distinguishable without relying on color alone.
7. **Touch accessibility.** Interactive targets are at least 48dp, text must remain usable with Android font scaling, and controls require meaningful accessibility labels.
8. **Fast restrained motion.** UI motion uses 120/180/240ms timing classes and should explain navigation or state changes rather than decorate them.
9. **Theme consistency.** R8 supports Follow system, Light and Dark through shared semantic roles and one global Sable appearance state. Follow system is the default, Sable Blue is the reset accent, and Start, Calculator, Games, Media, Reader, Hub and Mail must consume the same mode/accent selection. Individual apps must not maintain an unrelated private hard-coded palette.
10. **Truthful branding.** User-facing product branding should say SableOS where SableOS owns the surface. Internal package/API identifiers and technically truthful provider/service ownership references are not blindly renamed.
11. **One refresh interaction.** Refreshable first-party data surfaces use the shared Android pull-to-refresh gesture. Ordinary screen refresh must not add a separate app-local Refresh button. Event-driven updates remain the primary path where available; pull-to-refresh is the consistent user-controlled freshness fallback.

## Shared primitives

The canonical Compose source is:

```text
src/android/shared/sabledesign/
```

It is consumed by:

- the Gradle `:design` module used by R8 first-party apps;
- the Soong-built standalone `SableLauncher` through `:sable_design_shared_srcs`.

Shared primitives currently include:

- `SableTheme`
- `SableDesignContract`
- `SableSpacing`
- `SableSize`
- `SableColorTokens`
- `SableScreen`
- `SableScrollableScreen`
- `SableRefreshableSurface`
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

## Refresh interaction contract

Sable-owned refreshable data screens use `SableRefreshableSurface`, which owns the Material3 pull-to-refresh interaction.

Current refreshable surfaces include:

- SableStart Start and Live;
- Sable Hub and Connected Apps;
- Sable Weather;
- Sable Calendar agenda/provider views;
- Sable Media Podcasts.

Rules:

- a downward pull at the top of the data surface requests a fresh snapshot or explicit provider refresh;
- the standard pull indicator communicates in-progress refresh state;
- ordinary screen refresh does not get a separate visible **Refresh** button;
- provider/content observers should still update screens automatically when SableOS has an event-driven signal;
- pull-to-refresh is a fallback and explicit user action, not permission for background polling;
- explicit domain operations remain explicit controls when they are not equivalent to refreshing the current screen (for example Subscribe, Import folder, Save, Send, or Retry a failed mutation);
- editing/form screens do not need refresh gestures unless their content is itself a refreshable external-data view.

## Screen rules

### Start / app listing

- Display the page as **Start**.
- Display launcher entries by app label only.
- Do not show package names in the normal list.
- Keep the primary app list fast, vertically scannable and explicitly designed for one-handed use.
- Start remains Sable/Metro-derived: large typography, restrained flat geometry, live information and user-controlled pinned capabilities rather than a generic Android icon grid.
- R9 adds a compact favorites surface, a locale-aware edge alphabet rail, local Search/Command, and one-level **Sable Peek** contextual actions.
- The alphabet rail must be reachable from the right edge and through a left-edge activation region without mirroring the entire list.
- Persistent usage-ranked app ordering is not the default. User pinning and exact alphabetical order remain the privacy-preserving baseline; session recents may remain memory-only.
- Search is local-first. SableStart itself must not become an ambient network search client; remote/provider results require an explicit provider and privacy boundary.
- Sable Peek may expose Open, Pin/Unpin, published app shortcuts, App Security & Privacy and Android App info. Notification/widget content is optional and requires explicit access/redaction policy.
- Quickstep remains available for Android Recents/Overview and gesture integration until Sable separately owns and qualifies those surfaces.
- Pinned/live content must use the same tile/state primitives rather than a separate visual system.
- Before the next full Panther image build after a launcher redesign, a production-source visual review set is mandatory. Required states are defined in `R9_SABLESTART_LAUNCHER_DESIGN.md`.

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
- Media: use a Zune/Modern-inspired media-library/player hierarchy while following the global Sable Light/Dark/accent contract. Songs, Artists, Albums and Favorites use lazy flat rows plus a right-edge alphabet rail; destructive remove is not an inline browse action. Large collections must not trigger whole-library Compose rendering or per-frame grouping/sorting: collection indexing occurs off the UI thread, Up Next and playlist editing are lazy, playback-position ticks are scoped to Now Playing, and queue handoff must stay bounded rather than serialize an entire library through Binder. Album/now-playing art may use richer color than ordinary system surfaces; playback/source state remains truthful. Local favorites, playlists, queue ordering and preferences stay on-device and operate only on files explicitly added by the user.
- Reader: reading surfaces may reduce chrome, but navigation, settings and dialogs remain Sable-consistent. Ordinary Light/Dark follows the SableOS global appearance authority. Sepia remains an explicit reading override and E-ink remains an explicit compatibility mode. The library shows actual distinct books in a continuously accessible vertical grid; it must not collapse a larger library into a six-item/stack-only presentation.
- Messages: the normal product surface is Messages + People, not a provider-services dashboard. SMS presentation remains over the retained Android/Graphene Messaging transport boundary. Third-party apps integrate through user-authorized Android notification/conversation metadata and source-app RemoteInput actions where available. Connected-app configuration is package + Android user/profile based and must not require recompiling SableOS when a compatible messaging app is added.

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
- Launcher redesigns are build-blocking until the production-source review set is accepted; prototype/demo-only launcher screenshots do not satisfy this gate.
- SableStart launcher acceptance separately proves HOME resolution, HOME role ownership, cold-launch survival and Quickstep/Recents preservation. Package presence alone is insufficient.
