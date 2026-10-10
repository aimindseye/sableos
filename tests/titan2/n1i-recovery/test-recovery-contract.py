#!/usr/bin/env python3
"""N1I recovery-contract self-tests. Offline only: no device, no /srv, no network.

Output follows the N1I self-test convention:  CASE<TAB>recovery<TAB>id<TAB>PASS|FAIL<TAB>detail
"""

from __future__ import annotations

import ast
import copy
import json
import random
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path(subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"], text=True).strip())
sys.path.insert(0, str(ROOT / "build/titan2"))
sys.path.insert(0, str(HERE))

import n1i_recovery_eval as E  # noqa: E402
import make_fixtures as M  # noqa: E402

EVAL = ROOT / "build/titan2/n1i_recovery_eval.py"
CONTRACT_PATH = ROOT / "docs/titan2/N1I_RECOVERY_CONTRACT_V1.json"
FIXTURES = HERE / "fixtures"
FAILS = 0


def case(cid: str, ok: bool, detail: str = "") -> None:
    global FAILS
    print(f"CASE\trecovery\t{cid}\t{'PASS' if ok else 'FAIL'}\t{detail}".replace("\n", " ")[:500])
    FAILS += 0 if ok else 1


def load(p: Path):
    return json.loads(p.read_text(encoding="utf-8"))


CONTRACT = load(CONTRACT_PATH)


def bundle(fid: str) -> dict:
    return load(FIXTURES / f"{fid}.json")


def run(b: dict, c: dict | None = None) -> dict:
    return E.evaluate(b, c or CONTRACT)


def rehash(b: dict) -> dict:
    b["events_sha256"] = E.canonical_sha256(b["events"])
    return b


# ---------------------------------------------------------------------------
# 1. Contract is valid, design-only, and fixtures are generated, not hand-edited
# ---------------------------------------------------------------------------
errs = E.validate_contract(CONTRACT)
case("contract_valid", not errs, ",".join(errs))
case("contract_design_only", CONTRACT["status"] == "DESIGN_ONLY_NOT_PRODUCTION_AUTHORIZED"
     and CONTRACT["execution_enabled"] is False and not any(CONTRACT["authority"].values()))

regen = subprocess.run([sys.executable, str(HERE / "make_fixtures.py"), "--check"], capture_output=True, text=True)
case("fixtures_match_generator", regen.returncode == 0, regen.stdout.strip())

ids = [f["id"] for f in CONTRACT["fixtures"]]
files = sorted(p.stem for p in FIXTURES.glob("*.json"))
case("fixture_files_match_contract", sorted(ids) == files, f"contract={len(ids)} files={len(files)}")

# ---------------------------------------------------------------------------
# 2. Gate coverage: every gate has at least one fixture that exercises it
# ---------------------------------------------------------------------------
cover = {g: [f["id"] for f in CONTRACT["fixtures"] if g in f["gates"]] for g in CONTRACT["gates"]}
for g, fs in cover.items():
    case(f"gate_covered:{g}", bool(fs), ",".join(fs))

# ---------------------------------------------------------------------------
# 3. Replay every fixture through the evaluator and check its assertions
# ---------------------------------------------------------------------------
RESULTS: dict[str, dict] = {}
for f in CONTRACT["fixtures"]:
    r = run(bundle(f["id"]))
    RESULTS[f["id"]] = r
    diff = {k: {"want": v, "got": r.get(k)} for k, v in f["assert"].items() if r.get(k) != v}
    case(f"replay:{f['id']}", not diff, json.dumps(diff, sort_keys=True) if diff else f["expected"])
    case(f"replay_never_executes:{f['id']}", r["execution_enabled"] is False
         and r["physical_qualification"] == "NOT_EXECUTED" and r["root_cause"] == "UNKNOWN"
         and r.get("proposal") in (None, *E.PROPOSALS) and r.get("proposal") != "REQUEST_EXPLICIT_RECOVERY_APPROVAL")

# ---------------------------------------------------------------------------
# 4. Specific semantics
# ---------------------------------------------------------------------------
case("stock_cause_not_equivalent_to_oct09",
     not E.same_initial_cause(RESULTS["F02_OCT09_LOSS"], RESULTS["F04_STOCK_DIFFERENT_CAUSE"]))
case("same_cause_is_reflexive",
     E.same_initial_cause(RESULTS["F02_OCT09_LOSS"], RESULTS["F02_OCT09_LOSS"]))

r02 = RESULTS["F02_OCT09_LOSS"]
decoded = {k for k in r02 if "meaning" in k or "decoded" in k}
case("vendor_code_kept_opaque", r02["vendor_codes"] == ["0x140F7C"] and not decoded,
     "0x140F7C == res 1314684; must not be decoded")

case("exact_duplicate_dropped_not_counted", RESULTS["F01_OCT03_STABLE"]["abort"] is None)
case("dsrm_selection_is_not_execution",
     RESULTS["F02_OCT09_LOSS"]["dsrm_executed"] == [] and RESULTS["F19_DSRM_EXECUTED"]["dsrm_executed"])
case("dsds_two_subscriptions_no_leak",
     RESULTS["F10_DSDS"]["per_subscription"] == {"S1": "VALIDATED_STABLE", "S2": "LOST"})
case("single_sim_never_qualifies_dsds",
     all(r.get("dsds") != "QUALIFIED" for r in RESULTS.values()))

# Ordering is deterministic: shuffling the event list does not change the verdict.
for fid in ("F02_OCT09_LOSS", "F03_POST_CYCLE_INVALID", "F10_DSDS", "F11_STOCK_TRANSIENT_RECOVERED"):
    ok = True
    for seed in range(5):
        b = bundle(fid)
        random.Random(seed).shuffle(b["events"])
        r = run(rehash(b))
        r.pop("detail", None)
        base = dict(RESULTS[fid]); base.pop("detail", None)
        ok &= r == base
    case(f"shuffle_deterministic:{fid}", ok)

# ---------------------------------------------------------------------------
# 5. Bundle mutations must change or stop the verdict
# ---------------------------------------------------------------------------
def mutate_events(fid, fn, label, check):
    b = bundle(fid)
    fn(b["events"])
    r = run(rehash(b))
    case(f"bundle_mutation:{label}", check(r), f"outcome={r.get('outcome')} abort={r.get('abort')}")


def flip_first_valid(ev):
    for e in ev:
        if e["event_type"] == "VALIDATION":
            e["payload"]["verdict"] = "INVALID"
            return


def drop_validation(ev):
    ev[:] = [e for e in ev if e["event_type"] != "VALIDATION"]


def drop_sub_ref(ev):
    for e in ev:
        if e["event_type"] == "SIM_STATE":
            e["subscription_ref"] = None


def thin_samples(ev):
    ev[:] = [e for e in ev if not (e["source_id"] == "sampler" and 300 < E.parse_ts(e["timestamp_utc"]) - E.parse_ts(ev[0]["timestamp_utc"]) < 400)]


def unknown_clock(ev):
    ev[0]["source_clock_kind"] = "UNKNOWN"


def add_extra_field(ev):
    ev[0]["execute"] = True


def move_apn_before_loss(ev):
    for e in ev:
        if e["event_type"] == "OPERATOR_ACTION" and e["payload"]["action"] == "APN_TRIAL":
            e["timestamp_utc"] = M.ts(50)


mutate_events("F01_OCT03_STABLE", flip_first_valid, "valid_to_invalid_fails_internet",
              lambda r: r["outcome"] == "FAIL_INTERNET_VALIDATION")
mutate_events("F01_OCT03_STABLE", drop_validation, "no_validation_not_stable",
              lambda r: r["outcome"] == "INCONCLUSIVE" and r["inconclusive_reason"] == "VALIDATION_PENDING")
mutate_events("F01_OCT03_STABLE", drop_sub_ref, "no_mapping_unknown", lambda r: r["outcome"] == "UNKNOWN")
mutate_events("F01_OCT03_STABLE", thin_samples, "sample_gap_inconclusive",
              lambda r: r["outcome"] == "INCONCLUSIVE" and r["inconclusive_reason"] == "SAMPLE_GAP")
mutate_events("F01_OCT03_STABLE", unknown_clock, "unknown_clock_inconclusive",
              lambda r: r["outcome"] == "INCONCLUSIVE")
mutate_events("F01_OCT03_STABLE", add_extra_field, "extra_field_aborts", lambda r: r["abort"] == "SCHEMA")
mutate_events("F07_LATE_APN_TRIAL", move_apn_before_loss, "apn_before_loss_becomes_prior_candidate",
              lambda r: "APN_TRIAL" in r["prior_cause_candidates"])

b = bundle("F01_OCT03_STABLE")
b["events"][3]["payload"]["active"] = 0  # tamper without rehash
case("bundle_mutation:tamper_without_rehash_aborts", run(b)["abort"] == "SHA256_MISMATCH")

b = bundle("F01_OCT03_STABLE")
b["capture"]["end_utc"] = M.ts(10)
case("bundle_mutation:event_outside_capture_aborts", run(b)["abort"] == "PROVENANCE")

# ---------------------------------------------------------------------------
# 6. Contract mutations: each must be rejected by validate_contract and must
#    make evaluate() refuse to run (the old tests missed all of these).
# ---------------------------------------------------------------------------
def fx(c, fid):
    return next(f for f in c["fixtures"] if f["id"] == fid)


CONTRACT_MUTATIONS = {
    "drop_required_evidence_ref": lambda c: c["event_schema"]["required_fields"].remove("evidence_ref"),
    "add_action_event_type": lambda c: c["event_schema"]["allowed_event_types"].append("RADIO_CYCLE_EXEC"),
    "corrupt_fixture_expected_pass": lambda c: fx(c, "F09_CORRUPT_EVIDENCE").__setitem__(
        "assert", {"outcome": "VALIDATED_STABLE"}),
    "invent_root_cause": lambda c: fx(c, "F02_OCT09_LOSS")["assert"].__setitem__("root_cause", "0x140F7C_CARRIER_RELEASE"),
    "capture_gap_to_pass": lambda c: c["qualification"]["outcomes"].__setitem__("capture_gap_or_clock_conflict", "PASS"),
    "validation_age_3600": lambda c: c["qualification"]["thresholds"].__setitem__("active_probe_max_validation_age_seconds", 3600),
    "status_production": lambda c: c.__setitem__("status", "PRODUCTION_AUTHORIZED"),
    "remove_flash_authority": lambda c: c["authority"].pop("flash"),
    "drop_stable_window_requirement": lambda c: c["qualification"]["required"].remove("continuous_stable_window"),
    "enable_execution": lambda c: c.__setitem__("execution_enabled", True),
    "grant_adb": lambda c: c["authority"].__setitem__("adb", True),
    "action_allowed": lambda c: fx(c, "F08_UNAUTHORIZED_ACTION")["assert"]["action_decisions"].__setitem__("ADB_SHELL", "ALLOW"),
    "uncover_dual_sim_gate": lambda c: c["fixtures"].remove(fx(c, "F10_DSDS")),
    "unknown_gate_on_fixture": lambda c: fx(c, "F01_OCT03_STABLE")["gates"].append("G99_NONE"),
    "duplicate_dedup_allowed": lambda c: c["event_schema"].__setitem__("duplicate_conflict", "KEEP_FIRST"),
    "extra_fields_allowed": lambda c: c["event_schema"].__setitem__("extra_fields", "ALLOW"),
    "thresholds_advisory": lambda c: c["qualification"].__setitem__("thresholds_binding", False),
    "negative_fixture_passes": lambda c: fx(c, "F15_CAPTURE_GAP")["assert"].__setitem__("outcome", "VALIDATED_STABLE"),
}
for name, mut in CONTRACT_MUTATIONS.items():
    c = copy.deepcopy(CONTRACT)
    mut(c)
    errs = E.validate_contract(c)
    refused = run(bundle("F01_OCT03_STABLE"), c)["abort"] == "CONTRACT_INVALID"
    case(f"contract_mutation_rejected:{name}", bool(errs) and refused, ",".join(errs[:3]))

# ---------------------------------------------------------------------------
# 7. G10 safety: static scan of the evaluator source
# ---------------------------------------------------------------------------
tree = ast.parse(EVAL.read_text(encoding="utf-8"))
ALLOWED_IMPORTS = {"__future__", "argparse", "hashlib", "json", "sys", "datetime", "pathlib"}
imports = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        imports |= {a.name.split(".")[0] for a in node.names}
    elif isinstance(node, ast.ImportFrom):
        imports.add((node.module or "").split(".")[0])
case("g10_imports_allowlisted", imports <= ALLOWED_IMPORTS, f"extra={sorted(imports - ALLOWED_IMPORTS)}")

FORBIDDEN_CALLS = {"system", "popen", "Popen", "run", "call", "check_call", "check_output", "exec", "eval",
                   "execv", "execvp", "spawnl", "urlopen", "connect", "socket", "open", "write_text",
                   "write_bytes", "write", "unlink", "remove", "rmtree", "kill"}
called = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Call):
        fn = node.func
        called.add(fn.attr if isinstance(fn, ast.Attribute) else getattr(fn, "id", ""))
case("g10_no_process_network_or_write_calls", not (called & FORBIDDEN_CALLS), f"found={sorted(called & FORBIDDEN_CALLS)}")

src = EVAL.read_text(encoding="utf-8").lower()
case("g10_no_device_tool_strings", not any(t in src for t in ("adb ", "fastboot ", "resetprop", "setprop", "svc data",
                                                              "cmd phone", "reboot ", "reboot(")))

# ---------------------------------------------------------------------------
# 8. CLI behaves and stays read-only
# ---------------------------------------------------------------------------
before = subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain"], text=True)
cli = subprocess.run([sys.executable, str(EVAL), "--contract", str(CONTRACT_PATH),
                      "--bundle", str(FIXTURES / "F02_OCT09_LOSS.json")], capture_output=True, text=True)
out = json.loads(cli.stdout) if cli.returncode == 0 else {}
case("cli_evaluates_bundle", cli.returncode == 0 and out.get("outcome") == "LOST", cli.stderr.strip()[:200])
cli = subprocess.run([sys.executable, str(EVAL), "--contract", str(CONTRACT_PATH),
                      "--bundle", str(FIXTURES / "F09_CORRUPT_EVIDENCE.json")], capture_output=True, text=True)
case("cli_abort_exit_code", cli.returncode == 2 and json.loads(cli.stdout).get("abort") == "SHA256_MISMATCH")
cli = subprocess.run([sys.executable, str(EVAL), "--contract", str(CONTRACT_PATH), "--validate-contract"],
                     capture_output=True, text=True)
case("cli_validate_contract", cli.returncode == 0)
after = subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain"], text=True)
case("cli_wrote_nothing", before == after)

print(f"RECOVERY_CONTRACT_TESTS={'PASS' if FAILS == 0 else 'FAIL'} failed={FAILS}")
sys.exit(1 if FAILS else 0)
