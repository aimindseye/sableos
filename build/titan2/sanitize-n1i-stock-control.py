#!/usr/bin/env python3
"""Sanitize Titan 2 stock telephony captures for repository reference."""
from __future__ import annotations

import argparse
import hashlib
import ipaddress
import re
from pathlib import Path

CURATED = (
    "identity.txt",
    "radio-props.txt",
    "data-settings.txt",
    "ims-package.txt",
    "ims-routing.txt",
    "ims-package-dumpsys.txt",
    "carrier-config.txt",
    "telephony.txt",
    "connectivity.txt",
    "high-signal.txt",
)
RADIO_KEYS = re.compile(
    r"CIREGU|ImsRegistration|setImsRegistrationState|setupDataCall|"
    r"requestSetupDataCall|DataCall|ccmni|REGISTRATION_STATE|RegStateResult|"
    r"ServiceState|rejectCause|reasonForDenial|ERROR_UNSPECIFIED|"
    r"MtkDynamicImsService|MtkMmTelFeature|ImsService|ImsResolver|IMS|VOLTE|"
    r"RIL_UNSOL_ICCID_CHANGED",
    re.I,
)
IPV4 = re.compile(r"(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?")
IPV6_CANDIDATE = re.compile(
    r"(?<![0-9A-Fa-f:])(?:[0-9A-Fa-f]{1,4}:){2,}"
    r"[0-9A-Fa-f:]*(?:/\d{1,3})?(?![0-9A-Fa-f:])"
)
MAC = re.compile(r"(?i)(?<![0-9a-f])(?:[0-9a-f]{2}:){5}[0-9a-f]{2}(?![0-9a-f])")
LABEL_PATTERNS = (
    (re.compile(r"(?i)(\b(?:imei|imsi|iccid|icid|meid|msisdn|eid)\b\s*[:=]\s*)([^\s,}\]]+)"), r"\1<REDACTED>"),
    (re.compile(r"(?i)(\b(?:mCallIncomingNumber|line1Number|voicemailNumber|phoneNumber|number)\s*=\s*)([^,}\]\s]+)"), r"\1<REDACTED>"),
    (re.compile(r"(?i)(\b(?:mCi|mPci|mTac)\s*=\s*)-?\d+"), r"\1<REDACTED_CELL>"),
    (re.compile(r"(?i)(\b(?:BSSID|SSID|wifiBssid|wifiSsid)\s*[:=]\s*)([^\s,}\]]+)"), r"\1<REDACTED>"),
    (re.compile(r"(?i)(\b(?:LinkAddresses|DnsAddresses|PcscfAddresses)\s*:\s*)\[[^\]]*\]"), r"\1[<REDACTED_IPS>]"),
)

def redact_ipv6(text: str) -> str:
    def repl(match: re.Match[str]) -> str:
        token = match.group(0)
        address = token.split("/", 1)[0]
        try:
            parsed = ipaddress.ip_address(address)
        except ValueError:
            return token
        return "<REDACTED_IP>" if parsed.version == 6 else token

    return IPV6_CANDIDATE.sub(repl, text)


def has_ipv6(text: str) -> bool:
    found = False

    def probe(match: re.Match[str]) -> str:
        nonlocal found
        address = match.group(0).split("/", 1)[0]
        try:
            found = ipaddress.ip_address(address).version == 6
        except ValueError:
            pass
        return match.group(0)

    IPV6_CANDIDATE.sub(probe, text)
    return found


def sanitize(text: str) -> str:
    text = re.sub(r"(?i)(\bDUMP=)[0-9A-F]+", r"\1<REDACTED_MODEM_PAYLOAD>", text)
    text = re.sub(r"(?i)(RIL_UNSOL_ICCID_CHANGED\s+)([^\s]+)", r"\1<REDACTED_ICCID>", text)
    text = re.sub(r"(?i)(handleIccidIndication[^\n]*?str:)([^\s,]+)", r"\1<REDACTED_ICCID>", text)
    text = re.sub(r"(?i)(\batr:\s*\d*,)([^,\s]*)", r"\1<REDACTED_ATR>", text)
    for pattern, replacement in LABEL_PATTERNS:
        text = pattern.sub(replacement, text)
    text = MAC.sub("<REDACTED_MAC>", text)
    text = IPV4.sub("<REDACTED_IP>", text)
    text = redact_ipv6(text)
    return text

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    src = args.input_dir.resolve()
    dst = args.output_dir.resolve()
    dst.mkdir(parents=True, exist_ok=True)

    for name in CURATED:
        path = src / name
        if not path.is_file():
            raise SystemExit(f"missing required capture: {path}")
        (dst / name).write_text(sanitize(path.read_text(errors="replace")))

    radio = src / "radio-log.txt"
    if not radio.is_file():
        raise SystemExit(f"missing required capture: {radio}")
    selected = [
        line for line in radio.read_text(errors="replace").splitlines()
        if RADIO_KEYS.search(line)
    ]
    (dst / "radio-high-signal.txt").write_text(
        sanitize("\n".join(selected) + "\n")
    )

    combined = "\n".join(
        path.read_text(errors="replace")
        for path in dst.iterdir()
        if path.is_file()
    )
    checks = {
        "raw_iccid_prefix_890124": bool(re.search(r"890124\d", combined)),
        "imei_label_with_digits": bool(re.search(r"(?i)imei\s*[:=]\s*\d", combined)),
        "imsi_label_with_digits": bool(re.search(r"(?i)imsi\s*[:=]\s*\d", combined)),
        "literal_ipv4": bool(IPV4.search(combined)),
        "literal_mac": bool(MAC.search(combined)),
        "literal_ipv6": has_ipv6(combined),
        "unredacted_cell_id": bool(re.search(r"\bm(?:Ci|Pci|Tac)=\d+", combined)),
        "modem_dump_payload": bool(re.search(r"\bDUMP=[0-9A-F]{16,}", combined, re.I)),
    }
    report = "\n".join(
        f"{key}={'FAIL' if hit else 'PASS'}" for key, hit in checks.items()
    ) + "\n"
    (dst / "SANITIZATION_CHECKS.txt").write_text(report)
    if any(checks.values()):
        raise SystemExit("sanitization checks failed\n" + report)

    rows = []
    for path in sorted(dst.iterdir()):
        if path.is_file() and path.name != "SHA256SUMS.txt":
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            rows.append(f"{digest}  {path.name}")
    (dst / "SHA256SUMS.txt").write_text("\n".join(rows) + "\n")

    print("TITAN2_STOCK_CAPTURE_SANITIZATION=PASS")
    print(f"OUTPUT={dst}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
