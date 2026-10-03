# D6: RadioDiag and DisplayCompat source hardening

Source-only hardening of two existing product modules. Nothing here crosses into canonical radio, platform or enforcement ownership, and
nothing is validated on a device.

```text
D6_RADIODIAG_READ_ONLY=YES
D6_RADIODIAG_IMS_REGISTRATION=NOT_VISIBLE
D6_RADIODIAG_PRIVILEGED_PERMISSIONS=NONE
D6_RADIODIAG_EVIDENCE_LEVEL=PUBLIC_READ_ONLY_APP_STATE
D6_DISPLAYCOMPAT_FAIL_CLOSED=YES
D6_DISPLAYCOMPAT_STORED_IS_NOT_ENFORCED=YES
D6_DISPLAYCOMPAT_STRONGEST_CLAIM=PLATFORM_CALL_ACCEPTED_UNVERIFIED
D6_DISPLAYCOMPAT_MINI_MODE_IMPLEMENTED=NO
D6_DISPLAYCOMPAT_NEW_HIDDEN_API=NO
D6_DEPENDENCY_DELTA=NONE
D6_DEVICE_RUNTIME_VALIDATED=NO
IR_006_STATUS=OPEN_CANONICAL
IR_007_STATUS=OPEN_CANONICAL
KL_013_STATUS=OPEN_CANONICAL
KL_015_STATUS=OPEN_CANONICAL
KL_023_STATUS=OPEN_CANONICAL
```

## RadioDiag

- Every read has an explicit state: value, needs permission, unavailable, not supported or unknown. A value that could not be read is never
  shown as data, and a failed package query is never reported as a missing package.
- A missing `TelephonyManager` (no telephony service) is a reported state and no longer a crash path.
- Platform integer constants (SIM state, network type, data state) are named in a pure, tested table; an unrecognised number is shown as such.
- Every report value is redacted, not only properties, and every report ends with a fixed limits block: evidence level, `ims registration:
  NOT_VISIBLE` with IR-007, and `canonical radio evidence: NOT_PROVIDED_BY_THIS_APP`.
- Cross-source consistency notes flag combinations that cannot all be true (a telephony sub-feature without `telephony`, or `com.android.phone`
  present or missing against the feature flag). A note means the sources disagree or one is hidden, not that the radio is broken.
- Blank properties are reported as unset or unreadable, because the hidden-API read (IR-001) cannot tell them apart.
- Only the existing public, read-only sources are used. The single permission stays `READ_BASIC_PHONE_STATE` (normal). No IMS registration, APN,
  CarrierConfig, QNS/IWLAN, modem, telephony-framework or SELinux-radio change, and no vendor or stock telephony binary.

## DisplayCompat

- The backend is fail-closed: the gate property must be exactly `validated`, otherwise every request is a no-op. The controller exposes the
  availability and the UI always shows it.
- There is no "enforced" state. A save reports one of: native (nothing to enforce), not enforced because the backend is closed, not enforced
  because the profile or platform is unsupported (with the reason), or platform call accepted and unverified. Stored is never worded as applied.
- A save is checked end to end: an invalid package name is refused, the write is read back before the backend is called, a store that forgets a
  write or throws is reported as not saved, and a backend that throws is reported as not enforced.
- Reset reports a platform override that could not be cleared, and reset-all lists those apps while still clearing the store.
- A stored profile that is no longer allowed for the app (it became a keyboard, the launcher, an authenticator) is not effective and is shown as
  ignored until saved or reset.
- The codec distrusts a payload with an unknown profile id, drops an out-of-range ratio and rejects a Custom profile without a usable ratio.
- Empty and no-match states of the app list are explicit. Mini Mode is not implemented and is never reported as applied; no new hidden or
  private API, SystemUI/Settings/framework change or privilege is added.

## Ownership

IR-006, IR-007, KL-013, KL-015 and KL-023 remain OPEN and canonical-owned. KL-031 records that the Android glue changed here is verified only by
pure-core JVM tests in the developer lane; Android compile and strict offline qualification belong to the operator.
