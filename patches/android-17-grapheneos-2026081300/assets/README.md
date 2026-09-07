# D3 branding binary assets

The Sable D2+D3 applicator expects these exact binary files in this directory:

```text
sableos_setupwizard_icon.png
sableos_boot_fallback_mask_448x605.png
```

Their validated SHA-256 values are recorded in `SHA256SUMS`:

```text
eed1b1277a77fa1f94b514585622c403c85c95191cfa3ba90edf526d02e5aea7  sableos_setupwizard_icon.png
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e  sableos_boot_fallback_mask_448x605.png
```

Before applying the source delta, verify:

```bash
cd patches/android-17-grapheneos-2026081300/assets
sha256sum -c SHA256SUMS
```

`apply_sable_branding.py` independently verifies both hashes and refuses to mutate the Android source tree if either asset is absent or does not match.

The SetupWizard icon is the 512x512 transparent Sable shield asset used by D2. The boot fallback mask is the exact 448x605 fully opaque D3 mask physically validated on Pixel 7. Do not recompress, resize, optimize, or regenerate either file while claiming the D3 reference identity; any byte change creates a new source input and requires a new artifact audit.
