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

## External Reference Notes

- `EXTERNAL_LESSONS.md` — lessons from MarathonOS/Marathon Shell and resulting Sable decisions.

## Current Milestone Snapshot

```text
S1.6   PASS
S1.7A  IN PROGRESS
S1.7B  PLANNED
S1.8+  PLANNED
```

S1.7A must not be documented as complete until its frozen AIDL host seal and image reseal pass.
