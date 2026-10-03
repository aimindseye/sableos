# Titan 2 C3B E2 canonical product template

This directory is the canonical E2 product template. It is staged into
`vendor/sable/titan2` inside the isolated Titan 2 C3B Android workspace only by
`build/titan2/stage-n1d-c3b-e2-product-composition.sh`.

The product is a thin wrapper around the already generated and qualified E1
Treble product:

```text
device/phh/treble/treble_arm64_bvN.mk
        ↓ inherit
vendor/sable/titan2/sable_titan2.mk
        ↓
sable_titan2-bp4a-userdebug
```

The earlier direct handcrafted `sable_titan2_n1d_arm64` /
`vendor/sable/n1d` product remains retired.

Five source-qualified Sable apps are included as non-privileged product apps.
Their APKs are generated offline from the canonical admitted Gradle source,
remain unsigned in the source-bound artifact bundle, and are signed by Soong
with `default_dev_cert: true` for the engineering userdebug image. No
presigned repository APK, platform certificate, privileged app, stock-app
override, default-IME provisioning, Setup Wizard ownership, device contact,
flash, production signing, target-files/OTA or release authority is introduced
by this template.
