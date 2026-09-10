# SableOS maintenance tools

`SABLE_DISK_SPACE_AUDIT.py` is a read-only bounded disk-space inventory. It reports known SableOS build outputs, historical workspaces, caches, canonical target-files archives, and direct Sable/Panther evidence directories under `/tmp`.

It performs no deletion, truncation, movement, compression, cleanup, or device operation. Cleanup requires a later exact-path review and separate authorization.
