# INFRA5 deferred trusted-runner activation decision

Date: 2026-09-18

## Decision

INFRA5 is intentionally deferred and is not an active development milestone.

SableOS will continue to use GitHub-hosted CI for normal source/application qualification. The `ai-g732` build host remains a development/build machine and is **not** accepted as a trusted self-hosted release runner while its Sable source/build storage is unencrypted.

The existing INFRA4 fail-closed controls remain authoritative:

```text
SOURCE_STORAGE_ENCRYPTED=NO
TRUSTED_SELF_HOSTED_RUNNER=DISABLED
INFRA5_STATUS=DEFERRED_NON_BLOCKING
```

This is a scheduling decision, not a security exception. INFRA4 must not be weakened to make an unencrypted host appear trusted.

## Rationale

The current project priority is application/product development and build qualification. For the present hobby/development stage, activating a hardened self-hosted runner would add storage migration, LUKS lifecycle, runner isolation, credential-handling and unattended-host operations without being required for current R8 source qualification.

Those controls become materially more valuable when SableOS begins handling production signing keys, private release artifacts, unattended trusted CI credentials, or release-candidate generation.

## Revisit trigger

INFRA5 should be reopened as part of release/security hardening before production release-candidate signing or trusted unattended build execution.

The future activation gate remains:

1. encrypt the Sable source/build storage with a cryptographically visible dm-crypt/LUKS layer;
2. pass `build/audit-trusted-runner-host.py` with `PASS_ENCRYPTED`;
3. create a dedicated unprivileged runner identity with no privilege-expanding group membership;
4. use ephemeral one-job runner registration with no persistent runner service;
5. keep runner credentials and state outside the Git repository;
6. allow only explicitly trusted workflow/event surfaces;
7. separately qualify production signing/key custody and release provenance.

Production signing, trusted-runner activation and build-host encryption should be reviewed together so the project does not create a partially hardened release path.

## Current development consequence

No current R8 work is blocked by INFRA5.

The active handoff is:

```text
R8 application source implementation/build preparation
    -> standalone qualification and artifact freeze
    -> product integration gates
    -> Panther/Titan development qualification
    -> release/security hardening
         -> INFRA5 encrypted trusted runner
         -> production signing/key custody
         -> signed release/OTA closure
```

