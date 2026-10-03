# Product-lane interface evidence (converted from the retired `product/titan2` tree)

These are **facts and requirements**, not product configuration. Nothing here is a product path, overlay, key map or
permission grant, and none of it may be copied into another product tree by the product lane. The canonical C3B lane decides how
each requirement is met.

## IR-005: default input method at first boot

The retired SettingsProvider overlay set both values to the Sable IME service component:

```text
def_input_method          = org.sableos.titan2.keyboard/.android.SableImeService
def_enabled_input_methods = org.sableos.titan2.keyboard/.android.SableImeService
```

Requirements: the Sable keyboard must be the working IME in Setup Wizard, lockscreen and system dialogs, including before
first unlock (the IME service is `directBootAware`). Stock Titan 2 uses Kika as default with Gboard installed but off.
Validate after first boot with `settings get secure default_input_method` and `settings get secure enabled_input_methods`.
This repository no longer sets either value. Until the canonical lane does, the Sable keyboard is not the default.

## IR-004: physical key policy

The retired keylayout placeholder shipped no `.kl`, `.kcm` or `.idc` file. Known facts (from stock research in
`docs/TITAN2_STOCK_PARITY.md` and `docs/TITAN2_PLATFORM_APPS.md`):

- The physical keyboard is exposed by the `TitanKey` input device; Sym is `KEYCODE_SYM` (63); the platform has no Sym layer; Alt must
  be latched by the IME; the Alt-layer legends match the platform kcm.
- Fn and the Func keys never reach apps (Fn acts as Home before apps see it); both red keys produce no app-visible event.
- Scan codes for Fn, Func1, Func2, the touch keyboard and the Elite programmable key are **not captured**. They must be captured on
  the device (read-only inventory: `getevent -lp`, `dumpsys input`, stock `/vendor/usr/keylayout`) before any mapping exists.
  Guessing from another device is forbidden by the profile model. `DeviceKeyAdapter` reports Fn chords as unsupported.

## Permissions

SableScreens requests no permissions and needs no privapp allowlist. No product-lane module requests a privileged, signature or
platform-certificate permission. Any future need is an interface request, not a grant added here.

## Display compatibility: Mini Mode evidence (non-blocking, deferred)

```text
profile titan2        : stock capture, `wm size` override with Mini on = 810x1440   (measured on retail Titan 2)
profile titan2-elite  : NOT captured
profile zinwa-q27     : NOT captured
```

The repository no longer assigns `persist.sable.displaycompat.mini_size`. DisplayCompat's Mini Mode stays a no-op until a size is
supplied through its validation screen; the enforcement backend is gated (`persist.sable.displaycompat.backend=validated`,
a manual validation switch, see IR-006). Mini Mode is not a C3B blocker.
