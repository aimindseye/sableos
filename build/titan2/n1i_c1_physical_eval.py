from __future__ import annotations

import csv
import pathlib
import re
from dataclasses import dataclass, field

from n1i_c1_physical_evidence import (
    IMAGE_SOURCE_COMMIT, SCENARIOS, SURFACES, QualificationError, any_ims_registered,
    cellular_validated, expected_sim_state, ims_bearer_count, ims_provider_present,
    ims_registered_for_phone, load_env, operator_pass, parse_getprop, scenario_prefix,
    stable_data_connected, stable_registration, text, timeline_rows, verdict,
)


@dataclass
class ScenarioResult:
    scenario: str
    markers: dict[str, str] = field(default_factory=dict)
    internal: dict[str, str] = field(default_factory=dict)
    stock: dict[str, str] = field(default_factory=dict)
    reasons: dict[str, str] = field(default_factory=dict)


def _validate_collector(root: pathlib.Path, scenario: str) -> dict[str, str]:
    summary = load_env(root / "N1I_C1_COLLECTOR_SUMMARY.env")
    binding = load_env(root / "N1I_C1_BINDING.env")
    if summary.get("N1I_C1_PHYSICAL_COLLECTOR") != "PASS":
        raise QualificationError(f"{scenario}: collector not PASS")
    if summary.get("SCENARIO") != scenario or binding.get("SCENARIO") != scenario:
        raise QualificationError(f"{scenario}: scenario binding mismatch")
    for key in (
        "N1I_C1_DEVICE_SERIAL_BINDING", "N1I_C1_SYSTEM_IMAGE_SHA_BINDING",
        "N1I_C1_RUNTIME_DEVICE_IDENTITY", "N1I_C1_READ_ONLY_CONTRACT",
    ):
        if summary.get(key) != "PASS":
            raise QualificationError(f"{scenario}: {key} not PASS")
    for key in (
        "N1I_C1_PROPERTY_WRITE_COUNT", "N1I_C1_RADIO_RESTART_COUNT_BY_COLLECTOR",
        "N1I_C1_AIRPLANE_TOGGLE_COUNT_BY_COLLECTOR", "N1I_C1_APN_EDIT_COUNT",
        "N1I_C1_HEALING_ACTION_COUNT",
    ):
        if summary.get(key) != "0":
            raise QualificationError(f"{scenario}: mutation counter {key}={summary.get(key)}")
    if summary.get("N1I_C1_IMAGE_SOURCE_COMMIT") != IMAGE_SOURCE_COMMIT:
        raise QualificationError(f"{scenario}: wrong image source commit")
    return summary


def evaluate_scenario(root: pathlib.Path, scenario: str, op: dict[str, str]) -> ScenarioResult:
    _validate_collector(root, scenario)
    rows = timeline_rows(root)
    end = root / "raw" / "end"
    props = parse_getprop(text(end / "getprop.txt"))
    registry = text(end / "telephony_registry.txt")
    connectivity = text(end / "connectivity.txt")
    package_dump = text(end / "mediatek_ims_package.txt")
    path_dump = text(end / "mediatek_ims_path.txt")
    preferred_apn = text(end / "preferred_apn.txt")
    be2_log = text(root / "be2" / "redacted" / "logcat_stream.log")
    services = text(end / "mediatek_ims_services.txt")
    combined_ims = "\n".join((registry, services, be2_log))
    sim_state_ok = props.get("gsm.sim.state") == expected_sim_state(scenario)
    provider = ims_provider_present(package_dump, path_dump)
    validated = cellular_validated(connectivity)
    bearer_count = ims_bearer_count(connectivity)
    result = ScenarioResult(scenario=scenario)
    pfx = f"N1I_C1_{scenario_prefix(scenario)}"

    if scenario in {"tray1", "tray2"}:
        phone = 0 if scenario == "tray1" else 1
        opfx = scenario_prefix(scenario)
        registration = sim_state_ok and stable_registration(rows, phone)
        data_key = f"{opfx}_DATA_USER_TEST"
        data = registration and stable_data_connected(rows, phone) and validated and operator_pass(op, data_key)
        sms = operator_pass(op, f"{opfx}_SMS_SEND", f"{opfx}_SMS_RECEIVE", f"{opfx}_MMS_SEND", f"{opfx}_MMS_RECEIVE")
        ims_registration = any_ims_registered(combined_ims)
        ims_bearer = bearer_count >= 1
        outgoing = operator_pass(op, f"{opfx}_OUTGOING_VOICE")
        incoming = operator_pass(op, f"{opfx}_INCOMING_VOICE")
        result.markers = {
            f"{pfx}_REGISTRATION": verdict(registration), f"{pfx}_DATA": verdict(data),
            f"{pfx}_SMS_MMS": verdict(sms), f"{pfx}_IMS_PROVIDER": verdict(provider),
            f"{pfx}_IMS_REGISTRATION": verdict(ims_registration), f"{pfx}_IMS_BEARER": verdict(ims_bearer),
            f"{pfx}_OUTGOING_VOICE": verdict(outgoing), f"{pfx}_INCOMING_VOICE": verdict(incoming),
        }
        result.reasons = {
            "REGISTRATION": f"sim_state={props.get('gsm.sim.state','-')} final3_phone{phone}={stable_registration(rows, phone)}",
            "DATA": f"registration={registration} final3_connected={stable_data_connected(rows, phone)} validated={validated} operator={op.get(data_key,'MISSING')}",
            "SMS_MMS": "operator send/receive SMS+MMS all required", "IMS_PROVIDER": f"provider={provider}",
            "IMS_REGISTRATION": f"registered_end_evidence={ims_registration}", "IMS_BEARER": f"ims_mmtel_bearer_count={bearer_count}",
            "OUTGOING_VOICE": f"operator={op.get(f'{opfx}_OUTGOING_VOICE','MISSING')}",
            "INCOMING_VOICE": f"operator={op.get(f'{opfx}_INCOMING_VOICE','MISSING')}",
        }
    else:
        reg1 = sim_state_ok and stable_registration(rows, 0); reg2 = sim_state_ok and stable_registration(rows, 1)
        data1 = reg1 and operator_pass(op, "DSDS_SIM1_DATA_AS_DDS"); data2 = reg2 and operator_pass(op, "DSDS_SIM2_DATA_AS_DDS")
        sms1 = operator_pass(op, "DSDS_SIM1_SMS_SEND", "DSDS_SIM1_SMS_RECEIVE", "DSDS_SIM1_MMS_SEND", "DSDS_SIM1_MMS_RECEIVE")
        sms2 = operator_pass(op, "DSDS_SIM2_SMS_SEND", "DSDS_SIM2_SMS_RECEIVE", "DSDS_SIM2_MMS_SEND", "DSDS_SIM2_MMS_RECEIVE")
        imsreg1 = ims_registered_for_phone(registry, 0); imsreg2 = ims_registered_for_phone(registry, 1)
        bearer1 = bearer_count >= 1; bearer2 = bearer_count >= 2
        out1 = operator_pass(op, "DSDS_SIM1_OUTGOING_VOICE"); out2 = operator_pass(op, "DSDS_SIM2_OUTGOING_VOICE")
        in1 = operator_pass(op, "DSDS_SIM1_INCOMING_VOICE"); in2 = operator_pass(op, "DSDS_SIM2_INCOMING_VOICE")
        result.internal = {
            "N1I_C1_DSDS_SIM1_REGISTRATION": verdict(reg1), "N1I_C1_DSDS_SIM2_REGISTRATION": verdict(reg2),
            "N1I_C1_DSDS_SIM1_DATA": verdict(data1), "N1I_C1_DSDS_SIM2_DATA": verdict(data2),
            "N1I_C1_DSDS_SIM1_SMS_MMS": verdict(sms1), "N1I_C1_DSDS_SIM2_SMS_MMS": verdict(sms2),
            "N1I_C1_DSDS_SIM1_IMS_PROVIDER": verdict(provider), "N1I_C1_DSDS_SIM2_IMS_PROVIDER": verdict(provider),
            "N1I_C1_DSDS_SIM1_IMS_REGISTRATION": verdict(imsreg1), "N1I_C1_DSDS_SIM2_IMS_REGISTRATION": verdict(imsreg2),
            "N1I_C1_DSDS_SIM1_IMS_BEARER": verdict(bearer1), "N1I_C1_DSDS_SIM2_IMS_BEARER": verdict(bearer2),
            "N1I_C1_DSDS_SIM1_OUTGOING_VOICE": verdict(out1), "N1I_C1_DSDS_SIM2_OUTGOING_VOICE": verdict(out2),
            "N1I_C1_DSDS_SIM1_INCOMING_VOICE": verdict(in1), "N1I_C1_DSDS_SIM2_INCOMING_VOICE": verdict(in2),
        }
        result.markers = {
            f"{pfx}_REGISTRATION": verdict(reg1 and reg2), f"{pfx}_DATA": verdict(data1 and data2 and validated),
            f"{pfx}_SMS_MMS": verdict(sms1 and sms2), f"{pfx}_IMS_PROVIDER": verdict(provider),
            f"{pfx}_IMS_REGISTRATION": verdict(imsreg1 and imsreg2), f"{pfx}_IMS_BEARER": verdict(bearer1 and bearer2),
            f"{pfx}_OUTGOING_VOICE": verdict(out1 and out2), f"{pfx}_INCOMING_VOICE": verdict(in1 and in2),
        }
        result.reasons = {
            "REGISTRATION": f"sim_state={props.get('gsm.sim.state','-')} sim1={reg1} sim2={reg2}",
            "DATA": f"sim1_as_dds={data1} sim2_as_dds={data2} current_validated_cellular={validated}",
            "SMS_MMS": f"sim1={sms1} sim2={sms2}", "IMS_PROVIDER": f"provider={provider}",
            "IMS_REGISTRATION": f"phone0={imsreg1} phone1={imsreg2}", "IMS_BEARER": f"ims_mmtel_bearer_count={bearer_count}",
            "OUTGOING_VOICE": f"sim1={out1} sim2={out2}", "INCOMING_VOICE": f"sim1={in1} sim2={in2}",
        }

    all_runtime = "\n".join((connectivity, preferred_apn, registry, be2_log))
    result.stock = {
        f"{pfx}_STOCK_APN_TARGET": verdict("fast.t-mobile.com" in preferred_apn),
        f"{pfx}_STOCK_DATA_INTERFACE_TARGET": verdict("ccmni1" in all_runtime),
        f"{pfx}_STOCK_IMS_INTERFACE_TARGET": verdict("ccmni2" in all_runtime),
        f"{pfx}_STOCK_IMS_MMTEL_TARGET": verdict(bearer_count >= 1),
    }
    if scenario == "tray2":
        default_phone_1 = bool(re.search(r"(?i)mDefaultPhoneId\s*[=:]\s*1\b", registry) or "Default data phoneid = 1" in be2_log)
        cap_event = any(token in be2_log for token in ("MtkProxyController", "SET_RADIO_CAPABILITY", "EVENT_UNSOL_RADIO_CAPABILITY_CHANGED", "DSSExt"))
        result.stock[f"{pfx}_STOCK_CAPABILITY_SWITCH_TARGET"] = verdict(default_phone_1 and cap_event)
    return result


def evaluate_all(tray1: pathlib.Path, tray2: pathlib.Path, dsds: pathlib.Path, op: dict[str, str]) -> tuple[list[ScenarioResult], dict[str, str]]:
    roots = {"tray1": tray1, "tray2": tray2, "dsds": dsds}
    results = [evaluate_scenario(roots[s], s, op) for s in SCENARIOS]
    summaries = [load_env(roots[s] / "N1I_C1_COLLECTOR_SUMMARY.env") for s in SCENARIOS]
    shas = {s.get("N1I_C1_SYSTEM_IMAGE_SHA256", "") for s in summaries}
    serial_hashes = {s.get("N1I_C1_DEVICE_SERIAL_SHA256", "") for s in summaries}
    if len(shas) != 1 or "" in shas: raise QualificationError("scenario system-image SHA bindings differ")
    if len(serial_hashes) != 1 or "" in serial_hashes: raise QualificationError("scenario device serial bindings differ")
    return results, {"SYSTEM_SHA256": next(iter(shas)), "DEVICE_SERIAL_SHA256": next(iter(serial_hashes))}


def write_outputs(results: list[ScenarioResult], meta: dict[str, str], out: pathlib.Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    markers: dict[str, str] = {}; internal: dict[str, str] = {}; stock: dict[str, str] = {}
    for r in results: markers.update(r.markers); internal.update(r.internal); stock.update(r.stock)
    overall = all(v == "PASS" for v in markers.values())
    summary = out / "N1I_C1_PHYSICAL_RUNTIME_SUMMARY.env"
    with summary.open("w", encoding="utf-8") as fp:
        fp.write(f"N1I_C1_IMAGE_SOURCE_COMMIT={IMAGE_SOURCE_COMMIT}\nN1I_C1_SYSTEM_IMAGE_SHA256={meta['SYSTEM_SHA256']}\nN1I_C1_DEVICE_SERIAL_SHA256={meta['DEVICE_SERIAL_SHA256']}\n")
        fp.write("N1I_C1_READ_ONLY_CONTRACT=PASS\nN1I_C1_DEVICE_SERIAL_BINDING=PASS\nN1I_C1_SYSTEM_IMAGE_SHA_BINDING=PASS\nN1I_C1_DUMPSYS_IMS_STANDALONE_GATE=DISABLED\n")
        fp.write("N1I_C1_PROPERTY_WRITE_COUNT=0\nN1I_C1_RADIO_RESTART_COUNT_BY_COLLECTOR=0\nN1I_C1_AIRPLANE_TOGGLE_COUNT_BY_COLLECTOR=0\nN1I_C1_APN_EDIT_COUNT=0\nN1I_C1_HEALING_ACTION_COUNT=0\n")
        for key in sorted(internal): fp.write(f"{key}={internal[key]}\n")
        for scenario in ("TRAY1", "TRAY2", "DSDS"):
            for surface in SURFACES: fp.write(f"N1I_C1_{scenario}_{surface}={markers[f'N1I_C1_{scenario}_{surface}']}\n")
        fp.write(f"N1I_C1_PHYSICAL_RUNTIME_MATRIX={verdict(overall)}\n")
    with (out / "N1I_C1_PHYSICAL_RUNTIME_MATRIX.tsv").open("w", encoding="utf-8", newline="") as fp:
        w = csv.writer(fp, delimiter="\t", lineterminator="\n"); w.writerow(("scenario", "surface", "result", "reason"))
        for r in results:
            p = scenario_prefix(r.scenario)
            for surface in SURFACES: w.writerow((r.scenario, surface, r.markers[f"N1I_C1_{p}_{surface}"], r.reasons.get(surface, "")))
    with (out / "N1I_C1_STOCK_COMPARISON.tsv").open("w", encoding="utf-8", newline="") as fp:
        w = csv.writer(fp, delimiter="\t", lineterminator="\n"); w.writerow(("marker", "result", "blocking"))
        for key in sorted(stock): w.writerow((key, stock[key], "NO_DIAGNOSTIC_ONLY"))
    with (out / "N1I_C1_PHYSICAL_RUNTIME_REPORT.md").open("w", encoding="utf-8") as fp:
        fp.write("# Titan 2 N1I-C1 Physical Runtime Qualification\n\n")
        fp.write(f"- Image source: `{IMAGE_SOURCE_COMMIT}`\n- System image SHA-256: `{meta['SYSTEM_SHA256']}`\n- Device serial SHA-256: `{meta['DEVICE_SERIAL_SHA256']}`\n")
        fp.write("- Collector contract: read-only; no healing or radio/APN/property mutation\n- `dumpsys ims`: deliberately not a standalone gate\n\n")
        fp.write("Transient `ERROR_UNSPECIFIED`, registration rejects, early IMS setup errors, and `mtkImsIndication == NULL` are not standalone failures. Stable end state and independent surfaces control the verdict.\n\n")
        fp.write("## Acceptance matrix\n\n| Scenario | Surface | Result |\n|---|---|---|\n")
        for r in results:
            p = scenario_prefix(r.scenario)
            for surface in SURFACES: fp.write(f"| {r.scenario} | {surface} | {r.markers[f'N1I_C1_{p}_{surface}']} |\n")
        fp.write("\n## Stock comparison targets (diagnostic only)\n\n| Marker | Result |\n|---|---|\n")
        for key in sorted(stock): fp.write(f"| `{key}` | {stock[key]} |\n")
        fp.write(f"\n**N1I_C1_PHYSICAL_RUNTIME_MATRIX={verdict(overall)}**\n")
    print(summary); print(out / "N1I_C1_PHYSICAL_RUNTIME_MATRIX.tsv"); print(out / "N1I_C1_STOCK_COMPARISON.tsv"); print(out / "N1I_C1_PHYSICAL_RUNTIME_REPORT.md")
    print(f"N1I_C1_PHYSICAL_RUNTIME_MATRIX={verdict(overall)}")
    return 0 if overall else 1
