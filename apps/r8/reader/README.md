# R8 Sable Reader qualification

Sable Reader is qualified from a pinned Vaachak Mobile checkout rather than a copied/reimplemented reader engine.

The CI gate:

1. clones `vaachak-platform/vaachak-mobile`;
2. checks out the exact SHA in `upstream.env`;
3. injects only the Sable product flavor and Sable branding;
4. removes `INTERNET` from the Sable flavor manifest for the first offline-first qualification gate;
5. runs Vaachak core tests plus Sable-flavor Android compilation/lint.

Readium, bookshelf/database, EPUB navigation, bookmarks, highlights, search, TOC, TTS, preferences and existing reader architecture remain upstream code. Network-backed sync/AI/OPDS behavior is not accepted into the first Sable image merely because those dependencies exist in the upstream source; a separate product-policy gate must hide/disable those surfaces before integration acceptance.

The currently verified manifest evidence is EPUB-oriented. TXT acceptance is not claimed by this staging gate until source/runtime evidence proves it.
