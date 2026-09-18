# INFRA4 trusted runner isolation and source-storage encryption decision

INFRA4 is based on exact integrated `main` commit `7f85b522afa989e197b09d07c8f7d9f01c62e48d`. The nine
post-integration push workflows for that commit were all successful before this
deliverable was produced.

## Host storage decision

- source/build root: `/srv/data/sable-build`
- mount source: `/dev/nvme1n1p1`
- mount target: `/srv/data/sable-build`
- filesystem: `ext4`
- detected block ancestry: `/dev/nvme1n1p1 -> /dev/nvme1n1`
- encryption detector result: `FAIL_UNENCRYPTED`
- encryption decision: `DEFER_TRUSTED_RUNNER_UNTIL_ENCRYPTED`

Trusted-runner activation state:

`BLOCKED_UNTIL_ENCRYPTED`

INFRA4 does not weaken the encryption requirement. If encryption is not
cryptographically visible in the block ancestry, self-hosted execution remains
disabled.

## Trusted runner isolation policy

Current workflows remain pinned to GitHub-hosted `ubuntu-22.04`. No current
workflow may use a self-hosted runner.

A future activation change must require all of the following:

- source storage passes the committed encryption audit;
- a dedicated unprivileged runner account;
- no membership in `sudo`, `wheel`, `docker`, `lxd`, `libvirt`, or equivalent
  privilege-expanding groups;
- ephemeral, one-job runner registration;
- no persistent Actions runner service;
- no registration token or runner credential persisted in the repository;
- labels `[self-hosted, linux, x64, sable-trusted, sable-ephemeral]`;
- no untrusted pull-request or fork-originated execution;
- runner state/work directories under `/srv/data/sable-build/sableos/runner`,
  outside the Git repository.

`build/check-runner-policy.py` fails CI if self-hosted use is introduced before
a separate explicit activation change. `build/check-ci-policy.py` invokes that
gate. The runner policy, host-audit implementation, and policy checker are
included in deterministic supply-chain provenance.

## Audited current runner state

- active/configured runner detected: `False`
- runner process count: `0`
- system runner service count: `0`
- user runner service count: `0`
- runner installation marker count: `0`
- dedicated `sable-runner` account exists: `False`

This INFRA4 change does not install/register a runner, enable a runner service,
create registration credentials, change root privileges, or enable self-hosted
workflow execution.
