# PR342 A2C: operator authorizes exactly six N1C partition streaming comparisons

Date 2026-10-14. Existing A2B/A2C separate read-only host qualification lane. PR remains OPEN/DRAFT/UNMERGED. No production build, hybrid super assembly, device contact, reboot, restore, or flash.

## Actual ai-g732 A2C metadata outcome

User verified sealed A2C V1 ZIP SHA256 `167c7aee57d046f30bbf683f5c0f4d62bf429cf223c898c7014ae028849d15fc` and all eight internal members. Python AST3/Bash syntax PASS and 32/32 hermetic regressions PASS in 0.098 seconds. Real ai-g732 `--preflight` returned `PASS_A2C_METADATA_AND_EXACT_SIX_PATHS_NO_PARTITION_BYTES`, `no_partition_bytes_read=true`, six file count 6, six source bytes available to stream 3,446,366,208 and corresponding sparse extent bytes 3,446,366,208. `stock_reference_to_oct03_live_match=UNBOUND`. This is a real fixed-path metadata pass, NOT content equivalence.

## Exact authorization newly granted

User stated `I authorize.` immediately before the sealed package + actual A2C read-only metadata preflight transcript. This follows the preceding request for specific additional permission to stream the six N1C stock-reference source images (exact combined size 3,446,366,208 bytes) and their matching logical extents in the N1C stock sparse super (another 3,446,366,208 bytes), comparing every block and hashing exact pinned SHA256. Interpret as approval of precisely that one read-only verification, not broader Stage B authority. Expected source root is the existing TEE14-large-reference six files; expected one sparse super is `titan2-stock-v010014-super-restore-r1c.sparse.img` under the fixed N1C restore root. A2C stops on sparse DONT_CARE sections and does not normalize unknown payloads to zero.

After independent ZIP hash validation and from the already extracted copy, authorized exact operator invocation:

```bash
bash ./n1f_p342_a2c_one_command_v1.sh \
  --verify \
  --authorize-a2c-six-partition-streaming
```

Wrapper checks SHA8, AST3, Bash syntax, 32 unit tests, zero-host I/O plan, then the independently operator-approved streaming mode. Exact A2B LP reader remains pinned unchanged SHA256 `ced1c4a48327ae322b5cd0f92fce7ad58016d0bfcf7c1e82844c8ac0d39e925a`. Source and sparse-super files are read-only, no partial image output, raw super reconstruction, network, fastboot, ADB, build or flash. If refusal or nonzero: preserve output, do not retry blindly.

Assistant-container fresh extraction confirmed exact ZIP SHA and CRC, eight inner SHA256 pins, AST3 and bash -n, 32/32 hermetic tests under BOTH umask077/022, and `--plan` integrity paths; **no actual ai-g732 multi-GB verification run has been received**. The expected eventual PASS marker is `PASS_A2C_N1C_SIX_REFERENCE_TO_SUPER_BYTES_NOT_OCT03_MATCHED`. Even a PASS means HISTORICAL N1C stock-source/super byte equivalence, NOT same-session Oct03 live-partition equivalence, AVB, stock restore, IMS G3, or a flash-qualified A1X-derived complete super.

```text
A2C_METADATA_REAL_AI_G732=PASS
A2C_SIX_PARTITION_STREAMING_AUTHORIZED=YES_EXACT_ONE_RUN
A2C_FULL_STREAMING_RESULT=PENDING
OCT03_LIVE_COMPANION_IDENTITIES=UNBOUND
MATCHED_AVB_RESTORE=UNQUALIFIED
HYBRID_SUPER_A1X_BUILT=NO
DEVICE=NO FLASH=NO
```