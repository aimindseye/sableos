# Actual Track B IMS admission and Q25 design-receipt reconciliation (21 Oct 2026)

**Owner-provided original archive:** `TB2_EXISTING_IMS_ADMISSION_RECEIPTS_20261021.tar.gz`, SHA256 `5edce52944c81647d8757652decd82e42df7f12ca9534f62670bb53cb7ad70b3`; two safe JSON members, 6,363 and 12,146 bytes. Archive SHA-256 and JSON parsing independently passed. No source mutation, build, device contact or flash.

## Do not redo these completed findings

Both reports share `schema=TB2_Q25_IMS_CONFORMANCE_GATE_V1`, status `HOLD_IMS_DESIGN_AND_IMAGE_ADMISSION_OPEN`, `ims_status=OPEN_PROVIDER_SIGNATURE_SERVICE_PRIVAPP_OVERLAY_CLASSLOADER_VENDOR_ABI_AND_DEVICE_REGISTRATION`, and `radio_status=OPEN_MODEM_CAPABILITY_TRANSACTION_AND_DATA_SIM_RUNTIME`. They each pin the 18,061,116-byte Launcher3QuickStep APK to SHA256 `5d97ac40e8d62e03ed81bf85acc4d0359359ecad577ce90732c7e64fb10f137b`; code definitions for `NativeTaskFramePolicy` and `AllAppsPrivacyFilters` were found in the compiled artifact, but **runtime behavior was not tested**. Reuse earlier Native34/NextSlice APK and actual Phase12/13 native compile receipts without recompiling for evidence.

The first report (2026-10-20 16:32 UTC) could **not locate the exact** `DESIGN_CONFORMANCE_Q25.md`; its reason explicitly prohibits substituting the Q25 gap review. The second report (16:34 UTC) **did** read `/home/mindseye73/Downloads/DESIGN_CONFORMANCE_Q25.md`, SHA256 **`741c7f3fdd31c8740372738281da6c407d4b9f39cd1ec2448248351ca38bdae2`**, in **read-only inventory** mode. Its `checked_mentions=[]` means **zero verified finished items from this tool**, not that no Q25 code exists. The document's headings are at lines 1, 9, 21, 49 and 57. Preserve original file for source-to-owner adaptation rather than rerunning the inventory.

## Exact Q25 artifact items reported Partial (18)

This table retains the findings from the **2026-10-20 source document**, which concerns Q25; it does **not** certify those capabilities in the actual Android 16 Titan2 product.

| Artifact owner in original design review | Reported missing or conflicting items |
|---|---|
| `all-apps-titan2` | Privacy filter chips, slot picker, permission match group |
| `command-titan2` | Best-match row, per-result actions, locked state, global Alt+Space |
| `hub-titan2` | Sub-filters, slash search, Menu actions sheet, counts-only private state |
| `messages-conversation-titan2` | End/Esc latest, PageUp, slash thread search, new-message pill |
| `phone-dialer-titan2` | Letter-to-digits dial-screen not verified; recents privacy |
| `contacts-people-titan2` | Route subtitle, Hub route chip, locked states |
| `lockscreen-titan2` | Count row, private card, Locked label, E emergency hint (E types 2 on Q25; device-specific) |
| `quick-settings-titan2` | Hub summary, hint line, slash search; design conflict 2-column versus 3-column layout; keyboard light tile dropped because firmware ignores phone |
| `settings-titan2 / -approved` | Keyboard & input and Diagnostics top-level rows, consistent focus ring; Diagnostics placement conflict |
| `setup-wizard-titan2` | Step counter, Wi-Fi Alt/Sym hint, navy cards; restore remains live despite fail-closed design |
| `mobile-manager-app-controls-titan2` | App Control Center, Freezer, Student mode; placement under Apps rather than Privacy |
| `private-space-dual-work-titan2` | Secure Vault, Dual Apps disabled, stored-only unenforced App Lock |
| `connectivity-otg-nfc-cast-titan2` | Connectivity card hub; display-compat profile stored but not applied |
| `camera-capture-titan2` | Z zoom, R RAW, accidental trackpad changes, Aperture default, focus reticle and hint dock |
| `browser-webview-titan2` | T/B/L shortcuts conflict; tab close/switch, start cards, reader mode |
| `files-documents-titan2` | Single-letter navigation, 3-pane preview and J/K/T/E/V/F keys |
| `mail-calendar-titan2` | Calendar week view, NOW line, C/T/V/J/K/R keys |
| `media-gallery-titan2` | Key labels, caption strip, S=Share conflict |

A nineteenth `pending_mentions` line is only the glossary defining **Done, Partial, Missing, N/A, Conflict**, not a nineteenth incomplete artifact. The report does not itself read the source implementations or prove all 18 remain missing on the current Track B branch. It is an integration backlog, **not** a set of individual gates to rerun. Q25-only hardware/kernel/partition changes are explicitly nonportable.

## IMS and selected image: what the reports can and cannot say

- They scanned **only** `tb2-q25-nextslice-module-out-20261020T152037Z/.../system/system_ext/priv-app` for *named IMS APK candidates* and found none. They did **not** scan every installed path in the active `out-integrated-13-floss-ims` engineering output, so this is **not evidence of no PhhIms on the selected product**.
- `system_image.present=false` applies to that NextSlice output path. It does **not contradict** existence of earlier separately named Track B engineering image directories.
- `signer_status=UNKNOWN_TOOL_NOT_INSTALLED_IN_PRIOR_RECEIPT` is not signer failure or success.
- Neither report checks actual service binding, selected privileged grants, Android 16 IMS classloader/JAR/ELF/linker namespace G1–G3, default data SIM/modem transactions, or live registration/VoLTE.
- The later actual product supplement independently shows active `device/phh/treble/rom.mk` inherits `vendor/sable/trackb13ims/track-b.mk`, selecting **PhhIms/PhhImsOverlay/Iwlan/QualifiedNetworksService** and PHH privilege XML. This source selection is separate evidence; it does **not** upgrade the October 20 reports to an IMS runtime PASS.
- The actual rebuilt 13-app source graph uses `TB2Sable*` imports, not a second `SableTB2*` set; this was resolved from the owner-provided makefile and Soong definitions, not from these two JSON receipts.

## One Track B source-convergence disposition

**Reused/established:** compiled Native34/NextSlice class membership; exact Q25 design artifact document identity and 18 historical partial findings; confirmed original IMS provider/admission gaps; no need to rerun these admission scripts.

**Still source implementation:** bind `DESIGN_CONFORMANCE_Q25.md` artifacts to actual Android 16 SystemUI/Launcher3/Settings/Contacts/Phone/Setup/Browser/Files and Sable app owners; avoid Q25-only overlays, Lineage Jelly and SetupWizard path assumptions. Finish one coherent SableLauncher HOME + Quickstep RECENTS-only runtime policy, real privileged AppLock/Freezer/Vault/Private/Dual profile enforcement, restricted SMS grant/role, and installed product app graph. Reuse actual selected FLOSS source and existing 13 APKs, not parallel imported graphs.

**Still system/radio validation:** built effective selected image, signer/UID/permission service installation, telephony G1–G3, SIM1/SIM2 and VoLTE after a separately authorized build/device phase.

**Status:** `SOURCE_REPORTS_REUSED`, `18_Q25_PARTIAL_ITEMS_KNOWN`, `IMS_ADMISSION_OPEN`, `Q25_ANDROID16_INTEGRATION_NOT_COMPLETE`, `IMAGE_OR_FLASH_NOT_AUTHORIZED`.
