# C3B product first-party icon contract (D5)

Status: `C3B_PRODUCT_ICON_CONTRACT_STATUS=SOURCE_READY_CANONICAL_GATE_PENDING`. `IR_010_STATUS=OPEN_CANONICAL_GATE_PENDING`.

This is source-and-evidence only. The canonical gate `build/gates/r9-first-party-app-icon-contract.py` (SableOS
`e97ea89cbd77a53390df8a14d93eb1a36531178c`, git blob `0fb3505bcb69b9ee5ba2bfc88cbb724148947291`) is not modified or
run from this repository. It still enumerates only Panther modules; the canonical lane must wire the five product
modules below into it (IR-010) before the contract is enforced in canonical CI. Nothing here claims canonical CI.

## Language (mirrors the canonical contract tokens)

| property | value |
|---|---|
| viewport | `android:viewportWidth="256"`, `android:viewportHeight="256"` |
| tonal background | `#161C24`, rounded square path |
| foreground glyph | `#F7F9FC`, Phosphor path at scale 0.70, translate 38.4/34 (same optical scale as Panther) |
| bottom identity rail | per-app accent, `M28,226h200v6H28z` |
| glyph source | Phosphor Icons `regular`, `https://github.com/phosphor-icons/core` at `2b75f3ad12b420c9504ef05df8d2564a28f8500e`, MIT |

## Product modules (5)

| module | drawable | Phosphor glyph | accent | origin |
|---|---|---|---|---|
| Sable Setup | `ic_sable_setup` | `list-checks` | `#2BB5A0` | new Titan glyph |
| Radio Diagnostics | `ic_sable_radiodiag` | `cell-signal-high` | `#E5534B` | new Titan glyph |
| Sable Keyboard | `ic_sable_keyboard` | `keyboard` | `#E8B931` | new Titan glyph |
| Sable Camera | `ic_sable_camera` | `camera` | `#E8458F` | new Titan glyph |
| Display Compatibility | `ic_sable_displaycompat` | `frame-corners` | `#34C8E8` | new Titan glyph |

No Panther identity exists for these utilities, so none was ported or redesigned. They are new glyphs in the
same Phosphor/Sable language, not a Titan-specific replacement icon family
(`C3B_TITAN_SPECIFIC_REPLACEMENT_ICON_FAMILY_ALLOWED=NO`). The accents are chosen to differ from one another; they
were not checked against every canonical Panther accent, which the canonical lane should do when wiring IR-010.

Each `<application>` declares `android:icon` and `android:roundIcon` pointing at its drawable. SableScreens is a
prototype (`PROTOTYPE_ONLY`, `NOT_ADMITTED`) and gets no product icon.

## Provenance and reproducibility

`third_party/phosphor-icons/` holds the licence, `PROVENANCE.md`, `ICON_MANIFEST.tsv` (module, drawable, glyph,
glyph sha256, accent, origin) and the verbatim pinned glyph SVGs. `tools/gen_first_party_icons.py` regenerates the
drawables; the static gate fails if any drawable differs from the generator output.

## Static gate (this repository)

Fails when: a required module has no `android:icon` or `android:roundIcon`; the referenced drawable is missing or is not
the generator output; the viewport, background, glyph colour, scale or rail contract is violated; the Phosphor commit pin,
MIT licence text, per-glyph hash or provenance record is missing; a SableScreens manifest carries a product icon.

Markers: `C3B_FIRST_PARTY_ICON_SOURCE`, `C3B_FIRST_PARTY_ICON_LANGUAGE`, `C3B_PRODUCT_ICON_MANIFEST_WIRING`,
`C3B_PRODUCT_ICON_PROVENANCE`.

Not verified here: how the icons render on a launcher or in an image, and the Android resource compile (no SDK in the
developer lane; operator ai-g732 compiles it).
