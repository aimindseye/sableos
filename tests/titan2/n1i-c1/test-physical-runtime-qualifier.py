#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
QUALIFIER = ROOT / "build" / "titan2" / "qualify-n1i-c1-physical-runtime.py"

proc = subprocess.run(
    [sys.executable, str(QUALIFIER), "--self-test"],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=False,
)
if proc.stdout:
    print(proc.stdout, end="")
if proc.returncode != 0:
    if proc.stderr:
        print(proc.stderr, file=sys.stderr, end="")
    raise SystemExit(proc.returncode)
print("N1I_C1_PHYSICAL_QUALIFIER_TEST=PASS")
