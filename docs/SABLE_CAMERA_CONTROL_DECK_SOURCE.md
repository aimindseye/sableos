# Sable Camera Control Deck: source architecture (D7A)

Status: **source architecture delivered; no device evidence**

Implements the interaction architecture accepted in `docs/SABLE_CAMERA_CONTROL_DECK.md` for the
existing Sable Camera module. This is CAMERA-D6A in that document's roadmap (the product lane's
deliverable D7A). It is source, JVM tests and a static gate. It is not runtime evidence.

## Source markers

These are derived from the source by `build/titan2/qualify-c3b-product-source.sh` and fail the
static gate if the source stops backing them. They are source-level only.

~~~text
SABLE_CAMERA_CONTROL_DECK_MODEL=PASS
SABLE_CAMERA_FIXED_CONTROL_MAP=PASS
SABLE_CAMERA_TOUCH_FALLBACK=PASS
SABLE_CAMERA_TRANSIENT_PARAMETER_UI=PASS
SABLE_CAMERA_CONTROL_LEGEND=PASS
SABLE_CAMERA_GLOBAL_LANDSCAPE_LOCK=PASS_ABSENT
~~~

## Contract statements

~~~text
D7A_DEVICE_RUNTIME_VALIDATED=NO
D7A_DEPENDENCY_DELTA=NONE
D7A_NEW_CAPTURE_MODES=NO
D7A_FUNC_KEYS_BOUND=NO
D7A_FOCUS_POINT_RUNTIME_VALIDATED=NO
D7A_AF_AE_LOCK_RUNTIME_VALIDATED=NO
D7A_ORIENTATION_RUNTIME_VALIDATED=NO
D7A_PHYSICAL_KEY_RUNTIME_VALIDATED=NO
~~~

The runtime markers of the Control Deck document (`SABLE_CAMERA_*_TITAN2`,
`SABLE_CAMERA_CONTROL_DECK_ELITE`) are not claimed by this work and the gate rejects any
`PASS` for them.

## Layers

All of this is pure Kotlin in `apps/titan2/platform/camera/.../core/`, so it is JVM-testable.

~~~text
raw key code -> RawKeys -> core key name -> CameraKeyMap -> CameraAction   (semantic)
touch control -> TouchFallback -----------------------------> CameraAction   (same actions)
CameraAction -> ControlDeck.dispatch (legend/Back, ControlGate) -> ActionRouter -> Cmd
Cmd -> ParameterStrips.after -> DeckState (transient strip)
~~~

- **Raw keys are separate from actions.** `RawKeys` is the only place that holds Android key
  codes. `CameraKeyMap` binds core key names, never integers. `MainActivity` no longer carries its
  own key table.
- **One fixed Sable map.** `CameraKeyMap.standard` is the single opinionated layout from the
  Control Deck document (Space/Enter/Camera shutter, F autofocus, E/I/W/S exposure and Pro
  selectors, +/- zoom, arrows for mode and adjust, C camera, B compare, G last, A Auto). H and `/`
  show the legend. Volume shutter keys remain a per-device profile override, exactly as before
  (Titan 2 only; the Elite profile inherits nothing). There is no per-key customization matrix.
- **Func1/Func2 are not bound** for any profile. Current Titan evidence says the vendor framework
  intercepts them.
- **Touch and keys share one path.** `MainActivity.act` is the only entry point; key presses and
  `TouchControlBar` buttons both call it. `TouchFallback` has a control for every
  `CameraAction`; only Back is provided by the system back gesture. A test enforces both.
- **Capability gating.** `ControlGate.check` closes every control the camera cannot back through
  existing Camera2 reporting (zoom without a range, fixed focus, no EV range, no manual sensor,
  single camera or mode, video-only and photo-only actions). A closed control is not run; the
  status line says why, and the legend shows it greyed with the reason.
- **Transient parameter strips.** `ParameterStrips` builds a strip (ISO, white balance, shutter
  speed, exposure compensation, manual focus, zoom) only from the limits the camera reported. A
  strip appears while a control is adjusted and expires after `DeckPolicy.STRIP_TIMEOUT_MS`.
  The permanent Pro cell row was removed; Pro field selection is by key or touch control and the
  Pro HUD names the selected field and value.
- **Legend.** `ControlLegend.entries` is generated from the key map, so it cannot describe a key
  that does not work. It is dismissed by H, `/`, Esc/Back, any other control, or a tap.
- **Orientation.** `DeckPolicy.ORIENTATION_POLICY=AUTO`, `GLOBAL_LANDSCAPE_LOCK=false`. The
  manifest keeps `screenOrientation="unspecified"` and the source never sets a requested
  orientation. Portrait is the minimal conventional surface with touch chrome always visible.
  Landscape is the Control Deck presentation: touch chrome is hidden until a tap on the viewfinder
  reveals it, and the physical keys are fully active in both.

## Explicitly not in this deliverable

- No new capture modes: Photo, Video and Pro remain the only modes.
- No HAL or vendor changes, no `SYSTEM_CAMERA`, no GCam or proprietary camera code, no
  timelapse, burst or computational HDR.
- No Func1/Func2 application bindings.
- No movable focus point, AF lock or AE lock (CAMERA-D6B), and no orientation or inset polish
  (CAMERA-D6C). Those and all device evidence stay later work. The existing F key keeps its
  previous AF-trigger behaviour.
- No claim that AF/AE lock, focus geometry, orientation or physical-key delivery works on a
  device.

## Verification limits

The JVM tests cover the key table, the fixed map, touch parity, gating, strips, expiry, legend
and Back/dispatch rules. The Compose layer (`MainActivity.kt`) is verified by
the static gate and by operator Android compile, lint, Detekt and Ktlint only. This module has no
Compose test dependency and D7A adds none, so there are no Compose UI tests and nothing here has
run on a device. See KL-014.
