#!/usr/bin/env bash
set -euo pipefail
E5A=""; CAP=""; PLAN=""; OUT=""
EXPECTED_C3A_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
EXPECTED_C3A_BYTES=3146977280
EXPECTED_STOCK_FINGERPRINT="Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys"
EXPECTED_STOCK_INCREMENTAL="V01.00.14"
EXPECTED_SLOT="a"
EXPECTED_SUPER_BYTES=9663676416
while (($#)); do
  case "$1" in
    --e5a-json) E5A="$2"; shift 2;;
    --capacity-json) CAP="$2"; shift 2;;
    --offline-plan) PLAN="$2"; shift 2;;
    --output-json) OUT="$2"; shift 2;;
    *) echo "C3A_LIVE_QUALIFIER=FAIL_UNKNOWN_ARG" >&2; exit 64;;
  esac
done
for f in "$E5A" "$CAP" "$PLAN"; do [[ -f "$f" ]] || exit 64; done
[[ -n "$OUT" ]] || exit 64
python3 - "$E5A" "$CAP" "$PLAN" "$OUT" "$EXPECTED_C3A_SHA256" "$EXPECTED_C3A_BYTES" "$EXPECTED_STOCK_FINGERPRINT" "$EXPECTED_STOCK_INCREMENTAL" "$EXPECTED_SLOT" "$EXPECTED_SUPER_BYTES" <<'PY'
import json,pathlib,sys
e=json.loads(pathlib.Path(sys.argv[1]).read_text())
c=json.loads(pathlib.Path(sys.argv[2]).read_text())
expected_sha=sys.argv[5]; expected_bytes=int(sys.argv[6]); expected_fp=sys.argv[7]; expected_inc=sys.argv[8]; expected_slot=sys.argv[9]; expected_super=int(sys.argv[10])
p={}
for x in pathlib.Path(sys.argv[3]).read_text().splitlines():
    if x and not x.startswith("#") and "=" in x:
        k,v=x.split("=",1); p[k]=v
f=e.get("fastbootd") or {}; s=e.get("stock") or {}; cows=c.get("active_cow_partitions") or {}
checks={
"OFFLINE_PLAN_STATE":p.get("C3A_V010014_CONTROL_PLAN")=="PREPARED_NO_WRITE",
"C3A_SHA":e.get("sealed_system_sha256")==expected_sha,
"C3A_BYTES":int(e.get("sealed_system_bytes",0) or 0)==expected_bytes,
"E5A_CLEAN_PASS":e.get("final_state")=="PASS_REVIEW_READY",
"DEVICE_BINDING":e.get("device_binding_verified") is True,
"STOCK_FP":s.get("fingerprint")==expected_fp,
"STOCK_INC":s.get("incremental")==expected_inc,
"SLOT_A":f.get("current_slot")==expected_slot,
"FASTBOOTD":f.get("is_userspace")=="yes",
"UNLOCKED":f.get("unlocked")=="yes",
"SNAPSHOT_NONE":e.get("snapshot_update_review")=="PASS_IDLE_OR_NONE",
"SUPER_BYTES":int(f.get("super_bytes",0) or 0)==expected_super,
"ALLOCATION_COMPLETE":f.get("allocation_complete") is True,
"E5A_CAPACITY":f.get("capacity_safe") is True,
"TARGET_BYTES":int(f.get("planned_system_target_bytes",0) or 0)==expected_bytes,
"TARGET_SYSTEM_A":c.get("target_system_partition")=="system_a",
"NO_SLOT_SWITCH":c.get("slot_policy")=="KEEP_CURRENT_SLOT_NO_SLOT_SWITCH",
"ACTIVE_COW_COUNT_ZERO":isinstance(cows,dict) and len(cows)==0,
"NO_COW_CLEANUP":c.get("cow_cleanup_policy")=="NO_COW_CLEANUP_NEEDED",
"GROUP_CAPACITY":c.get("active_group_capacity_safe") is True,
"SUPER_CAPACITY":c.get("super_capacity_safe") is True,
"NO_FLASH":e.get("flash_authorized")=="NO" and c.get("flash_authorized") is False,
"NO_RESET":e.get("factory_reset_authorized")=="NO" and c.get("factory_reset_authorized") is False,
}
bad=[k for k,v in checks.items() if not v]
state="PASS_READY_FOR_PHYSICAL_CONTROL_REVIEW" if not bad else "BLOCKED_"+bad[0]
r={"schema":1,"phase":"C3A_V010014_LIVE_PREFLIGHT","final_state":state,
   "checks":checks,"failures":bad,"system_current_bytes":f.get("system_current_bytes",0),
   "planned_system_target_bytes":f.get("planned_system_target_bytes",0),
   "planned_system_growth_bytes":f.get("planned_system_growth_bytes",0),
   "remaining_headroom_bytes":f.get("remaining_headroom_after_planned_growth_bytes",0),
   "target_system_partition":c.get("target_system_partition",""),
   "active_cow_count":len(cows) if isinstance(cows,dict) else -1,
   "active_group":c.get("active_group",""),
   "active_group_capacity_safe":c.get("active_group_capacity_safe",False),
   "super_capacity_safe":c.get("super_capacity_safe",False),
   "flash_authorized":False,"factory_reset_authorized":False,"write_capable_script_created":False}
pathlib.Path(sys.argv[4]).write_text(json.dumps(r,indent=2,sort_keys=True)+"\n")
for k in ["current_slot","is_userspace","unlocked","super_bytes","system_current_bytes","planned_system_target_bytes","planned_system_growth_bytes","remaining_headroom_after_planned_growth_bytes"]:
    print(f"C3A_V010014_LIVE_{k.upper()}={f.get(k,'UNKNOWN')}")
print(f"C3A_V010014_LIVE_TARGET_PARTITION={c.get('target_system_partition','UNKNOWN')}")
print(f"C3A_V010014_LIVE_ACTIVE_COW_COUNT={len(cows) if isinstance(cows,dict) else -1}")
print(f"C3A_V010014_LIVE_ACTIVE_GROUP={c.get('active_group','UNKNOWN')}")
print(f"C3A_V010014_LIVE_ACTIVE_GROUP_CAPACITY_SAFE={'YES' if c.get('active_group_capacity_safe') is True else 'NO'}")
print(f"C3A_V010014_LIVE_SUPER_CAPACITY_SAFE={'YES' if c.get('super_capacity_safe') is True else 'NO'}")
for x in bad: print("C3A_V010014_LIVE_PREFLIGHT_FAILURE="+x)
print("C3A_V010014_LIVE_FLASH_AUTHORIZED=NO")
print("C3A_V010014_LIVE_FACTORY_RESET_AUTHORIZED=NO")
print("C3A_V010014_LIVE_WRITE_CAPABLE_SCRIPT_CREATED=NO")
print("C3A_V010014_LIVE_PREFLIGHT="+state)
raise SystemExit(0 if not bad else 4)
PY
