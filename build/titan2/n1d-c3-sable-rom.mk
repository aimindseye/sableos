# SableOS N1D configuration inherited by the pinned TrebleDroid generator.
#
# Keep this file intentionally minimal. device/phh/treble/base.mk is treated as
# a compatibility substrate for compile/boot discovery, not as Sable runtime
# policy. Runtime patch admission remains separate and deny-by-default.

# Matches the known-good Restless build's image-size optimization.
WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := true
