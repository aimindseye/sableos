#!/usr/bin/env python3
"""SableOS PR 207 — was "5G" a real NR attachment, or only a display override?

Reads text dumps you already have and separates the four things that are easy to confuse:

  RAT          PS/WWAN accessNetworkTechnology and getRilDataRadioTechnology.
               NR here means 5G *standalone* (SA). 5G NSA always reports LTE, because
               LTE is the anchor.
  nrState      From the PS/WWAN NetworkRegistrationInfo only (the CS entry says NONE):
                 NONE           cell has no EN-DC / NR capability, or SA
                 RESTRICTED     EN-DC cell, NR restricted by the network
                 NOT_RESTRICTED EN-DC cell, NR allowed but NOT connected (anchor only)
                 CONNECTED      NR secondary cell group active (real NSA attachment)
  Channels     PhysicalChannelConfig entries. An NR channel in Primary/SecondaryServing is
               physical proof of an NR leg. An empty list means the vendor RIL does not
               report channels, so NSA detection falls back to nrState.
  Display      TelephonyDisplayInfo overrideNetwork (NR_NSA / NR_ADVANCED = "5G" icon).
               Carrier config can show 5G for NOT_RESTRICTED, and a grace timer can keep
               it after NR drops, so the icon alone proves nothing.

Classes per sample and phone:
  NR_SA               data RAT is NR
  NR_NSA_CONNECTED    RAT LTE and (nrState CONNECTED or NR serving channel)
  NR_ANCHOR_ONLY      RAT LTE, nrState NOT_RESTRICTED/RESTRICTED, no NR channel
  LTE_ONLY            RAT LTE, nrState NONE
  NO_WWAN_DATA        not registered / unknown RAT
Flags: DISPLAY_5G_WITHOUT_NR (icon says 5G, radio is not on NR), NR_WITHOUT_5G_DISPLAY.

Inputs (any mix; label each source):
  --sample LABEL=PATH   PATH may be a file or a directory. Directories are searched for
                        *registry*.txt (dumpsys telephony.registry), *carrier_config*.txt,
                        and dumpsys_phone*.txt. A capture-n1b2-cellular-runtime.sh output
                        directory works as-is (raw/ preferred, redacted/ also fine).
  The report contains only parsed radio fields and carrier-config values, but it is
  derived from device dumps: manual privacy review is required before sharing it.
  Plain files are sniffed by content, so hand-saved dumps work too.

Example:
  classify-n1b2-nr-state.py --sample stock-tee14=./stock_dumps --sample n1d-system-only=./out/cellular-runtime-n1d-system-only-...
Writes a Markdown comparison to stdout (or --out FILE) and exits 0. Read-only.
"""
import argparse
import os
import re
import sys
from collections import Counter, defaultdict

NR_OVERRIDES = {"NR_NSA", "NR_ADVANCED", "NR_NSA_MMWAVE"}
CC_KEYS = [
    "carrier_nr_availabilities_int_array",       # 1 = NSA, 2 = SA
    "5g_icon_configuration_string",
    "5g_icon_display_grace_period_string",
    "5g_icon_display_secondary_grace_period_string",
    "nr_advanced_threshold_bandwidth_khz_int",
    "additional_nr_advanced_bands_int_array",
    "nr_advanced_capable_pco_id_int",
    "lte_plus_threshold_bandwidth_khz_int",
    "lte_enabled_bool",
    "carrier_name_string",
    "carrier_config_version_string",
]


# ------------------------------------------------------------------ parsing
def _m(rx, text, default="-", flags=0):
    m = re.search(rx, text, flags)
    return m.group(1) if m else default


def split_phones(registry_text):
    """dumpsys telephony.registry -> {phone_id: block}. Ignores the trailing local-log history."""
    body = re.split(r"\n\s*local logs:?", registry_text, maxsplit=1, flags=re.I)[0]
    parts = re.split(r"\n\s*Phone Id=(\d+)", "\n" + body)
    if len(parts) < 3:
        return {"0": body}
    return {parts[i]: parts[i + 1] for i in range(1, len(parts) - 1, 2)}


def nri_entries(block):
    """Split each NetworkRegistrationInfo{...} into its own chunk (they contain nested braces)."""
    chunks = re.split(r"NetworkRegistrationInfo\{", block)[1:]
    out = []
    for c in chunks:
        c = re.split(r"\}\s*\]|\},\s*NetworkRegistrationInfo|\n\s*m[A-Z]\w*=", c, maxsplit=1)[0]
        out.append({
            "domain": _m(r"domain=(\w+)", c),
            "transport": _m(r"transportType=(\w+)", c),
            "reg": _m(r"registrationState=(\w+)", c),
            "rat": _m(r"accessNetworkTechnology=(\w+)", c),
            "nr_state": _m(r"nrState=(\w+)", c),
            "endc_available": _m(r"isEnDcAvailable\s*=\s*(\w+)", c),
            "nr_available": _m(r"isNrAvailable\s*=\s*(\w+)", c),
            "dcnr_restricted": _m(r"isDcNrRestricted\s*=\s*(\w+)", c),
            "carrier_agg": _m(r"isUsingCarrierAggregation=(\w+)", c),
        })
    return out


def channels(block):
    pcc = []
    for c in re.findall(r"PhysicalChannelConfig\{([^}]*)\}", block):
        pcc.append({
            "status": _m(r"mConnectionStatus=(\w+)", c),
            "type": _m(r"mNetworkType=(\w+)", c),
            "band": _m(r"mBand=(-?\d+)", c),
            "bw": _m(r"mCellBandwidthDownlinkKhz=(\d+)", c),
            "range": _m(r"mFrequencyRange=(\w+)", c),
        })
    return pcc


def parse_registry_phone(block):
    """Everything needed to classify one phone in one registry dump."""
    nris = nri_entries(block)
    ps = next((n for n in nris if n["domain"] == "PS" and n["transport"] == "WWAN"), None)
    wlan = next((n for n in nris if n["domain"] == "PS" and n["transport"] == "WLAN"), None)
    pcc = channels(block)
    serving = [p for p in pcc if re.match(r"(Primary|Secondary)Serving", p["status"], re.I)]
    nr_ch = [p for p in serving if p["type"].upper().startswith("NR")]
    lte_ch = [p for p in serving if p["type"].upper().startswith("LTE")]
    rec = {
        "ril_data_tech": _m(r"getRilDataRadioTechnology=\d+\((\w+)\)", block),
        "data_reg": _m(r"mDataRegState=\d+\((\w+)\)", block),
        "voice_reg": _m(r"mVoiceRegState=\d+\((\w+)\)", block),
        "ps_reg": ps["reg"] if ps else "-",
        "ps_rat": ps["rat"] if ps else "-",
        "nr_state": ps["nr_state"] if ps else "-",
        "endc_available": ps["endc_available"] if ps else "-",
        "nr_available": ps["nr_available"] if ps else "-",
        "dcnr_restricted": ps["dcnr_restricted"] if ps else "-",
        "carrier_agg": ps["carrier_agg"] if ps else "-",
        "wlan_reg": wlan["reg"] if wlan else "-",
        "iwlan_preferred": _m(r"mIsIwlanPreferred=(\w+)", block),
        "nr_freq_range": _m(r"mNrFrequencyRange=(\w+)", block),
        "display_network": _m(r"TelephonyDisplayInfo\s*\{\s*network=(\w+)", block),
        "display_override": _m(r"overrideNetwork=(\w+)", block),
        "pcc_reported": "YES" if pcc else "NO",
        "nr_channels": ";".join(f"{p['status']}/b{p['band']}/{p['bw']}kHz" for p in nr_ch) or "-",
        "lte_channels": str(len(lte_ch)),
        "data_conn": _m(r"mDataConnectionState(?:\[\d+\])?=(-?\d+)", block),
    }
    rec["nr_class"] = classify(rec)
    rec["flags"] = flags(rec)
    return rec


def classify(r):
    rat = r["ps_rat"] if r["ps_rat"] not in ("-", "UNKNOWN") else r["ril_data_tech"]
    rat = (rat or "-").upper()
    if rat.startswith("NR"):
        return "NR_SA"
    if rat.startswith("LTE"):
        if r["nr_state"] == "CONNECTED" or r["nr_channels"] != "-":
            return "NR_NSA_CONNECTED"
        if r["nr_state"] in ("NOT_RESTRICTED", "RESTRICTED"):
            return "NR_ANCHOR_ONLY"
        return "LTE_ONLY"
    return "NO_WWAN_DATA"


def flags(r):
    f = []
    shows_5g = r["display_override"] in NR_OVERRIDES or r["display_network"].upper().startswith("NR")
    on_nr = r["nr_class"] in ("NR_SA", "NR_NSA_CONNECTED")
    if shows_5g and not on_nr:
        f.append("DISPLAY_5G_WITHOUT_NR")
    if on_nr and not shows_5g and r["display_override"] != "-":
        f.append("NR_WITHOUT_5G_DISPLAY")
    if r["nr_state"] == "CONNECTED" and r["pcc_reported"] == "YES" and r["nr_channels"] == "-":
        f.append("NRSTATE_CONNECTED_BUT_NO_NR_CHANNEL")
    if r["nr_channels"] != "-" and r["nr_state"] not in ("CONNECTED", "-"):
        f.append("NR_CHANNEL_BUT_NRSTATE_" + r["nr_state"])
    if r["pcc_reported"] == "NO":
        f.append("NO_PHYSICAL_CHANNEL_REPORTS")
    return ",".join(f) or "-"


def parse_carrier_config(text):
    """dumpsys carrier_config -> {phone: {key: [(section, value)]}}."""
    out = defaultdict(lambda: defaultdict(list))
    phone, section = "?", "?"
    for line in text.splitlines():
        m = re.match(r"\s*Phone\s*Id\s*[=:]\s*(\d+)", line, re.I)
        if m:
            phone, section = m.group(1), "?"
            continue
        m = re.match(r"\s*(m\w*Config\w*|Default Values.*|CarrierConfigLoader.*)\s*:?\s*$", line)
        if m:
            section = m.group(1).strip(" :")
            continue
        m = re.match(r"\s*([0-9a-z_]+)\s*=\s*(.*)$", line)
        if m and m.group(1) in CC_KEYS:
            out[phone][m.group(1)].append((section, m.group(2).strip()))
    return out


def parse_network_type_controller(text):
    """Optional: dumpsys phone NetworkTypeController section -> grace-timer state per file."""
    keys = ["mIsPrimaryTimerActive", "mIsSecondaryTimerActive", "mIsPhysicalChannelConfigOn",
            "mLastShownNrState", "mPrimaryTimerState", "mSecondaryTimerState"]
    return {k: _m(rf"{k}\s*[=:]\s*(\S+)", text) for k in keys}


# ------------------------------------------------------------------ input discovery
def sniff(path):
    try:
        head = open(path, errors="replace").read(200000)
    except OSError:
        return None, ""
    if "mServiceState" in head and ("Phone Id=" in head or "mTelephonyDisplayInfo" in head):
        return "registry", head
    if "carrier_nr_availabilities_int_array" in head or "5g_icon_configuration_string" in head:
        return "carrier_config", head
    if "NetworkTypeController" in head:
        return "phone", head
    return None, head


def collect(path):
    files = []
    if os.path.isdir(path):
        # Prefer raw over redacted if both exist; the fields used here are not identifiers.
        roots = [os.path.join(path, "raw")] if os.path.isdir(os.path.join(path, "raw")) else [path]
        for root in roots:
            for dp, _, fns in os.walk(root):
                for fn in sorted(fns):
                    if fn.endswith((".txt", ".log")):
                        files.append(os.path.join(dp, fn))
    else:
        files.append(path)
    reg, cc, ntc = [], [], []
    for f in files:
        kind, text = sniff(f)
        if kind == "registry":
            reg.append((f, open(f, errors="replace").read()))
        elif kind == "carrier_config":
            cc.append((f, open(f, errors="replace").read()))
        elif kind == "phone":
            ntc.append((f, open(f, errors="replace").read()))
    return reg, cc, ntc


def analyse(label, path):
    reg, cc, ntc = collect(path)
    samples = []
    for f, text in reg:
        for pid, block in split_phones(text).items():
            r = parse_registry_phone(block)
            r.update({"file": os.path.relpath(f, path) if os.path.isdir(path) else os.path.basename(f), "phone_id": pid})
            samples.append(r)
    ccfg = {}
    for f, text in cc:
        for ph, keys in parse_carrier_config(text).items():
            ccfg.setdefault(ph, {}).update(keys)
    timers = [parse_network_type_controller(t) for _, t in ntc]
    return {"label": label, "path": path, "samples": samples, "carrier_config": ccfg, "timers": timers,
            "files": {"registry": len(reg), "carrier_config": len(cc), "phone": len(ntc)}}


# ------------------------------------------------------------------ verdict + report
def verdict(samples):
    """Per phone: overall answer to 'was it real NR?'."""
    by = defaultdict(list)
    for s in samples:
        by[s["phone_id"]].append(s)
    out = {}
    for pid, ss in sorted(by.items()):
        cls = Counter(s["nr_class"] for s in ss)
        disp = sum(1 for s in ss if "DISPLAY_5G_WITHOUT_NR" in s["flags"])
        real = cls["NR_SA"] + cls["NR_NSA_CONNECTED"]
        shown = sum(1 for s in ss if s["display_override"] in NR_OVERRIDES or s["display_network"].upper().startswith("NR"))
        if real and disp == 0:
            v = "REAL_NR" + ("_SA" if cls["NR_SA"] >= cls["NR_NSA_CONNECTED"] else "_NSA")
        elif real and disp:
            v = "MIXED_REAL_NR_AND_DISPLAY_ONLY"
        elif shown:
            v = "DISPLAY_OVERRIDE_ONLY"
        elif cls["NR_ANCHOR_ONLY"]:
            v = "NR_CAPABLE_CELL_NOT_ATTACHED"
        elif cls["LTE_ONLY"]:
            v = "LTE_ONLY"
        else:
            v = "NO_WWAN_DATA"
        pcc = "YES" if any(s["pcc_reported"] == "YES" for s in ss) else "NO"
        out[pid] = {"verdict": v, "samples": len(ss), "classes": dict(cls), "display_5g_samples": shown,
                    "display_only_samples": disp, "pcc_reported": pcc,
                    "confidence": "HIGH" if pcc == "YES" or cls["NR_SA"] else "MEDIUM_NRSTATE_ONLY"}
    return out


def md_table(rows, cols):
    o = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for r in rows:
        o.append("| " + " | ".join(str(x).replace("|", "\\|")[:120] for x in r) + " |")
    return "\n".join(o)


def report(results, max_rows):
    o = ["# NR attachment vs 5G display\n",
         "Read-only analysis of existing dumps. **Manual privacy review required before sharing.** "
         "NR SA reports RAT=NR; NR NSA reports RAT=LTE with "
         "nrState=CONNECTED and/or an NR serving channel. A 5G icon (display override) without either "
         "is not an NR attachment.\n"]
    # verdict comparison
    o.append("## Verdict\n")
    rows = []
    for r in results:
        for pid, v in r["verdict"].items():
            rows.append((r["label"], pid, v["verdict"], v["confidence"], v["samples"],
                         " ".join(f"{k}={n}" for k, n in sorted(v["classes"].items())),
                         v["display_5g_samples"], v["display_only_samples"], v["pcc_reported"]))
    o.append(md_table(rows, ["image", "phone", "verdict", "confidence", "samples", "classes",
                             "5G shown", "5G shown w/o NR", "channel reports"]) + "\n")
    # carrier config
    o.append("## Carrier config (5G rules)\n")
    rows = []
    for r in results:
        for ph, keys in sorted(r["carrier_config"].items()):
            for k in CC_KEYS:
                for sec, val in keys.get(k, []):
                    rows.append((r["label"], ph, k, sec, val))
    o.append((md_table(rows, ["image", "phone", "key", "source", "value"]) if rows else
              "No carrier_config dump found. Capture `dumpsys carrier_config`.") + "\n")
    o.append("`carrier_nr_availabilities_int_array`: 1 = NSA, 2 = SA. If 2 is missing, the framework will "
             "not use SA even if the modem supports it. `5g_icon_configuration_string` entries such as "
             "`not_restricted_rrc_idle:5G` show a 5G icon on an anchor cell with no NR leg; grace-period "
             "keys keep the icon after NR drops.\n")
    # timers
    for r in results:
        if r["timers"]:
            o.append(f"## NetworkTypeController timers — {r['label']}\n")
            o.append(md_table([tuple(t.values()) for t in r["timers"]], list(r["timers"][0].keys())) + "\n")
    # per-sample detail
    cols = ["file", "phone_id", "ril_data_tech", "ps_rat", "nr_state", "endc_available", "nr_channels",
            "lte_channels", "display_network", "display_override", "nr_class", "flags"]
    for r in results:
        o.append(f"## Samples — {r['label']} ({len(r['samples'])})\n")
        ss = r["samples"]
        # Show every sample where anything NR-related changed, capped.
        keep, prev = [], {}
        for s in ss:
            sig = (s["phone_id"], s["nr_class"], s["display_override"], s["nr_state"], s["nr_channels"])
            if prev.get(s["phone_id"]) != sig:
                keep.append(s)
                prev[s["phone_id"]] = sig
        o.append(md_table([tuple(s[c] for c in cols) for s in keep[:max_rows]], cols) + "\n")
        if len(keep) > max_rows:
            o.append(f"_{len(keep) - max_rows} more state changes not shown._\n")
    o.append("## How to read this\n"
             "- `REAL_NR_SA` / `REAL_NR_NSA`: the radio was on NR. `confidence=MEDIUM_NRSTATE_ONLY` means "
             "the vendor RIL sent no physical channel reports, so NSA rests on nrState alone.\n"
             "- `DISPLAY_OVERRIDE_ONLY`: the icon said 5G, the radio never was. Usually carrier-config icon "
             "rules on an EN-DC-capable LTE anchor, or a grace timer.\n"
             "- `NR_CAPABLE_CELL_NOT_ATTACHED`: the LTE cell supports EN-DC but NR was never added.\n"
             "- Stock vs Sable: compare the radio fields, not the icon. MediaTek stock frameworks can "
             "compute the icon with their own rules.\n")
    return "\n".join(o)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sample", action="append", required=True, metavar="LABEL=PATH")
    ap.add_argument("--out")
    ap.add_argument("--max-rows", type=int, default=60)
    a = ap.parse_args()
    results = []
    for s in a.sample:
        if "=" not in s:
            ap.error(f"--sample must be LABEL=PATH, got {s}")
        label, path = s.split("=", 1)
        if not os.path.exists(path):
            ap.error(f"not found: {path}")
        r = analyse(label, path)
        if not r["samples"]:
            print(f"WARNING: no telephony.registry dump found under {path}", file=sys.stderr)
        r["verdict"] = verdict(r["samples"])
        results.append(r)
    text = report(results, a.max_rows)
    if a.out:
        open(a.out, "w").write(text)
        print(a.out)
    else:
        print(text)
    for r in results:
        for pid, v in r["verdict"].items():
            key = re.sub(r"[^A-Z0-9]+", "_", r["label"].upper()).strip("_")
            print(f"NR_VERDICT_{key}_PHONE{pid}={v['verdict']}", file=sys.stderr)


if __name__ == "__main__":
    main()
