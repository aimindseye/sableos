# SableOS Documentation Index

## Architecture

- `ARCHITECTURE.md` — platform layering, power path, privilege placement, device separation.
- `SECURITY_MODEL.md` — trust boundaries, IPC policy, SELinux/service-manager rules.
- `adr/0001-mobile-ux-with-strict-privilege-separation.md` — decision record separating UX from privilege.

## Planning

- `ROADMAP.md` — completed, current and planned milestones.

## Engineering / Release

- `ENGINEERING_PRINCIPLES.md` — measurement, architecture correction, negative testing, recovery discipline.
- `RELEASE_VALIDATION.md` — build, image, AVB, flashing, runtime and slot-closure gates.
- `S1_7_VALIDATION.md` — frozen Power AIDL V1 source/image/device/runtime seal and physical acceptance record.

## External Reference Notes

- `EXTERNAL_LESSONS.md` — lessons from MarathonOS/Marathon Shell and resulting Sable decisions.

## Current Milestone Snapshot

```text
S1.6   PASS
S1.7A  PASS
S1.7B  PASS
S1.7   PASS / FROZEN
S1.8+  PLANNED
```

S1.7 closed with frozen AIDL V1, dedicated least-privilege client authorization, verified unauthorized-call blocking, physical callback-to-AIDL sequence correlation, natural slot-A success, and preserved successful slot-B fallback. See `S1_7_VALIDATION.md` for the exact seals.
