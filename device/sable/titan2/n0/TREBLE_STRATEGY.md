# Titan 2 N0_A16 Treble strategy

Status: **accepted for build-target planning**

## Decision

Titan 2 enters SableOS through the Treble portability lane.

```text
DEVICE=titan2
SABLE_RELEASE=R10
TITAN_RELEASE_ID=N0_A16
ANDROID_RELEASE=16
PLATFORM_SDK=36
ARTIFACT_KIND=gsi-system-image
FIRST_SUBSTRATE=AOSP16_CLEAN_GSI
RESTLESSOS_ROLE=REFERENCE_AND_FUTURE_FORK
RESTLESSOS_FIRST_BOOT_DEPENDENCY=NO
```

## RestlessOS handling

RestlessOS is not the first N0 substrate. It becomes relevant after the clean
AOSP16 system image exists and has been compared against stock-vendor behavior.

Planned public fork:

```text
sableos-project/treble_restlessos
```

Branch model:

```text
upstream/android-16.2
upstream/android-17.0
sable/android-16.2
sable/android-17.0
sable/titan2-n0-a16
```

## Build order

```text
1. Qualify AOSP android-16.0.0_r4 / gsi_arm64-userdebug.
2. Build Sable-owned system.img from source.
3. Register output identity and evidence.
4. Run E3 artifact preflight.
5. Only after E3, decide whether deployment is authorized.
6. Compare RestlessOS android-16.2 as a compatibility reference.
```

## Non-goals

- no prebuilt RestlessOS image as a Sable release artifact;
- no inherited GrapheneOS/RestlessOS security claim;
- no flash authorization from a successful build;
- no Pixel Android latest-version requirement before stock vendor compatibility
  is proven.
