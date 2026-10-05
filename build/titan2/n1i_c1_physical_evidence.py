from __future__ import annotations

import csv
import pathlib
import re

IMAGE_SOURCE_COMMIT = "a745c7daa08267d851f45785a5bb7ff762ed4604"
SCENARIOS = ("tray1", "tray2", "dsds")
SURFACES = (
    "REGISTRATION", "DATA", "SMS_MMS", "IMS_PROVIDER", "IMS_REGISTRATION",
    "IMS_BEARER", "OUTGOING_VOICE", "INCOMING_VOICE",
)


class QualificationError(RuntimeError):
    pass


def load_env(path: pathlib.Path) -> dict[str, str]:
    if not path.is_file():
        raise QualificationError(f"missing env file: {path}")
    out: dict[str, str] = {}
    for n, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise QualificationError(f"invalid env line {path}:{n}")
        key, value = line.split("=", 1)
        if not re.fullmatch(r"[A-Z0-9_.-]+", key):
            raise QualificationError(f"invalid env key {path}:{n}:{key}")
        if key in out:
            raise QualificationError(f"duplicate env key {path}:{key}")
        out[key] = value.strip()
    return out


def text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""


def parse_getprop(raw: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in raw.splitlines():
        m = re.match(r"^\[([^]]+)\]: \[(.*)\]$", line.strip())
        if m:
            out[m.group(1)] = m.group(2)
        elif "=" in line:
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def timeline_rows(root: pathlib.Path) -> list[dict[str, str]]:
    p = root / "be2" / "redacted" / "timeline.tsv"
    if not p.is_file():
        raise QualificationError(f"missing BE2 timeline: {p}")
    with p.open(encoding="utf-8", errors="replace", newline="") as fp:
        return list(csv.DictReader(fp, delimiter="\t"))


def final_phone_rows(rows: list[dict[str, str]], phone_id: int, count: int = 3) -> list[dict[str, str]]:
    return [r for r in rows if r.get("phone_id") == str(phone_id)][-count:]


def stable_registration(rows: list[dict[str, str]], phone_id: int) -> bool:
    tail = final_phone_rows(rows, phone_id)
    return len(tail) >= 3 and all(
        r.get("voice_reg") == "IN_SERVICE" and r.get("data_reg") == "IN_SERVICE" for r in tail
    )


def stable_data_connected(rows: list[dict[str, str]], phone_id: int) -> bool:
    tail = final_phone_rows(rows, phone_id)
    return len(tail) >= 3 and all(r.get("data_conn") == "CONNECTED" for r in tail)


def ever_data_connected(rows: list[dict[str, str]], phone_id: int, count: int = 3) -> bool:
    run = 0
    for row in rows:
        if row.get("phone_id") != str(phone_id):
            continue
        if (
            row.get("voice_reg") == "IN_SERVICE"
            and row.get("data_reg") == "IN_SERVICE"
            and row.get("data_conn") == "CONNECTED"
        ):
            run += 1
            if run >= count:
                return True
        else:
            run = 0
    return False


def cellular_validated(connectivity: str) -> bool:
    return bool(
        re.search(r"(?is)CELLULAR.{0,2500}VALIDATED", connectivity)
        or re.search(r"(?is)VALIDATED.{0,2500}CELLULAR", connectivity)
    )


def ims_provider_present(package_dump: str, path_dump: str) -> bool:
    package_ok = "com.mediatek.ims" in package_dump
    shared_uid_ok = bool(
        re.search(r"(?i)(sharedUserId|sharedUser)[^\n]*android\.uid\.phone", package_dump)
        or "android.uid.phone" in package_dump
    )
    privileged_ok = "PRIVILEGED" in package_dump.upper() or "priv-app" in path_dump
    path_ok = bool(re.search(r"package:/system_ext/priv-app/ImsService/ImsService\.apk", path_dump))
    return package_ok and shared_uid_ok and privileged_ok and path_ok


def slot_provider_present(end: pathlib.Path, slot: int) -> bool:
    device = text(end / f"ims_slot{slot}_device.txt")
    carrier = text(end / f"ims_slot{slot}_carrier.txt")
    return "com.mediatek.ims" in device or "com.mediatek.ims" in carrier


def phone_registry_block(registry: str, phone_id: int) -> str:
    matches = list(re.finditer(rf"(?i)(phoneId|phone_id|slotId|slot_id)\s*[=:]\s*{phone_id}\b", registry))
    return "\n".join(
        registry[max(0, m.start() - 1200): min(len(registry), m.end() + 2200)] for m in matches
    )


def ims_registered_for_phone(registry: str, phone_id: int) -> bool:
    block = phone_registry_block(registry, phone_id)
    return bool(block) and bool(
        re.search(r"(?i)\b(m?ImsRegistered|imsRegistrationState)\s*[=:]\s*(true|REGISTERED|1)\b", block)
        or re.search(r"(?i)IMS[^\n]{0,120}\bregistered\s*[=:]\s*true\b", block)
    )


def last_ims_log_state(log: str) -> bool | None:
    events: list[bool] = []
    for line in log.splitlines():
        m = re.search(r"setImsRegistrationState[^\n]*registered\s*=\s*(true|false)", line, re.I)
        if m:
            events.append(m.group(1).lower() == "true")
            continue
        m = re.search(r"\b(m?ImsRegistered|imsRegistrationState)\s*[=:]\s*(true|false|REGISTERED|NOT_REGISTERED|0|1)\b", line, re.I)
        if m:
            events.append(m.group(2).lower() in {"true", "registered", "1"})
            continue
        m = re.search(r"\+CIREGU:\s*1,([0-9a-fA-F]+)", line)
        if m:
            events.append(m.group(1).lower() in {"7", "f"})
    return events[-1] if events else None


def ims_registered_end_state(registry: str, phone_id: int, log: str) -> bool:
    block = phone_registry_block(registry, phone_id)
    if block:
        explicit_false = bool(
            re.search(r"(?i)\b(m?ImsRegistered|imsRegistrationState)\s*[=:]\s*(false|NOT_REGISTERED|0)\b", block)
            or re.search(r"(?i)IMS[^\n]{0,120}\bregistered\s*[=:]\s*false\b", block)
        )
        if explicit_false:
            return False
        if ims_registered_for_phone(registry, phone_id):
            return True
    state = last_ims_log_state(log)
    return state is True


def ims_bearer_blocks(connectivity: str) -> list[str]:
    chunks = re.split(r"\n\s*\n|(?=NetworkAgentInfo\{)|(?=NetworkAgentInfo\[)", connectivity)
    good = [
        c for c in chunks
        if "CELLULAR" in c.upper()
        and "IMS" in c.upper()
        and "MMTEL" in c.upper()
        and ("CONNECTED" in c.upper() or "VALIDATED" in c.upper())
    ]
    if good:
        return good
    out: list[str] = []
    for m in re.finditer(r"MMTEL", connectivity, re.IGNORECASE):
        chunk = connectivity[max(0, m.start() - 1200): min(len(connectivity), m.end() + 1200)]
        upper = chunk.upper()
        if "CELLULAR" in upper and "IMS" in upper and ("CONNECTED" in upper or "VALIDATED" in upper):
            out.append(chunk)
    return out


def ims_bearer_count(connectivity: str) -> int:
    blocks = ims_bearer_blocks(connectivity)
    if not blocks:
        return 0
    interfaces: set[str] = set()
    for block in blocks:
        interfaces.update(re.findall(r"\bccmni\d+\b", block))
    if interfaces:
        return len(interfaces)
    return len({re.sub(r"\s+", " ", b.strip())[:600] for b in blocks})


def operator_pass(op: dict[str, str], *keys: str) -> bool:
    return all(op.get(k) == "PASS" for k in keys)


def expected_sim_state(scenario: str) -> str:
    return {"tray1": "LOADED,ABSENT", "tray2": "ABSENT,LOADED", "dsds": "LOADED,LOADED"}[scenario]


def scenario_prefix(scenario: str) -> str:
    return {"tray1": "TRAY1", "tray2": "TRAY2", "dsds": "DSDS"}[scenario]


def verdict(ok: bool) -> str:
    return "PASS" if ok else "FAIL"
