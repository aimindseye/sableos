#!/usr/bin/env bash
set -euo pipefail
E5A=""; CAP=""; PLAN=""; OUT=""
EXPECTED_C3A_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
EXPECTED_C3A_BYTES=3146977280
EXPECTED_STOCK_FINGERPRINT="Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys"
EXPECTED_STOCK_INCREMENTAL="V01.00.14"
EXPECTED_SLOT="a"
EXPECTED_PRODUCT="Titan_2"
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
python3 - "$E5A" "$CAP" "$PLAN" "$OUT" "$EXPECTED_C3A_SHA256" "$EXPECTED_C3A_BYTES" "$EXPECTED_STOCK_FINGERPRINT" "$EXPECTED_STOCK_INCREMENTAL" "$EXPECTED_SLOT" "$EXPECTED_PRODUCT" "$EXPECTED_SUPER_BYTES" <<'PY'
import json,pathlib,sys
e=json.loads(pathlib.Path(sys.argv[1]).read_text())
c=json.loads(pathlib.Path(sys.argv[2]).read_text())
expected_sha=sys.argv[5]; expected_bytes=int(sys.argv[6]); expected_fp=sys.argv[7]; expected_inc=sys.argv[8]; expected_slot=sys.argv[9]; expected_product=sys.argv[10]; expected_super=int(sys.argv[11])
p={}
for x in pathlib.Path(sys.argv[3]).read_text().splitlines():
    if x and not x.startswith("#") and "=" in x:
        k,v=x.split("=",1); p[k]=v
f=e.get("fastbootd") or {}; s=e.get("stock") or {}; cows=c.get("active_cow_partitions") or {}
expected_binding=p.get("EXPECTED_FASTBOOT_BINDING_SHA256","")
logical_names=f.get("logical_partition_names") or []
checks={
"OFFLINE_PLAN_STATE_INVALID":p.get("C3A_V010014_CONTROL_PLAN")=="PREPARED_NO_WRITE",
"C3A_SHA_MISMATCH":e.get("sealed_system_sha256")==expected_sha,
"C3A_BYTES_MISMATCH":int(e.get("sealed_system_bytes",0) or 0)==expected_bytes,
"E5A_NOT_CLEAN_PASS":e.get("final_state")=="PASS_REVIEW_READY",
"DEVICE_BINDING_NOT_VERIFIED":e.get("device_binding_verified") is True,
"FASTBOOT_DEVICE_BINDING_CHANGED":len(expected_binding)==64 and e.get("fastboot_device_binding_sha256")==expected_binding,
"STOCK_FINGERPRINT_MISMATCH":s.get("fingerprint")==expected_fp,
"STOCK_INCREMENTAL_MISMATCH":s.get("incremental")==expected_inc,
"CURRENT_SLOT_NOT_A":f.get("current_slot")==expected_slot,
"NOT_USERSPACE_FASTBOOTD":f.get("is_userspace")=="yes",
"BOOTLOADER_NOT_UNLOCKED":f.get("unlocked")=="yes",
"FASTBOOT_PRODUCT_MISMATCH":f.get("product")==expected_product,
"FASTBOOT_SNAPSHOT_UPDATE_STATUS_NOT_NONE":f.get("snapshot_update_status")=="none",
"SNAPSHOT_UPDATE_REVIEW_NOT_IDLE":e.get("snapshot_update_review")=="PASS_IDLE_OR_NONE",
"SUPER_BYTES_MISMATCH":int(f.get("super_bytes",0) or 0)==expected_super,
"LOGICAL_PARTITION_INVENTORY_INCOMPLETE":f.get("allocation_complete") is True,
"SYSTEM_A_NOT_REPORTED_LOGICAL":isinstance(logical_names,list) and "system_a" in logical_names,
"TOTAL_SUPER_CAPACITY_NOT_SAFE":f.get("capacity_safe") is True and c.get("super_capacity_safe") is True,
"TARGET_BYTES_MISMATCH":int(f.get("planned_system_target_bytes",0) or 0)==expected_bytes,
"TARGET_NOT_SYSTEM_A":c.get("target_system_partition")=="system_a",
"SLOT_SWITCH_WOULD_BE_REQUIRED":c.get("slot_policy")=="KEEP_CURRENT_SLOT_NO_SLOT_SWITCH",
"ACTIVE_COW_COUNT_NOT_ZERO":isinstance(cows,dict) and len(cows)==0,
"COW_CLEANUP_WOULD_BE_REQUIRED":c.get("cow_cleanup_policy")=="NO_COW_CLEANUP_NEEDED",
"ACTIVE_GROUP_CAPACITY_NOT_SAFE":c.get("active_group_capacity_safe") is True,
"NO_FLASH_BOUNDARY_VIOLATED":e.get("flash_authorized")=="NO" and c.get("flash_authorized") is False,
"NO_RESET_BOUNDARY_VIOLATED":e.get("factory_reset_authorized")=="NO" and c.get("factory_reset_authorized") is False,
"NO_LP_MUTATION_BOUNDARY_VIOLATED":e.get("lp_mutation_authorized")=="NO" and c.get("lp_mutation_authorized") is False,
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
