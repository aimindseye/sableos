# Titan 2 stock behaviour vs Sable platform apps

Source: Titan 2 User Manual V1.0 (2025-09), owner photos of the stock Settings and Camera screens (2026-10-01, 37 photos), keyboard close-up.
Status words: **Covered** = built and unit-tested. **Planned** = decided, not built. **System** = belongs in the OS/device adapter, not an app. **Unknown** = evidence needed.

## Keyboard

| Stock feature (where seen) | Sable plan | Status |
|---|---|---|
| Kika is default IME, Gboard installed but off | Sable IME is the default at first boot (IR-005, canonical lane) | Not covered by this repo; requested |
| Physical keyboard "TitanKey", **KCM provider: Default / Other / None** | Our IME must not depend on the vendor KCM. Capture what each choice changes before choosing a default. | Unknown |
| "Use on-screen keyboard while physical keyboard is active" (on) | IME hides its soft view when a hardware key is used and keeps text input receiving hardware events | Covered (device check pending) |
| Alt layer legends printed on keys | `Titan2PhotoRead` layout (all keys except U and I) | Covered (U/I pending) |
| Sym key has no printed layer; default = symbol key; Fn default = Home | Sym opens the symbol picker only; Fn is never treated as a modifier | Covered |
| Raw key events (stock, captured with `getevent -lt`): Upper red key = scan 249 on `mtk-pmic-keys` (event1); Lower red key = scan 250 on `gpio_key-func` (event3). **fn produced no kernel event at all** on any input device, so fn acts inside the keyboard controller or firmware and cannot be read as its own key. Sym and Alt come through `TitanKey` (event7). | Do not depend on fn as a key. Treat Func1/Func2 as vendor-owned. The Key Probe app shows what reaches an ordinary app. | Captured |
| Func1/Func2: Subscreen control, PTT, Programmable key (None, Media, Power, Sym, Ctrl, Tab, Shift, Alt, Home, Back, Recent, Magic key), Shortcut settings (short, long, double press) | Func keys stay vendor-owned. Our camera accepts them only through `keyOverrides` after capture. | Unknown (scan codes) |
| Per-key shortcuts (Settings > Shortcut keys > Letter key, long and short press) on the desktop only | System/launcher feature. IME must not consume letters when no text field is focused. | System |
| Modifier keys remap (Caps lock, Ctrl, Action key, Alt, Reset all) | AOSP feature. IME honours the platform's remapped meta state instead of keeping its own table. | Planned |
| Meta shortcuts (Action+H home, S screenshot, N notifications, L lock, I settings, A assistant, U/C/B/P/E/M apps) and Ctrl+Space language switch | AOSP shortcuts. IME must pass Meta chords through and support Ctrl+Space. | Planned |
| Repeat keys, Sticky keys, Bounce keys, Slow keys | Platform accessibility. IME must not duplicate repeat, so it uses the framework repeat count. | Planned |
| Flick typing: swipe up on the touchpad to pick a candidate word (Kika only) | Needs touchpad events routed to the IME. No candidate bar exists yet. | Planned (needs touchpad evidence) |
| Keyboard gestures: scroll assistant, cursor assistant (double-tap then slide moves the cursor) | Touchpad-to-scroll and touchpad-to-cursor belong to the input adapter | System |
| Slide to turn on the keyboard light; automatic keyboard light; duration (5 s); brightness slider | Backlight needs a Sable-owned system API | System |
| Alt key wakes the screen from off | Wake policy | System |
| Space bar: double-click answers call, hangs up, takes a picture; click returns to desktop (non-input screens) | Camera already binds Space to shutter. The others are system. | Covered (camera) |

## Camera

| Stock feature | Sable plan | Status |
|---|---|---|
| Modes: Timelapse, Video, Photo, Pro, More (Mono, Super resolution, QR code, Edit) | Video, Photo and Pro are built (Left/Right switch). Timelapse and More are not. | Covered (logic tested; device unverified) |
| Pro controls: WB, ISO, EV, S (shutter), F (focus), all Auto by default | Built: W/I/E/S/F pick the field, Up/Down step it, A returns it to Auto. Ranges come from the camera; a control the camera does not report is shown n/a. Either ISO or shutter manual turns auto-exposure off. | Covered (logic tested; device unverified) |
| Settings: self timer, ZSD, picture ratio (shows "Full screen"), capture sound, watermark, anti-shake, gridlines, straighten, anti flicker, auto screen brightness, GPS location, key mode, reset | Priority: self timer, picture ratio, gridlines, straighten, GPS tag opt-in, capture sound. Skip watermark. | Planned |
| Volume keys take photos and video; "Key mode" makes them switch modes; FN (programmable) key also shoots | Volume keys are shutter now. Key mode as an option. | Covered / Planned |
| Burst: hold the shutter | `CapturePlanner.bracket` exists. Real burst is not built. | Planned |
| Video: 3GP or MP4, quality, microphone on/off, anti flicker | Built: MP4 (H.264/AAC), quality list from the recorder sizes (Q cycles), pause (P), silent when the microphone is denied. 3GP and anti-flicker are not built. | Covered (logic tested; device unverified) |
| Super resolution (8192x6144 JPEG in the stream map) | Offered as an ordinary-stream size | Covered |
| Sub-screen camera (rear panel, swipe in from clock) | Out of scope for the ordinary-app path. Privileged hidden cameras 2/3 deferred. | System |

## Sub-screen (rear panel) and Mini mode

| Stock feature | Sable plan | Status |
|---|---|---|
| Sub-screen: clock faces, calls, notifications (per-app), media control, compass, camera, battery/brightness | Vendor-owned system feature. Not part of these apps. The IME and camera must keep working with the sub-screen on. | System |
| Func1 toggles the sub-screen by default | Do not rebind Func1 | System |
| Wake with main screen, double-tap wake, incoming-call and notification wake | Vendor policy | System |
| Manual: most apps do not adapt to the sub-screen and it has no text input | Do not target apps at the sub-screen | System |
| **Mini mode**: toggled by shortcut key, three-finger swipe down, or quick tile | **Captured on a stock Titan 2:** Mini off: `wm size` physical 1440x1440, override 1436x1440; `wm density` physical 400 (no override). Mini on: override 810x1440 (9:16), density still 400. So Mini is a system window-size override that narrows the width and leaves density alone. Only one Mini width has been seen; a web summary claimed three widths and scaled densities, which the capture contradicts. Sable sets `persist.sable.displaycompat.mini_size=810x1440` for Titan 2 only. The stock 1436x1440 override in the off state is a vendor quirk we are not copying. | Captured (810 wide); other widths unknown |
| Rotation Control (Settings > Intelligent Assistance) per-app orientation | Display compat profile gets an orientation field | Planned |

## Captured so far
Mini 810x1440 (density unchanged), Func1 = 249, Func2 = 250, fn = no event. Alt+U = `-`, Alt+I = `_` (owner-confirmed). KCM provider Other and None: switching them changed nothing visible.

## Key Probe results (owner run, stock Titan 2, 2026-10-01)
- Every physical key arrives from device `TitanKey`. Sym = KEYCODE_SYM(63) scan 253 with META_SYM_ON; Left Shift = 59 scan 42; right Alt = KEYCODE_ALT_RIGHT(58) scan 100; Space scan 57; Enter scan 28; U scan 22; I scan 23.
- Alt+U delivered `char=U+002D '-'` from the platform key map with ALT held, matching the Sable table. After Alt is released the character returns to `u`: the OS does not latch Alt, so one-shot or sticky Alt is the IME's job.
- Held modifiers auto-repeat (ALT_RIGHT repeated about every 50 ms after a 400 ms delay). The Sable modifier machine already ignores repeats of a held modifier.
- fn closes the app (acts as Home before apps see it). Neither red key produced any app-visible event. Both stay vendor-owned.

- Full Alt sweep (Alt held, each key): Q0 W1 E2 R3 T( Y) U- I_ O/ A@ S4 D5 F6 G* H# J+ K" L' Z! X7 C8 V9 B. N, M?. All 25 match the Sable table; P was not captured (Alt was released first), so `:` is from the key photo only.
- Sym held plus a letter returns the plain lowercase letter with META_SYM_ON: the platform key map has no Sym layer. Sym is not latched by the OS (Sym tap then E gave plain `e`). Any Sym behaviour (symbol picker) is the IME's job.
- `keyCode 404`, scan 404, device `touchPad` appeared once during the sweep (likely a touch on the keyboard surface), so the vendor 404 comes from the touchpad, not from a red key.

## What I still need from the device (in priority order)
1. Whether the Mini tile offers other widths (long-press the tile). If yes, `wm size` for each.
3. Open **Sable Key Probe** (keyboard app), press fn, Sym, Alt+U, Alt+I, both red keys, and send a screenshot or `adb logcat -s SableKeyProbe`.
4. KCM provider: no visible change from Other or None (owner-tested). Retest after the Key Probe is installed to see whether scan or character output differs.
5. A touchpad swipe-up recording while typing, if you want flick typing.
