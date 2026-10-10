N1I H1-C2B — OFFLINE DSRM / PACKET-SERVICE FIELD REPAIR

Scope: read only exact historical radio-log and N1H snapshot sources;
no network, device, ADB, flash, source checkout or evidence writes.

Usage:
 python3 -B -m unittest -v test_n1i_h1b2 test_n1i_h1b6 test_n1i_h1c1 test_n1i_h1c2 test_n1i_h1c2b
 python3 -B n1i_h1c2b.py --summary-only

The H1-C2B classifier distinguishes:
 - getRecoveryAction: RECOVERY_ACTION_GET_DATA_CALL_LIST => selection log
 - lastaction=RECOVERY_ACTION_GET_DATA_CALL_LIST => status report, NOT selection
 - other GET_DATA_CALL_LIST token hits => ambiguous, NOT selection
 - handlePsInd/handlePsNetworkStateChanged explicit reject_cause fields, even zero
 - SST reject fields, separately and uncorrelated

No recovery execution is established. PS indication fields (including repeated or
zero values) are not proof of distinct rejection events, default-data subscription,
network cause, or complete reject chronology. The post-cycle file shares a prefix;
its new lines must never replay that shared prefix as independent evidence.

Known bounded source-local October 9 result on pinned post-cycle log:
  original prefix token sightings 6 = selection 4 + status 2 + ambiguous 0
  post-cycle continuation token sightings 3 = selection 3 + status 0
  failure prefix PS nonzero field observations in line order:
    line 6588 -> 15; 6861 -> 13; 7053 -> 11; 7314 -> 13
  continuation PS nonzero field at line 7858 -> 114
No claim that these constitute a completed network rejection sequence.

IMPORTANT: Full host historical qualification must verify all 4 source hashes,
6 N1H snapshot hashes, baseline H1-B2/B6/C1/C2 behavior, and C2B tests.
The full merged 953-test N1I v1.2 suite remains a separate gate.
