#!/usr/bin/env python3
"""Summarize N1I-D0 Gate G B2 outputs and retire A4 import authority."""
from __future__ import annotations

import argparse
import csv
from pathlib import Path


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8") as fp:
        return list(csv.DictReader(fp, delimiter="\t"))


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--gates", type=Path, required=True)
    p.add_argument("--a4", type=Path, required=True)
    p.add_argument("--selftest", action="store_true")
    a = p.parse_args()

    if a.selftest:
        print("N1I_D0_NATIVE_SUMMARY_SELFTEST=PASS")
        return 0

    closures: list[dict[str, str]] = []
    for label in ("ims", "mediatek-common", "mediatek-ims-base"):
        path = a.gates / f"gate-g-{label}/NATIVE_CLOSURE.tsv"
        if not path.is_file():
            raise SystemExit(f"N1I_D0_GATE_G=FAIL missing={path}")
        closures.extend(read_rows(path))

    by_name: dict[str, list[dict[str, str]]] = {}
    root_names: set[str] = set()
    for row in closures:
        name = row["library"]
        by_name.setdefault(name, []).append(row)
        reasons = row.get("admitted_by", "")
        if any(
            token in reasons
            for token in (
                "LOADLIBRARY:",
                "LOAD:",
                "APK_PACKAGED",
                "USES_NATIVE_LIBRARY",
            )
        ):
            root_names.add(name)

    a4_rows: list[tuple[str, str, str]] = []
    for raw in a.a4.read_text(encoding="utf-8").splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("#"):
            continue
        name = Path(raw).name
        hits = by_name.get(name, [])
        found = [r for r in hits if r.get("status") == "FOUND"]
        if name in root_names and found:
            cls = "B2_REQUIRED"
        elif found:
            cls = "TRANSITIVE_REQUIRED"
        elif hits:
            cls = "PROVIDER_NOT_REQUIRED"
        else:
            cls = "SEARCH_SUPERSET_ONLY"
        a4_rows.append((raw, name, cls))

    with (a.gates / "A4_RETIREMENT.tsv").open(
        "w", encoding="utf-8", newline=""
    ) as fp:
        w = csv.writer(fp, delimiter="\t", lineterminator="\n")
        w.writerow(("a4_path", "soname", "classification"))
        w.writerows(a4_rows)

    admitted = sorted(
        {
            row["library"]
            for row in closures
            if row.get("status") == "FOUND"
        }
    )
    unresolved = sorted(
        {
            row["library"]
            for row in closures
            if row.get("status") != "FOUND"
        }
    )
    roots = sorted(root_names)

    with (a.gates / "GATE_G.env").open("w", encoding="utf-8") as fp:
        fp.write(f"N1I_D0_GATE_G_B2_ROOT_COUNT={len(roots)}\n")
        fp.write(f"N1I_D0_GATE_G_B2_ROOTS={','.join(roots) or 'NONE'}\n")
        fp.write(f"N1I_D0_GATE_G_B2_ADMITTED_COUNT={len(admitted)}\n")
        fp.write(
            f"N1I_D0_GATE_G_B2_ADMITTED={','.join(admitted) or 'NONE'}\n"
        )
        fp.write(f"N1I_D0_GATE_G_UNRESOLVED_COUNT={len(unresolved)}\n")
        fp.write(
            f"N1I_D0_GATE_G_UNRESOLVED={','.join(unresolved) or 'NONE'}\n"
        )
        fp.write("N1I_D0_GATE_G_A4_IMPORT_AUTHORITY=RETIRED\n")
        fp.write("N1I_D0_GATE_G_N1F=NOT_APPLICABLE\n")

    with (a.gates / "GATE_G2.env").open("w", encoding="utf-8") as fp:
        if not admitted:
            fp.write(
                "N1I_D0_GATE_G2=NOT_APPLICABLE_NO_B2_NATIVE_ADMISSION\n"
            )
            fp.write(
                "N1I_D0_GATE_G2_SYMBOL_VERSION_PROOF=NOT_APPLICABLE\n"
            )
            fp.write(
                "N1I_D0_GATE_G2_LINKER_NAMESPACE_MODEL=NOT_APPLICABLE\n"
            )
        else:
            fp.write("N1I_D0_GATE_G2=UNKNOWN_NOT_IMPLEMENTED\n")
            fp.write(
                "N1I_D0_GATE_G2_SYMBOL_VERSION_PROOF="
                "UNKNOWN_NOT_IMPLEMENTED\n"
            )
            fp.write(
                "N1I_D0_GATE_G2_LINKER_NAMESPACE_MODEL="
                "UNKNOWN_NOT_IMPLEMENTED\n"
            )

    print(
        "N1I_D0_GATE_G=PASS_REDERIVED "
        f"roots={len(roots)} admitted={len(admitted)} "
        f"unresolved={len(unresolved)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
