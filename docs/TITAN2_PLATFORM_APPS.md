# Titan 2 / Titan 2 Elite platform apps: keyboard, camera, display compatibility

Status: **D1b source/Android qualification passed on ai-g732; never run on a device; no flash authorization.**

```text
LANE=TITAN2_N0_USERSPACE_LAB
ANDROID_RELEASE=16            # compileSdk/targetSdk/minSdk 36 for platform apps; SableScreens catalog minSdk 29
PANTHER_FILES_TOUCHED=NO
D1B_ACCEPTED_HEAD=8e31cb253b9a6e720fed9a1be23fd6967c621317
D1B_ANDROID_COMPILE=PASS
D1B_ANDROID_TESTS=PASS
D1B_ANDROID_LINT=PASS
D1B_FULL_OFFLINE_QUALIFICATION=PASS
BOOT_VALIDATED=NO
ELITE_EVIDENCE=NONE
Q27_EVIDENCE=NONE
```

Why these three exist: stock Unihertz firmware leaves the keyboard-first hardware under-served. The org's own research records a Bluetooth pairing
text-entry failure (hardware Alt/SYM unreliable, soft keyboard unusable), apps that misbehave on the square panel (Mini Mode / Rotation Control are
only partial per-app answers), and proven camera paths (high-res JPEG, rear RAW/DNG) that the stock app does not fully expose.

Layout: `apps/titan2/platform/{displaycompat,keyboard,camera}`. Each module keeps its rules in a pure-Kotlin `core` package (no Android imports,
enforced by the audit) and a thin Android shell. Source authority: `platform_sable` design docs (`CAMERA_ENHANCEMENT_MODEL`, `CAMERA_CAPTURE_UX`,
`APP_DISPLAY_COMPATIBILITY_PROFILES_UX`, `KEYBOARD_AND_POINTER_PROFILE_MODEL`, `KEYBOARD_FIRST_REFERENCE_INTAKE`, `CRITICAL_TEXT_ENTRY_GATES`).

## Sable Keyboard (`org.sableos.titan2.keyboard`)

Sable-owned IME. It is not derived from Pastiera/Plektra GPL source. Pastiera 0.86 is now an explicit behavior/product reference; see `PASTIERA_086_REFERENCE_INTAKE.md`. Direct GPL source import remains unauthorized.

- Shift/Alt/Sym state machine: tap = one-shot, double tap = lock, hold + key = chord, long hold with no key = cancel.
- Alt and Sym layers, long-press letter for its Alt character, auto-capitalise, double-space period, forward delete on Shift+Backspace.
- Nav mode (IJKL arrows, U/O Home/End, Y/H PageUp/PageDown), toggled with Alt+Space. It suspends in password and numeric fields: text input always wins.
- **Critical text entry:** in numeric/phone fields letter keys type their digit with no Alt/Sym, and an on-screen numeric fallback appears automatically. This targets the stock Bluetooth-pairing failure. Preferences live in device-protected storage and the service is direct-boot aware, so it works at the lockscreen.
- Outside editable fields every key and modifier passes through untouched, so launcher and app shortcuts are not affected.
- Default IME: not set by this repository. The requirement (IR-005) is owned by the canonical lane; see `docs/C3B_PRODUCT_INTERFACE_EVIDENCE.md`.

Alt and Sym characters are read from the **device's own key character map** (`KeyEvent.getUnicodeChar`) whenever it defines them, so they follow the real legends with no hand capture (Titan 2 stock: Alt+Q gives `0`). Sable's table (`KeyLayout.verified=false`) is only a fallback, and it is a convention, not any device's printed legends: it already disagrees with stock on Alt+Q. Sym has no entry in the stock Titan 2 map (Sym+Q stays `q` with `META_SYM_ON`), so Sym output currently comes from the fallback table. Func1/2, the programmable key and touch-keyboard gestures are vendor-intercepted or unmapped and pass through.

## Sable Camera (`org.sableos.titan2.camera`)

Ordinary Camera2 on public camera ids, per `CAMERA_ENHANCEMENT_MODEL` (no `SYSTEM_CAMERA`, no custom HAL, no GCam dependency). The accepted UX direction is now **Camera Control Deck**: the viewfinder is primary and the Titan physical keyboard is treated as the camera control surface. See `SABLE_CAMERA_CONTROL_DECK.md`.

- Capability interpreter derives modes (Auto, High-res, RAW, Pro) from what the device reports. Tele is always unavailable on this path.
- "Normal" and "high-res" are defined against the sensor's active array, because on Titan 2 the 8192x6144 JPEG sits in the **ordinary** stream map (no high-res or maximum-resolution map, no pixel mode needed). Auto therefore stays on the conventional 4096x3072 path. RAW saved as DNG; files go to `DCIM/SableCamera` through MediaStore (no storage permission), JPEG quality 95, the same as the Titan 2 camera MVP.
- **Compare bracket (B):** one shutter press captures standard JPEG, high-res JPEG and RAW/DNG of the same scene, which is the same-scene comparison the camera doc requires before any quality claim.
- Keyboard control: Space/Enter/Camera key shutter (plus Volume Up/Down on Titan 2, which the stock-camera probe confirmed), Left/Right mode, C camera, E exposure, F focus, G last capture, with Pro parameter keys and +/- zoom. The Control Deck roadmap adds AF/AE lock, keyboard focus-point movement, transient parameter strips and a discoverable control legend. Func1/Func2 remain deliberately unbound until the Android input path proves applications receive them.
- Titan 2 profile holds the *researched* numbers (cameras 0/1, 8192x6144 and 6560x4928 JPEG, 4096x3072 RAW). They are used only to flag mismatches, never to enable a mode. Elite and Q27 profiles are empty on purpose.

Video and Pro source now exist, but their device behavior is unproven. Camera Control Deck interaction, multi-frame processing and any privileged tele path remain later evidence-gated work.

## App display compatibility (`org.sableos.titan2.displaycompat`)

Implements `APP_DISPLAY_COMPATIBILITY_PROFILES_UX` at its N0 interpretation: UI, per-user per-package storage, validation hooks, **gated** backend.

- Profiles: Native, Mini mode, 16:9 letterbox / fill, 4:3 letterbox, Square-safe, Fullscreen media, Keyboard-safe, Custom (advanced, gated). Stretch off by default.
- Per-app controls for orientation, scaling, letterbox background, keyboard-safe area, bars; live canvas preview; Fill and Stretch need an explicit acknowledgement.
- Safety rules enforced before saving: Settings/SystemUI/launcher/keyboards/accessibility services blocked; dialer cannot be reshaped; authenticator and payment apps cannot be cropped or stretched; camera preview cannot be cropped or stretched.
- Reset works without launching the app, Reset-all is one shortcut, and booting to safe mode clears every profile.
- Backend is closed unless `persist.sable.displaycompat.backend=validated`. When open it maps 16:9, 4:3, Fullscreen and Square-safe to the platform per-app minimum-aspect-ratio override via reflection and reports any failure as unsupported. Fill, Custom, Mini mode and orientation are stored and validated but not applied.
- **Mini mode size is not known.** The manuals say only "another normal size". It stays a no-op until captured (`wm size` before and after toggling Mini mode) into `persist.sable.displaycompat.mini_size`.

## Assumptions that must be verified before trusting any of this

1. Whether the hidden `setUserMinAspectRatio` call and its integer constants (copied from Android 14) are available to this app on Android 16. No privapp grant was added.
2. Whether the Titan keyboard delivers hardware key events to the IME service with the soft view hidden on this firmware (standard Android behaviour, unproven here).
3. The TextureView rotation matrix assumes a 90-degree sensor and is the same one the Titan 2 MVP uses; confirm on the square display in every rotation.
4. DNG metadata (colour matrix, black/white level) per `CAMERA_CAPTURE_UX`. The `image/x-adobe-dng` MediaStore insert is the same approach the Titan 2 camera MVP already uses.
5. Default IME at first boot and before first unlock (IR-005, canonical lane; not set by this repo).
6. Everything about Elite and Q27: nothing here is validated for them.

## First device session (read-only, no flashing)

Sideload the APKs on a stock Titan 2 and capture: `getevent -lp`, `dumpsys input`, key legends photographed, `wm size` with Mini mode on/off, camera ids and stream maps from the Camera app's capability report, and the Fn/Func scan codes. Record results in `docs/TITAN2_KEYBOARD_EVIDENCE.md` and the camera/display equivalents, then flip evidence levels in the profiles.

## Deferred

Camera Control Deck runtime polish, keyboard layout import/export, per-app keyboard policy (auto-focus, Enter-to-send), configurable SYM/emoji/snippet surfaces, SYSTEM_CAMERA tele path, accessibility audit and remaining supply-chain/quality work. Pastiera-inspired D6 work must not delay D2/D3/D5 or canonical C3B bring-up.

## Reconciliation with `aimindseye/unihertz-titan2` (read after the first build of this lane)

What the research changed in this code:

- **Camera:** the 8192x6144 and 6560x4928 JPEGs are in the ordinary stream map. My first interpreter treated "high-res" as anything beyond the best normal size, which would have made Auto shoot 50 MP and hidden High-res. Fixed (active-array rule, tests use the real Titan 2 shapes).
- **Keyboard:** stock Alt+Q is `0`; fixed by preferring the device's key character map. Real codes now known: Sym `KEYCODE_SYM` (scan 253), right Alt `KEYCODE_ALT_RIGHT` (100), Space 57, Enter 28, left Shift 42. These are standard keycodes and already handled; Func1 (249) / Func2 (250) are vendor-intercepted.
- **Shutter keys:** Volume Up/Down bound on the Titan 2 profile from the stock-camera probe; Space alone was not proven in the stock app but works in this one because the app handles the key itself.

Open decisions for the project owner:

1. **Camera source direction — resolved.** The Sable-owned Camera2 module is the product-source direction for keyboard-first devices. The device-proven research MVP remains behavioral/session evidence; do not ship both implementations. Reuse proven behavior by reimplementation/porting into the accepted Sable Camera source after provenance review. The interaction target is `SABLE_CAMERA_CONTROL_DECK.md`.
2. **Keyboard direction — resolved.** Sable Keyboard remains the first-party/factory-default direction, subject to canonical IR-005 integration. Pastiera 0.86 is a reviewed GPL-3.0 behavioral/product reference, not imported source. SableOS should preserve Android user choice so third-party IMEs can be installed, enabled and selected; Sable must not force its IME back after the user chooses another.
3. **Not covered by these apps:** keyboard backlight (`keyled_brightness`, 0..100, minimum nonzero 8, needs a Sable-owned system API), touchPad / Mouse Mode (raw ABS_MT stream owned by InputReader), wake policy for the matrix and side keys, and the vendor key-404 translation. Those belong to the device adapter, not these apps.
4. **Device identity.** Pastiera notes warn that an Elite can report Titan-2-like fingerprints. These apps never read build identifiers; they use `ro.sable.profile.id` set by the product fragment (audited).


## Stock feature parity
See `TITAN2_STOCK_PARITY.md` for the feature-by-feature comparison built from the manual and owner photos of the stock settings screens.

## Camera: Video and Pro (added 2026-10-01)

- Modes: Video, Photo, Pro. Left/Right switch. Space, Enter, the camera key and the volume keys are the shutter (they start and stop recording in Video).
- Pro: W/I/E/S/F select WB, ISO, EV, shutter, focus; Up/Down step the selected field; A returns it to Auto; +/- zoom. Camera2 has no shutter or ISO priority, so setting either turns auto-exposure off and the other value is taken from the camera's last auto value. EV applies only while auto-exposure is on. Manual focus uses `LENS_FOCUS_DISTANCE` when the camera reports a minimum focus distance.
- Video: recordable sizes come from the MediaRecorder stream map (16:9, 4:3 and 1:1 only, 480p to 3840 long side). The default is 1080p 16:9. Recording rebuilds the session so no empty file is left while framing. Files go to `DCIM/SableCamera` as `SBV_<date>_<time>_cam<id>_<tier>.mp4`.
- Permissions: CAMERA, and RECORD_AUDIO for video sound only (optional; without it, clips are silent). The source audit now allows exactly these two for the camera app and still rejects anything else.
- Unverified until a Gradle build and a device run: Camera2 manual keys and `LENS_FOCUS_DISTANCE` on the Titan 2 HAL, MediaRecorder with the SurfaceTexture preview, recording orientation, and whether Pro should offer RAW stills.
- Not built: timelapse, burst, video snapshot, 3GP, anti-flicker.

## Sable keyboard: languages and typing

The keyboard is a source candidate (`SableTitan2Keyboard`, not admitted). Product inclusion and default-IME selection belong to the canonical lane (IR-005, IR-011); this repository no longer sets either.

- **Languages** (`core/Languages.kt`): English, Spanish, French, German, Portuguese, Italian, Polish, Turkish, Swedish, Dutch. All are Latin script, so the printed QWERTY legends stay valid. A pack adds accented variants per base letter. Each is an IME subtype in `res/xml/method.xml`; the active one follows the system subtype.
- **Physical keys**: `Sym` + letter types the first accent of the active language; repeating `Sym` + the same letter replaces it with the next accent (cycles). `Sym` + `Space` switches to the next language. Languages with no variant for a letter keep the Sym table. Alt layer and long-press Alt are unchanged.
- **On-screen**: shift tap = one letter, double-tap or long-press = caps lock (shown as ⇪), sentence-start auto-capitalise in fields that ask for it, press-and-hold backspace repeats, long-press a letter for its Alt character and accents (strip above the key), long-press space switches language.
- Subtypes only appear in the switcher once enabled: Settings > System > Keyboard > On-screen keyboard > Sable > enable the languages.
- **Non-Latin on-screen layouts** (all in `Languages.kt`; Alt is hidden on them):
  - Russian, Ukrainian, Greek: standard layouts; long-press gives ё/ъ, ґ, tonos.
  - Arabic (101 layout, shift = tashkeel and hamza forms), Hebrew.
  - Hindi, Gujarati, Tamil, Telugu: InScript. Hindi is written by hand; the other three are derived from it by Unicode character name in `tools/gen_indic_rows.py` (a script's missing letters are dropped). Combining marks are drawn on a dotted circle.
- **Composed input** (`core/Composer.kt`, all pure Kotlin and unit-tested): Korean (Dubeolsik + a Hangul syllable composer, shift for ㅃㅉㄸㄲㅆㅒㅖ), Japanese (romaji to kana, hiragana/katakana candidates; no kanji conversion), Simplified Chinese (pinyin with a 87k-entry dictionary built from jieba and pypinyin, apostrophe separators, partial-pick, Space picks the first candidate). The composing text is underlined in the field and candidates appear in the IME candidates bar.
- **Physical keys**: Korean (Dubeolsik), Japanese and Chinese compose from the physical QWERTY keys. Other scripts do not type on the physical keys yet: the Titan 2 has 26 letter keys, and Arabic, Hebrew, Cyrillic and Indic layouts need more positions than that (Alt/Sym layers would have to carry the rest).
- **Cross-check**: layouts were compared with Indic Keyboard (github.com/smc/Indic-Keyboard, Apache-2.0) and AnySoftKeyboard (Apache-2.0). Nothing was copied; `LanguageTest` pins the character sets (full Cyrillic, Greek, Arabic and Hebrew alphabets, every Hindi InScript key, Tamil/Telugu long and short vowels). Hindi long-press holds the conjuncts (क्ष त्र ज्ञ श्र), nukta letters, candra and short vowel signs; Arabic holds Persian/Urdu letters (پ چ گ ژ) and tashkeel.
- **More Indic languages and Urdu**: Marathi, Sanskrit (Devanagari), Bengali, Punjabi (Gurmukhi), Kannada, Malayalam (with the chillu letters on long-press) and Urdu (Perso-Arabic, long-press for ٹ ڈ ڑ ژ ں ھ and the rest). InScript layouts for these are derived from the Devanagari one by `tools/gen_indic_rows.py` and checked key-for-key against Indic Keyboard.
- **Phonetic (Roman-letter) typing** for Hindi, Marathi, Sanskrit, Gujarati, Bengali, Punjabi, Tamil, Telugu, Kannada and Malayalam: each has a second keyboard "<language> · ABC" in the language list (IME subtype with `layout=phonetic`), also on the physical keys. The scheme is ITRANS-like and case sensitive, one table for all scripts (`tools/gen_phonetic.py`):
  - consonants carry an inherent a: `k`=क `ka`=क `kt`=क्त; vowels after a consonant become vowel signs: `ki`=कि; `aa ii uu` (or `A I U`) long vowels, `ai au`, `RRi`/`Ri`=ऋ
  - capitals are the retroflex and aspirate forms: `T Th D Dh N`, `Sh`=ष, `L`=ळ, `R`=ऱ; `x`=क्ष, `gy`=ज्ञ; `q f z` = nukta letters
  - `M` anusvara, `MM` or `~` chandrabindu, `H` visarga, `OM`=ॐ, `_` explicit virama (`k_`=क्)
  - Hindi `e o` are the long vowels; in Tamil/Telugu/Kannada/Malayalam `e o` are short and `E O` long, and a word-final consonant gets its pulli/virama automatically (`tamizh`=தமிழ்)
  - letters a script lacks fall back to the closest one (Tamil `bh`=ப, Bengali `v`=ব); `nh`=ன, `zh`=ழ, `ng`, `nj` in the South Indian scripts
  - examples: `namaste`=नमस्ते, `bhaarat`=भारत, `hindii`=हिन्दी, `gyaan`=ज्ञान, `tamizh`=தமிழ், `telugu`=తెలుగు
- Not covered: kanji conversion for Japanese, Traditional Chinese and Zhuyin, handwriting, word prediction, native digits.
