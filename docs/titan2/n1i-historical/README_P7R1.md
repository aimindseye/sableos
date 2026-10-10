# H1-C3 P7R1 manifest security boundary

P7R1 requires an absolute operator-supplied manifest outside Git with exact file mode 0600. The loader checks every component of the manifest and evidence paths with lstat and rejects symlinks, absent/non-regular files, parent traversal, and invalid schema. Source SHA-256 and line-count checks remain pinned in the historical normalizers. Existing evidence itself remains read-only; no device commands are executed.

`host_qualification.sh --synthetic-only` requires no manifest and runs synthetic tests. `--historical-offline --evidence-manifest /absolute/path` and `--full-host --evidence-manifest /absolute/path` validate the manifest before synthetic tests and historical replay. `--full-host` also runs the N1I v1.2 suite. Do not interpret synthetic results as historical replay or production qualification.

This validates filesystem paths at opening time, not against malicious concurrent filesystem replacement. Use a trusted operator-controlled offline host and immutable retained evidence storage. No raw historical inputs or private manifests belong in Git. Commit, push, merge and device operations remain separately authorized.
