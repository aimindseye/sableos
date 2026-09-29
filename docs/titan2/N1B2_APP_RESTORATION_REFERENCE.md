# N1B2 app restoration reference contract

This contract is the pre-code guard for restoring missing Titan2/N1B2 app modules.

It exists because Titan2 app work must not create device-specific app forks or free-floating new apps when Panther/current Sable app evidence and platform_sable design contracts already exist.

## Source policy

The restoration sources are, in order:

1. Existing SableOS common/Panther app modules under `apps/r8/android`.
2. Historical Panther/current app evidence and artifacts where the module is not currently in the Gradle graph.
3. platform_sable capability, portability, app reuse, and UX/design documents.

Only after those sources are checked may a restoration PR add missing code. If no usable prior source exists, the PR must say that explicitly and still follow the common app/profile-driven architecture.

## platform_sable basis

platform_sable states that Panther is the frozen reference evidence and that Titan 2 / Titan 2 Elite should consume the same common app source/artifacts where substrate compatibility permits. Keyboard-first work changes focus, layout, and input behavior; it does not create Titan2 ownership of common applications.

The primary upstream policy file is:

```text
docs/SABLE_APP_REUSE_AND_INTEGRATION_PLAN.md
```

The app restoration manifest is:

```text
docs/titan2/N1B2_APP_RESTORATION_REFERENCE.tsv
```

## Rules

- Existing current modules such as Calculator, Games, Media, Hub, Weather, and Calendar are the first app references.
- Hub is the current messages-adjacent reference and must be reviewed before adding a standalone Messages module.
- Mail, Reader, and Text Reader are accepted common app references in platform_sable but are not proven current Gradle modules in PR202; restoration must locate prior source/artifact evidence or document its absence.
- People/Contacts, Browser/WebView, Settings, Command/Search, Phone, and Quick Settings/SystemUI must use platform_sable UX/design sources and common app patterns before implementation.
- SystemUI is not a normal APK restoration and requires separate AOSP/platform review.
- Device-specific behavior must flow through profiles/capabilities/adapters, not retail model names or Titan2-only app forks.

## Gate

```text
build/gates/n1b2-app-restoration-reference-contract.sh
```

Expected marker:

```text
N1B2_APP_RESTORATION_REFERENCE=PASS
```

This gate does not build, contact a device, run adb or fastboot, flash, authorize public release, or authorize production signing.