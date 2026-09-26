# Titan 2 N0 artifact decision

Status: **undecided — experiment required**

Titan 2 N0 must not inherit Panther's target-files/full-image contract. The
first artifact must be selected from Titan evidence.

## Candidate artifact kinds

### 1. gsi-system-image

Use only if stock kernel/vendor/ODM/firmware can boot a Sable system image with a
bounded AVB strategy and an explicit userdata policy.

Required proof:

```text
LP_FREE_SPACE_OK=TODO
AVB_STRATEGY_OK=TODO
VENDOR_COMPATIBILITY_OK=TODO
RESTORE_PATH_OK=TODO
USERDATA_POLICY_OK=TODO
```

### 2. generated-super-image

Use if dynamic-partition sizing or multiple logical partitions make a single
system image insufficient.

Required proof:

```text
SUPER_METADATA_CAPTURED=TODO
LOGICAL_PARTITION_LAYOUT_DECIDED=TODO
RESTORE_SUPER_OR_PARTITIONS_OK=TODO
FASTBOOTD_FLASH_PLAN_OK=TODO
```

### 3. bounded system/product/system_ext bundle

Use if Sable userspace needs a bounded product/system_ext payload while
preserving the stock kernel/vendor/ODM basis.

Required proof:

```text
PRODUCT_SYSTEM_EXT_REQUIREMENTS_KNOWN=TODO
BUNDLE_PARTITION_BOUNDARY_OK=TODO
ARTIFACT_REGISTRY_KIND_SUPPORTED=TODO
RESTORE_PATH_OK=TODO
```

## Current decision

```text
TITAN2_N0_ARTIFACT_KIND=UNDECIDED
BUILD_IMAGE_ENABLED=NO
FLASH_ENABLED=NO
E3_DEPLOYMENT_ENABLED=NO
```

Do not run first E3 deployment until this file is updated with the chosen
artifact kind and supporting evidence.
