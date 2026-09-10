# Sable M1 — Sable Start architecture and engineering standard

Status: **accepted implementation gate / code not yet landed**.

Date: 2026-09-09

M1 is the first implementation milestone for Sable Flow. It establishes Sable Start as an Android-managed, Metro-inspired home surface without prematurely binding the product to a renderer or widening the launcher privilege boundary.

The machine-readable contract is `product/m1/sable-start-engineering-contract-v1.json`. The read-only validator is `tools/validation/product-m1/SABLE_M1_ENGINEERING_PREFLIGHT.py`.

## 1. M1 outcome

M1 must produce a real Panther launcher prototype with reusable Sable Flow primitives, not a screenshot demo:

```text
Sable Start
  vertical tile surface
  Phone tile
  People tile
  Messages tile
  Settings tile
  Social Hub placeholder tile
  app/service list transition
  accent/theme tokens
  privacy/redaction states
```

Launcher3 remains installed and recoverable until replacement qualification closes.

## 2. Architecture

Keep product semantics independent from the renderer:

```text
Android lifecycle / HOME intent boundary
             |
             v
Sable Start application adapter
             |
             v
renderer-independent Start core
  state + events + effects + tile model
             |
             v
renderer adapter
             |
             v
Android-managed Surface / SurfaceFlinger
```

The renderer owns presentation, not system authority. M1 does not bind Slint, Makepad, WaterUI, Vexo, Dioxus/Blitz or a Sable renderer before a bounded qualification result.

A recommended logical separation is:

```text
start-core        pure semantic state machine; no Android/HAL/device access
start-platform    narrow Android lifecycle/package/intent adapters
start-renderer    selected renderer adapter after qualification
start-testkit     deterministic fixtures and state-transition tests
```

Names and exact build layout may change with the selected framework, but the dependency direction may not invert. Renderer code must not become the location of package policy, privilege decisions or device access.

## 3. State model

Use a unidirectional state/effect design:

```text
Event -> reducer -> new immutable state + typed Effect
                              |
                              v
                    bounded platform executor
                              |
                              v
                         Result Event
```

Rules:

- deterministic reducers wherever possible;
- no hidden global mutable state for shell semantics;
- no UI callback directly performing privileged/platform work;
- effects are typed and allowlisted;
- lifecycle cancellation is explicit;
- stale asynchronous results carry generation/identity so they cannot overwrite newer state;
- high-frequency updates are coalesced before presentation;
- queues/channels are bounded with documented overflow behavior;
- no timer polling when Android/package callbacks or another event source exists.

## 4. Android security boundary

M1 is a launcher, not SystemUI and not a privileged command broker.

Initial manifest policy:

- `android.permission.INTERNET`: forbidden;
- network-state permission: forbidden;
- only `QUERY_ALL_PACKAGES` is pre-authorized because launcher functionality requires application visibility and AOSP Launcher3 uses the same permission;
- any additional permission requires a contract revision and review before source lands;
- exactly one exported activity is permitted for the HOME entry point;
- exported services, receivers and providers: zero in M1;
- backup: explicitly disabled;
- cleartext traffic: explicitly disabled;
- persistent process: disabled;
- shared UID: forbidden.

Incoming intents are untrusted input. Validate action, category, data, component and extras before use; never forward a nested intent without sanitization/explicit allowlisting. PendingIntent use, if added later, defaults to immutable.

M1 application-owned code must not:

```text
spawn shell/process commands
read /sys power/device state
open Binder/HwBinder device nodes
bind Health HAL directly
implement raw RIL/modem access
request CAP_NET_ADMIN or equivalent broad Linux capability
circumvent PackageManager / ActivityManager
```

## 5. Rust coding standard

Sable-owned M1 Rust code follows:

- `rustfmt` required;
- Clippy correctness, suspicious and performance findings treated as failures;
- safe Rust is the default and `unsafe` is forbidden in Sable-owned M1 code unless a future boundary is explicitly allowlisted and reviewed;
- `unwrap`/`expect` are not runtime error handling for untrusted/platform inputs; use typed errors and graceful fallback;
- panic is not a control-flow mechanism;
- integer conversions crossing Android/FFI/data boundaries are checked;
- indexes and dimensions from external/platform data are bounds-checked;
- ownership should make lifetime/cancellation relationships explicit rather than relying on leaked/static state;
- avoid cloning large state or strings on each frame; use stable IDs, borrowed/shared immutable data and incremental diffs where the renderer supports them;
- do not optimize by introducing unsafe code without measurement showing a real need.

Renderer/framework dependencies may internally contain unsafe code; that is a supply-chain qualification issue and does not authorize new Sable unsafe blocks.

## 6. Performance engineering

Performance is a release property, not a later cleanup task.

M1 measures on Panther:

- hot and warm start distributions;
- time to initial/full display where the selected integration supports it;
- frame deadline/overrun distribution during Start scrolling and tile transitions;
- P50/P90/P95/P99, not only averages;
- RSS and allocation behavior;
- idle CPU after UI settles;
- package-change update cost;
- process-restart/restore latency.

Initial targets:

```text
hot start <= 150 ms
warm start <= 200 ms
standard Start-scroll P95 frameOverrunMs <= 0
P99 always recorded and regression-reviewed
```

Do not perform network activity on startup. Minimize synchronous disk and Binder work on the first-frame path. Render a valid shell skeleton first and populate noncritical app/tile data asynchronously with bounded work.

Avoid common launcher performance failures:

- querying every package repeatedly per frame;
- decoding/resizing icons on the UI thread;
- rebuilding the whole tile tree for one tile change;
- unbounded image/icon caches;
- animation loops that run while visually idle;
- polling package/battery/time state instead of subscribing to appropriate events;
- per-frame allocation of stable layout/style objects;
- logging on hot rendering paths.

Any optimization must retain correctness and have before/after traces.

## 7. Data and privacy

M1 has no network egress, telemetry, analytics or remote configuration.

Persist only state required to restore the user's Start layout/preferences. Sensitive live-tile previews must honor lockscreen/redaction policy. Do not create a second permanent archive of messages, social content or notifications merely to render a tile.

Logging rules:

- no message bodies, auth tokens, contact identifiers, account names or URLs containing secrets;
- stable event/category names rather than raw payload dumps;
- production logging is bounded and rate-limited;
- debug logging is not required for correctness.

## 8. Supply-chain requirements

Before selecting a renderer or adding a dependency:

- exact source/version/commit provenance;
- deterministic lockfile or equivalent pin;
- offline/reproducible integration path;
- transitive dependency inventory;
- license inventory;
- known network/build-script behavior;
- Android lifecycle/accessibility/IME implications;
- binary/RSS/startup cost measured when relevant;
- no runtime-downloaded executable code.

Every new dependency needs a reason stronger than convenience. Prefer standard library/platform APIs when they are sufficient and auditable.

## 9. Test pyramid

### Host/pure-core

Required from the first core commit:

- reducer/state transition tests;
- invalid event/input tests;
- tile-layout invariants;
- stable-ID/diff behavior;
- bounded queue/coalescing tests;
- stale-result rejection;
- deterministic serialization/migration tests if persistence is introduced.

### Android integration

Required before default-HOME qualification:

- HOME/main intent behavior;
- activity recreation and process death;
- return-to-home/task semantics;
- package install/remove/change events;
- launcher app enumeration and launch failures;
- locale change, RTL, font scale and display-size changes;
- accessibility traversal/labels/actions;
- rotation/configuration behavior actually supported by the product;
- lock/unlock/redaction behavior for live state;
- malformed/unexpected intent input;
- low-memory/process-restart recovery.

### Performance

Automate repeatable Panther startup and scroll journeys. Use Android frame/startup tracing and Perfetto/Macrobenchmark-compatible measurement where applicable to the chosen renderer. A visually smooth manual run is not closure evidence.

### Adversarial/security

At minimum prove:

- no unexpected permissions;
- exported-component cardinality;
- no direct device/HAL/sysfs access;
- no process/shell execution path;
- no network permission/egress;
- malformed intent/extras do not crash or redirect unsafely;
- app/package names, labels and icons are treated as untrusted data;
- pathological package counts/label lengths/icon sizes are bounded;
- renderer crash does not destabilize platform services;
- Launcher3 fallback remains usable.

## 10. Accessibility and internationalization

Accessibility and localization are architectural, not polish tasks.

M1 must avoid renderer lock-in that prevents:

- semantic labels/roles/actions;
- logical traversal order;
- large font scale;
- TalkBack/Android accessibility bridge integration;
- RTL layout;
- Unicode/Indic shaping;
- Hindi and English baseline rendering;
- deterministic keyboard focus for future Q25/Q27.

Tiles must not encode meaning by color alone.

## 11. Failure handling

User-facing shell behavior must fail soft:

```text
package query failure -> keep shell usable + retry on explicit lifecycle/event boundary
missing app icon      -> deterministic fallback icon
invalid tile state    -> bounded fallback tile, not process crash
provider unavailable  -> unavailable state, not busy loop
renderer failure      -> Android process may restart; platform services remain unaffected
```

No watchdog/retry loop may create an uncontrolled restart storm.

## 12. M1 source gate

Before source exists, the preflight should return:

```text
M1_SOURCE_PRESENT=NO
M1_READINESS=READY_TO_IMPLEMENT_UNDER_CONTRACT
SABLE_M1_ENGINEERING_PREFLIGHT=PASS
```

Once source exists, M1 source preflight becomes fail-closed for the manifest and bounded prohibited-source rules.

The M1 implementation does **not** become the default HOME until additional build/image/runtime/physical gates prove:

```text
SOURCE_PREFLIGHT=PASS
HOST_TESTS=PASS
BUILD=PASS
MANIFEST_PERMISSION_GATE=PASS
IMAGE_PRESENCE=PASS
STARTUP_PERFORMANCE=PASS
FRAME_PERFORMANCE=PASS
ACCESSIBILITY=PASS
PANTHER_PHYSICAL_ACCEPTANCE=PASS
LAUNCHER3_ROLLBACK=PASS
```

## 13. Current authorization boundary

This deliverable authorizes no Android source/workspace mutation, build or device action:

```text
SOURCE_MUTATION_AUTHORIZED=NO
WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
DEVICE_REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
```

Repository documentation/validation files may evolve independently; Android workspace integration remains separately authorized.
