#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import sys

from n1i_c1_physical_evidence import QualificationError, load_env
from n1i_c1_physical_eval import evaluate_all, write_outputs
from n1i_c1_physical_selftest import run_self_test


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--tray1", type=pathlib.Path)
    p.add_argument("--tray2", type=pathlib.Path)
    p.add_argument("--dsds", type=pathlib.Path)
    p.add_argument("--operator-results", type=pathlib.Path)
    p.add_argument("--out", type=pathlib.Path)
    p.add_argument("--self-test", action="store_true")
    args = p.parse_args()
    if args.self_test:
        return run_self_test()
    required = ("tray1", "tray2", "dsds", "operator_results", "out")
    missing = [k for k in required if getattr(args, k) is None]
    if missing:
        p.error("missing required arguments: " + ", ".join(missing))
    try:
        op = load_env(args.operator_results)
        results, meta = evaluate_all(args.tray1, args.tray2, args.dsds, op)
        return write_outputs(results, meta, args.out)
    except QualificationError as exc:
        print(f"N1I_C1_PHYSICAL_RUNTIME_QUALIFICATION=FAIL reason={exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
