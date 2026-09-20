#!/usr/bin/env bash
# Fail-closed placeholder adapter. Mutation support is added only after physical qualification.

SABLE_DEVICE_CANONICAL=titan2
SABLE_DEVICE_EXPECTED_PRODUCT=UNQUALIFIED
SABLE_DEVICE_BUILD_SUPPORTED=NO
SABLE_DEVICE_FLASH_SUPPORTED=NO
SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=NO
SABLE_DEVICE_DEFAULT_ACCEPTANCE_SUITE=none

sable_device_build() {
  echo "SABLE_DEVICE_BUILD=BLOCKED_UNQUALIFIED device=titan2" >&2
  return 78
}

sable_device_accept() {
  echo "SABLE_DEVICE_ACCEPT=BLOCKED_UNQUALIFIED device=titan2" >&2
  return 78
}
