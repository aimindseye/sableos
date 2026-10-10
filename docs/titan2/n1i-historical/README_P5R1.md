# H1-C3 P5R1 — operator evidence manifest and explicit qualification modes

The source remains offline, read-only and observational. No device operations,
network requests, builds, commits, pushes, or merge operations occur.

## Repository qualification

From any checkout with the modules/tests installed:

```
bash tests/titan2/n1i-historical/host_qualification.sh --synthetic-only
bash tests/titan2/n1i-historical/host_qualification.sh --historical-offline --evidence-manifest /absolute/private/manifest.json
bash tests/titan2/n1i-historical/host_qualification.sh --full-host --evidence-manifest /absolute/private/manifest.json
```

`--synthetic-only` runs 66 synthetic tests without attempting to open any
historical sources or host toolchain config. `--historical-offline` adds verified
historical summary; `--full-host` also executes the N1I v1.2 selftest runner.
Do not claim historical qualification from the synthetic-only mode.

The manifest is an operator-controlled file outside Git, schema:

```
{
  "version": 1,
  "radio_logs": {
    "OCT03_N1H": "/private/path/to/oct03-radio.log",
    "OCT07_STOCK": "/private/path/to/oct07-radio.log",
    "OCT09_N1F_FAILURE": "/private/path/to/oct09-failure.log",
    "OCT09_POST_CYCLE": "/private/path/to/oct09-post-cycle.log"
  },
  "n1h_snapshots": {
    "start.connectivity.txt": "/private/path/to/start.connectivity.txt",
    "end.connectivity.txt": "/private/path/to/end.connectivity.txt",
    "start.telephony-registry.txt": "/private/path/to/start.telephony-registry.txt",
    "end.telephony-registry.txt": "/private/path/to/end.telephony-registry.txt",
    "start.carrier-config.txt": "/private/path/to/start.carrier-config.txt",
    "end.carrier-config.txt": "/private/path/to/end.carrier-config.txt"
  }
}
```

The manifest maps paths only. SHA-256 / line counts / snapshot sizes are pinned
inside the original normalizer constants and cannot be overridden by the manifest.
The original source snapshots are point-in-time observations, not proof of
continuous validated internet. Root cause UNKNOWN. DSRM selected != executed.

## Integration boundary

This patch changes four existing scripts/modules and adds one manifest loader,
one regression test module, and this README. The 14-file P3 pin is superseded
only after full ai-g732 qualification and a new exact Git manifest review.
