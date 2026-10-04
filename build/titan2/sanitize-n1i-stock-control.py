#!/usr/bin/env python3
"""Sanitize Titan 2 telephony captures for repository reference.

Modes:
  INPUT_DIR OUTPUT_DIR                  legacy N1I-F curated stock-control mode (unchanged)
  --tree INPUT_DIR OUTPUT_DIR [--serial S]...
                                        N1I-B1 strict mode: every text file under INPUT_DIR,
                                        whole-line drops for auth material and message/call
                                        content, per-class verify on the output, fail closed
  --verify DIR [--serial S]...          per-class check only; exit 1 if any class is found

Automated redaction is never a privacy clearance; manual review is still required.
"""
from __future__ import annotations

import argparse
import hashlib
import ipaddress
import re
import sys
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

# ---------------------------------------------------------------------------
# N1I-B1 strict mode (--tree / --verify). The legacy positional mode above is
# unchanged so the committed N1I-F evidence re-sanitizes byte-identically.
# ---------------------------------------------------------------------------
R = "<REDACTED>"

# Whole lines that are dropped, never partially redacted.
AUTH_LINE = re.compile(
    r"(?i:\b(?:authorization|www-authenticate|proxy-authenticate|proxy-authorization)\s*:)"
    r"|\b(?:RAND|AUTN|XRES|AUTS)\b"
    r"|\bRES\s*[=:]"
    r"|(?i:\bnonce\s*[=:])"
    r"|(?i:\b(?:requestIsimAuthentication|getIccAuthentication|iccAuthentication|SIM_AUTH|akaResponse)\b|EAP-AKA)"
)
CONTENT_LINE = re.compile(
    r"(?i)\b(?:messageBody|mMessageBody|getMessageBody|displayMessageBody|userData|mPdu|pdus?|"
    r"sms[ _]body|smsc_address|cnapName|callerDisplayName|mCnapName|contactDisplayName)\b"
    r"|\bbody\s*[=:]"
)
STRICT_SUBS = (
    # getprop identity properties: [key]: [value]
    (re.compile(r"(?i)(\[[\w.]*(?:serialno|iccid|imei|imsi|meid|msisdn|line1|phone_number|eid)[\w.]*\]:\s*\[)[^\]]+(\])"),
     r"\1<REDACTED_ID>\2"),
    # labelled identifiers (label, then = or :)
    (re.compile(r"(?i)(\b(?:imei\d?|imeisv|imsi|iccid|icc_id|iccId|mIccId|icid|meid|msisdn|eid|mEid|card_id|cardId|"
                r"cardString|mCardString|subscriberId|mImsi|line1Number|mLine1Number|voicemailNumber|"
                r"phoneNumber|phone_number|number|mNumber|mCallIncomingNumber|dialString|mDialString|"
                r"address|mAddress|serial|serialno|serialNumber|display_name|displayName|mDisplayName|"
                r"impi|impu|mImpi|mImpu|ims_impi|ims_impu|imsPrivateUserIdentity|imsPublicUserIdentity|"
                r"phone_number_source_\w+|accountName|account_name|mAccountName)\s*[:=]\s*)"
                r"(?!<REDACTED|NULL(?=[,\s}\]]|$))([^\s,}\]][^,}\]\n]*?)(?=\s*(?:,|}|\]|$|\s\w+[:=]))"),
     r"\1<REDACTED>"),
    (re.compile(r"(?i)(\bAccount\s*\{\s*name=)[^,}]+"), r"\1<REDACTED>"),
    # SIP / TEL URIs
    (re.compile(r"(?i)\b(sips?:)(?!<REDACTED)[^@\s;>,\"']+@"), r"\1<REDACTED_USER>@"),
    (re.compile(r"(?i)\b(tel:)(?!<REDACTED)\+?[0-9][0-9\-.()]*"), r"\1<REDACTED_NUMBER>"),
    # cell identity and location
    (re.compile(r"(?i)(\b(?:mCi|mCid|mLac|mTac|mPci|mNci|mBasestationId|mNetworkId|mSystemId|mGlobalCellId|"
                r"globalCellId|cellIdentity|ci|cid|lac|tac|pci|nci)\s*[:=]\s*)-?[0-9A-Fa-f]+\b"),
     r"\1<REDACTED_CELL>"),
    (re.compile(r"(?i)(\b(?:mLatitude|mLongitude|latitude|longitude|lat|lon|lng)\s*[:=]\s*)-?\d+(?:\.\d+)?"),
     r"\1<REDACTED_LOC>"),
    # numbers without labels
    (re.compile(r"(?<!\d)89\d{16,18}[Ff]?(?![0-9A-Za-z])"), "<REDACTED_ICCID>"),
    (re.compile(r"(?<![\w+])\+\d{7,15}(?!\d)"), "<REDACTED_NUMBER>"),
    # Digit runs bordered by hex letters are treated as hashes/digests, not identifiers.
    (re.compile(r"(?<![0-9A-Fa-f])\d{14,}(?![0-9A-Fa-f])"), "<REDACTED_LONG_ID>"),
    # e-mail / NAI
    (re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"), "<REDACTED_EMAIL>"),
)
# APN credentials: only on APN-bearing lines, so unrelated `user=0` fields stay intact.
APN_LINE = re.compile(r"(?i)\bapn\s*=|ApnSetting|\bRow:\s*\d+|content://telephony")
APN_CRED = re.compile(r"(?i)(\b(?:user|password|mUser|mPassword)\s*[:=]\s*)(?!<REDACTED|NULL(?=[,\s}]|$))([^,\s}][^,}]*)")


def sanitize_strict(text: str, serials: tuple[str, ...] = ()) -> str:
    out = []
    for line in text.splitlines(keepends=True):
        body = line.rstrip("\r\n")
        nl = line[len(body):]
        if AUTH_LINE.search(body):
            out.append("<DROPPED_AUTH_LINE>" + nl)
            continue
        if CONTENT_LINE.search(body):
            out.append("<DROPPED_CONTENT_LINE>" + nl)
            continue
        for s in serials:
            if s:
                body = body.replace(s, "<REDACTED_SERIAL>")
        if APN_LINE.search(body):
            body = APN_CRED.sub(r"\1<REDACTED_CREDENTIAL>", body)
        body = sanitize(body)
        for pattern, replacement in STRICT_SUBS:
            body = pattern.sub(replacement, body)
        out.append(body + nl)
    return "".join(out)


# Verify detectors: one per prohibited sensitive-data class. They run on the
# output and must all be clean. Dropped-line markers are skipped.
VERIFY_CLASSES = (
    ("iccid", re.compile(r"(?<!\d)89\d{16,18}[Ff]?(?![0-9A-Za-z])"
                         r"|(?i:\b(?:iccid|icc_id|iccId|mIccId|icid|card_id|cardId)\s*[:=]\s*\[?[0-9A-Fa-f]{6,})"
                         r"|RIL_UNSOL_ICCID_CHANGED\s+(?!<REDACTED)\S")),
    ("imei_imsi_meid", re.compile(r"(?i)\b(?:imei\d?|imeisv|imsi|meid|mImsi|subscriberId)\s*[:=]\s*\[?[0-9A-Fa-f]{6,}"
                                  r"|(?i:\[[\w.]*(?:imei|imsi|meid|iccid|msisdn|line1|eid)[\w.]*\]:\s*\[(?!<REDACTED)[^\]])")),
    ("long_digit_run", re.compile(r"(?<![0-9A-Fa-f])\d{14,}(?![0-9A-Fa-f])")),
    ("e164_number", re.compile(r"(?<![\w+])\+\d{7,15}(?!\d)")),
    ("phone_number_label", re.compile(r"(?i)\b(?:msisdn|line1Number|mLine1Number|phoneNumber|phone_number|number|mNumber|"
                                      r"voicemailNumber|mCallIncomingNumber|dialString|mDialString)\s*[:=]\s*\+?\d{4,}")),
    ("sip_uri_user", re.compile(r"(?i)\bsips?:(?!<REDACTED)[^@\s;>,\"']+@")),
    ("tel_uri", re.compile(r"(?i)\btel:(?!<REDACTED)\+?\d")),
    ("impi_impu", re.compile(r"(?i)\b(?:impi|impu|mImpi|mImpu|ims_impi|ims_impu|imsPrivateUserIdentity|"
                             r"imsPublicUserIdentity)\s*[:=]\s*(?!<REDACTED|NULL)[^\s,}\]]")),
    ("device_serial", re.compile(r"(?i)\[ro\.(?:boot\.)?serialno\]:\s*\[(?!<REDACTED)[^\]]+\]"
                                 r"|(?i:\bserial(?:no|Number)?\s*[:=]\s*(?!<REDACTED|NULL)[A-Za-z0-9])")),
    ("cell_identity", re.compile(r"(?i)\b(?:mCi|mCid|mLac|mTac|mPci|mNci|mBasestationId|mNetworkId|mSystemId|"
                                 r"mGlobalCellId|globalCellId|ci|cid|lac|tac|pci|nci)\s*[:=]\s*-?[0-9A-Fa-f]+\b")),
    ("location", re.compile(r"(?i)\b(?:mLatitude|mLongitude|latitude|longitude|lat|lon|lng)\s*[:=]\s*-?\d")),
    ("siminfo_identity", re.compile(r"(?i)\b(?:display_name|displayName|mDisplayName|cardString|mCardString)\s*[:=]\s*"
                                    r"(?!<REDACTED|NULL(?=[,\s}\]]|$))[^,\s}\]]")),
    ("email_or_account", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"
                                    r"|(?i:\bAccount\s*\{\s*name=(?!<REDACTED))"
                                    r"|(?i:\b(?:accountName|account_name|mAccountName)\s*[:=]\s*(?!<REDACTED|NULL)\S)")),
    ("auth_material", AUTH_LINE),
    ("message_content", CONTENT_LINE),
    ("wifi_ssid_bssid", re.compile(r"(?i)\b(?:BSSID|SSID|wifiBssid|wifiSsid)\s*[:=]\s*(?!<REDACTED)[^\s,}\]]")),
    ("literal_mac", MAC),
    ("literal_ipv4", IPV4),
    ("modem_dump_payload", re.compile(r"(?i)\bDUMP=[0-9A-F]{16,}")),
)
APN_CRED_DETECT = re.compile(r"(?i)\b(?:user|password|mUser|mPassword)\s*[:=]\s*(?!<REDACTED|NULL(?=[,\s}]|$))[^,\s}]")
VERIFY_CLASS_NAMES = tuple(n for n, _ in VERIFY_CLASSES) + ("literal_ipv6", "apn_credential", "literal_serial",
                                                             "unverifiable_binary")


def verify_text(text: str, serials: tuple[str, ...] = ()) -> dict[str, list[int]]:
    """Return {class: [line numbers]} for every class hit in text."""
    hits: dict[str, list[int]] = {n: [] for n in VERIFY_CLASS_NAMES}
    for no, line in enumerate(text.splitlines(), 1):
        if line.startswith(("<DROPPED_AUTH_LINE>", "<DROPPED_CONTENT_LINE>")):
            continue
        for name, rx in VERIFY_CLASSES:
            if rx.search(line):
                hits[name].append(no)
        if has_ipv6(line):
            hits["literal_ipv6"].append(no)
        if APN_LINE.search(line) and APN_CRED_DETECT.search(line):
            hits["apn_credential"].append(no)
        if any(s and s in line for s in serials):
            hits["literal_serial"].append(no)
    return hits


def is_binary(data: bytes) -> bool:
    return b"\x00" in data[:65536]


def verify_tree(root: Path, serials: tuple[str, ...]) -> dict[str, list[str]]:
    """Per-class list of 'relative/path:line' hits across every file under root."""
    found: dict[str, list[str]] = {n: [] for n in VERIFY_CLASS_NAMES}
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        rel = path.relative_to(root).as_posix()
        if rel in ("SANITIZATION_CHECKS.txt", "SHA256SUMS.txt"):
            continue
        data = path.read_bytes()
        if is_binary(data):
            found["unverifiable_binary"].append(rel)
            continue
        for name, lines in verify_text(data.decode("utf-8", errors="replace"), serials).items():
            found[name].extend(f"{rel}:{n}" for n in lines)
    return found


def write_checks(dst: Path, found: dict[str, list[str]]) -> str:
    rows = []
    for name in VERIFY_CLASS_NAMES:
        locs = found[name]
        # Locations only (file:line); matched text is never echoed.
        rows.append(f"{name}={'FAIL' if locs else 'PASS'}" + (f" count={len(locs)} first={locs[0]}" if locs else ""))
    report = "\n".join(rows) + "\n"
    if dst is not None:
        (dst / "SANITIZATION_CHECKS.txt").write_text(report)
    return report


def main_strict(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="sanitize-n1i-stock-control.py",
                                     description="N1I-B1 strict sanitization (--tree) or check (--verify).")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--tree", nargs=2, metavar=("INPUT_DIR", "OUTPUT_DIR"), type=Path)
    mode.add_argument("--verify", metavar="DIR", type=Path)
    parser.add_argument("--serial", action="append", default=[],
                        help="literal device serial to remove/detect (repeatable)")
    args = parser.parse_args(argv)
    serials = tuple(s for s in args.serial if s)
    for s in serials:
        if len(s) < 4:
            raise SystemExit("--serial values shorter than 4 chars are refused (too ambiguous)")

    if args.verify is not None:
        root = args.verify.resolve()
        if not root.is_dir():
            raise SystemExit(f"not a directory: {root}")
        found = verify_tree(root, serials)
        print(write_checks(None, found), end="")
        bad = any(found.values())
        print(f"N1I_B1_SANITIZATION_VERIFY={'FAIL' if bad else 'PASS'}")
        return 1 if bad else 0

    src, dst = (p.resolve() for p in args.tree)
    if not src.is_dir():
        raise SystemExit(f"not a directory: {src}")
    if dst == src or src in dst.parents or dst in src.parents:
        raise SystemExit("OUTPUT_DIR must not be INPUT_DIR, inside it, or contain it")
    if dst.exists() and any(dst.iterdir()):
        raise SystemExit(f"OUTPUT_DIR must be empty or absent: {dst}")
    dst.mkdir(parents=True, exist_ok=True)
    skipped = []
    for path in sorted(p for p in src.rglob("*") if p.is_file()):
        rel = path.relative_to(src)
        data = path.read_bytes()
        if is_binary(data) or path.suffix.lower() in (".zip", ".gz", ".tar", ".png", ".jpg"):
            skipped.append(rel.as_posix())
            continue
        out = dst / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(sanitize_strict(data.decode("utf-8", errors="replace"), serials))
    (dst / "SKIPPED_BINARY_NOT_COPIED.txt").write_text("".join(f"{s}\n" for s in skipped))
    found = verify_tree(dst, serials)
    report = write_checks(dst, found)
    if any(found.values()):
        raise SystemExit("N1I_B1_CAPTURE_SANITIZATION=FAIL\n" + report)
    rows = []
    for path in sorted(p for p in dst.rglob("*") if p.is_file()):
        rel = path.relative_to(dst).as_posix()
        if rel != "SHA256SUMS.txt":
            rows.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {rel}")
    (dst / "SHA256SUMS.txt").write_text("\n".join(rows) + "\n")
    print("N1I_B1_CAPTURE_SANITIZATION=PASS")
    print("PRIVACY_REVIEW=REQUIRED_BEFORE_SHARING")
    print(f"OUTPUT={dst}")
    return 0


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
    if any(a in ("--tree", "--verify") for a in sys.argv[1:]):
        raise SystemExit(main_strict(sys.argv[1:]))
    raise SystemExit(main())
