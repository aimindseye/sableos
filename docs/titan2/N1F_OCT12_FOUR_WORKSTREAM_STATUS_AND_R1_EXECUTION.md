# October 12 Titan 2 execution order: LTE P0, IMS1-D P1, CW1 P2, OEM IMS P2

## Authority
Operator explicitly authorized **source mutation and device contact as needed**. This is not authority to build, reboot, change modes, flash or modify firmware. Preserve the active flashed image and dirty canonical repo; operate in an isolated Android tree only. October 11 ADB cellular enablement was temporary and failed to sustain registration.

| Lane | Status | What the existing evidence establishes | Next smallest action |
|---|---|---|---|
| **P0 LTE registration** | **OPEN_ROOT_CAUSE** | Prior GSI data teardown/rejection causes 11/13/15/114, while stock V01.00.14 control had zero cause 13 in retained capture. Earlier tray-1 stable data and IMS absent shows missing IMS alone is **not sufficient** to cause cause 13. Oct11 transient IN_SERVICE→OUT_OF_SERVICE after diagnostic ADB activation. Vendor `mtkNetworkIndication==NULL` is not a proven causal error (observed even in good window per N1I-B). | Compare **existing** Oct11 timestamps in `n1f-r3-r8m-radio-diagnostics-20261011` and prior stock/tray-1 captures before any new ADB. On an explicit later bounded device session, capture only modem rejection details, exact registration state transitions and framework/vendor callback timestamps; no radio property forcing or auto-healing. |
| **P1 IMS1-D** | **PARTIAL_STATIC / RUNTIME_UNBOUND** | Existing IMS1-A/B/C/D and D9.6 correction preserve APK/classpath methods and image-exact D1R2 `bootclasspath.pb`, `systemserverclasspath.pb` refs. D7 records 29 pinned artifact identities but doesn't establish current-image classloader/service binding. | Reuse retained protobufs/manifest and selected IMS01 module plan; decode exact bootclasspath/runtime classloader and service ownership only for the chosen derived N1F image. No new broad APK/DEX census. |
| **P2 CW1** | **PASS_COMPILE_DEX_STATIC; RUNTIME_DEFERRED** | CW1 isolated telephony-common compile and 4 DEX method definitions PASS; exact stock `invoke-super` static linkage PASS, semantics and incoming-call runtime still unknown. | Preserve warm out_cw1 and evidence; don't merge or add call-waiting patch to first radio-stability experiment. |
| **P2 OEM IMS** | **MINIMAL_ISLAND_DESIGNED; NOT_INSTALLED_IN_OCT11_RUNTIME** | `skip_mount.cfg` bypasses stock system_ext/product, making embedded `/system/system_ext` target necessary. Existing C1 `Android.bp` + product makefile already define OEM `ImsService`, 2 JARs, 3 XML configs and boot-jar location overrides. R1 source exact parent/pre-post SHA qualified. R2 five stock hashes and 56 direct NEEDED qualified; full namespace still open. | Use isolated R1 exact-source patch; qualify IMS01 source/build pins and R2 delta namespace from previously retained B2/C3A evidence before packaging. No historical D1R2 7-JAR/33-native expansion. |

## Exact R1 next mutation

The operator-validated source file at `frameworks/base/core/res/AndroidManifest.xml` has pre SHA256 `2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c` and expected one-line post SHA256 `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca`. Git pre blob `a7675341e1575039845d09c64fa22006612cca4a`. The approved one-line declaration is `<protected-broadcast android:name="com.mediatek.common.carrierexpress.operator_config_changed" />`, inserted after the existing `android.telephony.action.STK_SETUP_EVENT_LIST` declaration.

An independent no-network Python tool named `n1f_m4_r1_isolated_apply_v1.py` checks exact pre/post SHA before writing **only that manifest** with `--apply`; it refuses the known canonical Android tree and requires an isolated tree. The tool is distributed to the operator outside GitHub and does not bootstrap or mutate an Android checkout. On-disk patching does **not** authorize building or flashing. No IMS module, R2 lib or device command is included.

## Go/no-go

```text
R1_EXACT_SOURCE_PATCH=AUTHORIZED_OPERATOR_SCOPE_IN_ISOLATED_TREE_ONLY
P0_LTE_CAUSE13=NOT_ESTABLISHED_NETWORK_VS_MODEM_VS_FRAMEWORK
P1_IMS1D=STATIC_PARTIAL_RUNTIME_BINDING_PENDING
P2_CW1=COMPILED_STATIC_PASS_RUNTIME_DEFERRED
P2_OEM_IMS=DESIGN_READY_BINARY_NAMESPACE_PENDING
SOURCE_MUTATION_AUTHORIZED=YES_EXACT_R1_ISOLATED_ONLY
READONLY_DEVICE_DIAGNOSTICS_AUTHORIZED=YES_SEPARATE_TARGET_SESSION
BUILD_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```
