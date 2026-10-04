#!/usr/bin/env python3
"""N1I-B sanitizer self-test (synthetic fixtures only).

Prints one line per case:  CASE<TAB>sanitizer<TAB>case_id<TAB>PASS|FAIL<TAB>detail
Exit 0 only if every case passes.
"""
from __future__ import annotations

import hashlib
import importlib.util
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path(subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"], text=True).strip())
SAN = ROOT / "build/titan2/sanitize-n1i-stock-control.py"
FIX = HERE / "fixtures/sanitizer"
BASE = "8adfac494380d36dcf1951bcef4adb9dca106b5e"
SERIAL = "SYNTHSERIAL0003"
FAILS = 0


def case(cid: str, ok: bool, detail: str = "") -> None:
    global FAILS
    detail = detail.replace("\t", " ").replace("\n", " ")
    print(f"CASE\tsanitizer\t{cid}\t{'PASS' if ok else 'FAIL'}\t{detail}")
    if not ok:
        FAILS += 1


def load():
    spec = importlib.util.spec_from_file_location("san", SAN)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SAN), *args], capture_output=True, text=True)


def planted() -> list[tuple[str, str, str]]:
    rows = []
    for line in (FIX / "planted.tsv").read_text().splitlines():
        if line.startswith("#") or not line.strip():
            continue
        cls, secret, sample = line.split("\t")
        rows.append((cls, secret, sample))
    return rows


def all_text(root: Path) -> str:
    return "\n".join(p.read_text(errors="replace") for p in sorted(root.rglob("*")) if p.is_file())


def main() -> int:
    san = load()
    rows = planted()
    classes = set(san.VERIFY_CLASS_NAMES)
    raw = FIX / "raw"
    raw_text = all_text(raw)

    # -- fixture completeness: every prohibited class is planted, every planted value is in raw
    planted_classes = {c for c, _, _ in rows}
    missing = sorted(classes - planted_classes - {"unverifiable_binary"})
    case("fixture_plants_every_class", not missing, f"classes={len(classes)} missing={missing}")
    unknown = sorted(planted_classes - classes)
    case("fixture_planted_classes_known", not unknown, f"unknown={unknown}")
    absent = [s for _, s, _ in rows if s not in raw_text]
    case("fixture_planted_values_present_in_raw", not absent, f"absent={absent}")

    # -- verify detects every class in the raw (unsanitized) fixture
    found = san.verify_tree(raw, (SERIAL,))
    undetected = sorted(c for c in classes if not found[c])
    case("verify_raw_flags_every_class", not undetected, f"undetected={undetected}")
    for c in sorted(classes):
        case(f"verify_raw_detects:{c}", bool(found[c]), f"hits={len(found[c])}")
    r = run("--verify", str(raw), "--serial", SERIAL)
    case("verify_cli_raw_exit1", r.returncode == 1 and "N1I_B1_SANITIZATION_VERIFY=FAIL" in r.stdout, f"rc={r.returncode}")
    leaked = [s for _, s, _ in rows if s in r.stdout + r.stderr]
    case("verify_report_never_echoes_values", not leaked, f"leaked={leaked}")

    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        out = td / "out"
        r = run("--tree", str(raw), str(out), "--serial", SERIAL)
        case("tree_exit0_pass", r.returncode == 0 and "N1I_B1_CAPTURE_SANITIZATION=PASS" in r.stdout,
             f"rc={r.returncode} {r.stderr.strip()[-200:]}")
        out_text = all_text(out)
        leaked = [s for _, s, _ in rows if s in out_text]
        case("tree_removes_every_planted_value", not leaked, f"leaked={leaked}")
        for cls, secret, _ in rows:
            case(f"tree_removed:{cls}:{secret[:12]}", secret not in out_text, "")
        keep = [k for k in (FIX / "must_keep.txt").read_text().splitlines() if k and not k.startswith("#")]
        lost = [k for k in keep if k not in out_text]
        case("tree_preserves_required_facts", not lost, f"lost={lost}")
        case("tree_binary_not_copied", not (out / "bugreport-fragment.bin").exists()
             and "bugreport-fragment.bin" in (out / "SKIPPED_BINARY_NOT_COPIED.txt").read_text(), "")
        checks = (out / "SANITIZATION_CHECKS.txt").read_text()
        case("tree_checks_all_pass", "FAIL" not in checks and checks.count("=PASS") == len(classes), "")
        sums_ok = True
        for line in (out / "SHA256SUMS.txt").read_text().splitlines():
            digest, rel = line.split("  ", 1)
            sums_ok &= hashlib.sha256((out / rel).read_bytes()).hexdigest() == digest
        case("tree_sha256sums_consistent", sums_ok, "")
        r = run("--verify", str(out), "--serial", SERIAL)
        case("verify_cli_sanitized_exit0", r.returncode == 0, f"rc={r.returncode}")

        # -- idempotence
        once = san.sanitize_strict(raw_text, (SERIAL,))
        case("strict_idempotent", san.sanitize_strict(once, (SERIAL,)) == once, "")

        # -- per-class mutation: an unredacted planted line inserted into clean output is caught
        for cls, secret, sample in rows:
            mut = td / f"mut-{cls}-{hashlib.sha256(sample.encode()).hexdigest()[:8]}"
            shutil.copytree(out, mut)
            (mut / "T1" / "injected.txt").write_text(f"clean line\n{sample}\n")
            hits = san.verify_tree(mut, (SERIAL,))
            r = run("--verify", str(mut), "--serial", SERIAL)
            case(f"verify_detects_injected:{cls}:{secret[:12]}",
                 bool(hits[cls]) and r.returncode == 1 and f"{cls}=FAIL" in r.stdout,
                 f"class_hits={len(hits[cls])} rc={r.returncode}")
        mut = td / "mut-binary"
        shutil.copytree(out, mut)
        (mut / "blob.dat").write_bytes(b"\x00\x01binary")
        r = run("--verify", str(mut))
        case("verify_detects_injected:unverifiable_binary", r.returncode == 1 and "unverifiable_binary=FAIL" in r.stdout, "")

        # -- fail-closed path handling
        r = run("--tree", str(raw), str(raw / "nested-out"))
        case("tree_refuses_output_inside_input", r.returncode != 0 and not (raw / "nested-out").exists(), f"rc={r.returncode}")
        r = run("--tree", str(raw), str(out))
        case("tree_refuses_nonempty_output", r.returncode != 0, f"rc={r.returncode}")
        r = run("--verify", str(out), "--serial", "ab")
        case("refuses_too_short_serial", r.returncode != 0, f"rc={r.returncode}")

        # -- legacy N1I-F mode is byte-identical to the base commit
        base_src = subprocess.run(["git", "-C", str(ROOT), "show", f"{BASE}:build/titan2/sanitize-n1i-stock-control.py"],
                                  capture_output=True, text=True)
        if base_src.returncode != 0:
            case("legacy_base_available", False, f"base {BASE} not in clone")
        else:
            (td / "base_san.py").write_text(base_src.stdout)
            lb, ln = td / "legacy-base", td / "legacy-new"
            rb = subprocess.run([sys.executable, str(td / "base_san.py"), str(FIX / "legacy-n1i-f"), str(lb)],
                                capture_output=True, text=True)
            rn = run(str(FIX / "legacy-n1i-f"), str(ln))
            case("legacy_mode_exit_codes_equal", rb.returncode == rn.returncode == 0,
                 f"base={rb.returncode} new={rn.returncode} {rn.stderr.strip()[-160:]}")
            names_b = sorted(p.name for p in lb.iterdir()) if lb.exists() else []
            names_n = sorted(p.name for p in ln.iterdir()) if ln.exists() else []
            same = names_b == names_n and names_b and all((lb / n).read_bytes() == (ln / n).read_bytes() for n in names_b)
            case("legacy_mode_outputs_byte_identical", bool(same), f"files={len(names_b)}")
            case("legacy_mode_stdout_marker_unchanged", "TITAN2_STOCK_CAPTURE_SANITIZATION=PASS" in rn.stdout, "")

    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
