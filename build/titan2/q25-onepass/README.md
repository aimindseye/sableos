# Titan 2 Track B: consolidated Q25 source owner candidates (2026-10-20)

This directory holds **16 byte-identical original framework implementation patches** from `aimindseye/zinwaq25-sableos`, branch `feature/sable-start-bb10-layout-20261019`, copied once to this current PR#346 source branch. They are not applied to the selected `/srv/sable-build/workspaces/titan2-track-b/android` tree or proven Android16-compatible.

| Owner | Number | Admission |
|---|---:|---|
| `frameworks/base` SystemUI/Keyguard/notification light | 5 | exact scratch context review, framework security review |
| `packages/apps/DocumentsUI` Files | 2 | source-context review, DocumentsUI operation/UI review |
| `packages/apps/Jelly` Browser | 2 | source-context review, **verify installed Browser owner** |
| `packages/apps/Settings` | 4 | two keyboard/Sable settings review, **two Mobile Manager/AppLock held until privileged enforcement** |
| `packages/apps/SetupWizard` | 2 | source-context review, **verify this Lineage owner actually exists in Android16** |
| `packages/apps/Dialer` | 1 | source-context review, preserve Telecom/IMS ownership |

**Selected design ownership for Track B source convergence:** the platform_sable three-page contract requires **SableLauncher as HOME** and **Launcher3QuickStep retained for Recents only**. This supersedes the older Track B source-staging assumption that Launcher3QuickStep stays HOME. The historical Q25 Launcher3 `0002` patch is **not applied** to Titan2 Android16 merely by declaring this contract. The selected Android16 Quickstep HOME intent, SableLauncher Soong module, product installation, and role/default-state must all be integrated together and checked during the canonical `sable.sh titan2 TB2 build`. Until then the checkout is not a completed Track B product.

**Important security restriction:** The two Settings Mobile Manager patches preserve already authored Q25 source, including UI for App Lock. They are **not enabled** merely by being in this tree: an actual privileged launch gate, user/profile enforcement, Freezer, Vault, and Dual/Private policy must be implemented and qualified first. Do not mark them DONE from a Settings toggle.

**One-pass local source-context operator** is included in the separately sealed `TB2_Q25_ONEPASS_REUSE_INTEGRATION_V1.zip` handoff, SHA-256 `eceade82ea79f492c03d87991fb8a2bef4712d7b8676c50f3cdb1d808b726f02`. Operator uses only `git` and Python 3, reads these exact pinned patches from existing Git blob objects without branch checkout, and tests dependent patch application in an ephemeral, bounded copy of touched paths. It never applies, builds, flashes, signs, resets or reverts the active Android tree.

**Status is Q25 original patch SOURCE_REUSE_CANDIDATE, not Q25 complete.** Remaining: real Android16 target adaptation/compilation, selected full product image, SystemUI/Settings/Browser/Files/Setup/Dialer UI integration; actual privileged enforcement; Q25 Camera QuickReview/Contacts/backend; permanent Native34 HOME runtime; READ_SMS hard-restricted selected-image grant; IMS FLOSS/OEM provider selection, new-image G1/G2/G3, and physical radio qualification. PR#342 historical OEM evidence remains independent, PR#344 current custody, PR#345 Sonar CI independent. No canonical `sable.sh` build was performed.
