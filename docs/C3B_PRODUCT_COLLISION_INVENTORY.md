# Collision inventory against canonical `aimindseye/sableos`

Checked by comparing every tracked path in this repository with `aimindseye/sableos` at
`e97ea89cbd77a53390df8a14d93eb1a36531178c`.

Exact file-path collisions (3):

| path | action |
|---|---|
| `.gitignore` | not staged (`DO_NOT_STAGE`) |
| `README.md` | not staged (`DO_NOT_STAGE`) |
| `build/titan2/capture-n1b2-cellular-runtime.sh` | renamed in D1a to `build/titan2/capture-c3b-cellular-runtime-reference.sh`, marked `REFERENCE_ONLY_NOT_CANONICAL_CAPTURE`, outputs renamed to `REFERENCE_*` |

Shared directory families (no shared files): `build/titan2/`, `docs/`. The `product/` tree and `vendor/sable/titan2` paths were
retired in D1b and must stay absent; see `docs/C3B_PRODUCT_RETIRED_PATHS.tsv` and `docs/C3B_PRODUCT_PATH_OWNERSHIP.tsv`.

Re-run the check against the current canonical head before every handoff:

```bash
git ls-files | while read f; do [ -e "<sableos-checkout>/$f" ] && echo "$f"; done
```
