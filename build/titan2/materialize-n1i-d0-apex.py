#!/usr/bin/env python3
"""Materialize preinstalled APEX payloads for N1I-D0.

Host-only and read-only with respect to inputs. Writes only below --out.
The output directory name is the logical APEX module name plus .apex, matching
what the existing N1I classpath deriver expects.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


class ApexError(Exception):
    pass


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def module_name(path: Path) -> str:
    name = path.name
    for suffix in (".capex", ".apex"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
            break
    return name.split("@", 1)[0]


def payload_fs(path: Path) -> str:
    with path.open("rb") as fp:
        data = fp.read(1084)
    if len(data) >= 1082 and data[1080:1082] == b"\x53\xef":
        return "ext4"
    if len(data) >= 1028 and data[1024:1028] == b"\xe2\xe1\xf5\xe0":
        return "erofs"
    raise ApexError(f"unsupported_payload_fs={path}")


def run(cmd: list[str], log: Path) -> None:
    with log.open("wb") as fp:
        rc = subprocess.run(
            cmd,
            stdout=fp,
            stderr=subprocess.STDOUT,
            check=False,
        ).returncode
    if rc != 0:
        raise ApexError(f"command_rc={rc}:log={log}:cmd={cmd[0]}")


def extract_archive(
    archive: Path,
    dest: Path,
    work: Path,
    debugfs: Path,
    fsck_erofs: Path | None,
) -> tuple[str, str, str, str]:
    outer_sha = sha256(archive)
    inner = archive
    inner_tmp: Path | None = None
    payload = work / f"{dest.name}.payload.img"

    try:
        with zipfile.ZipFile(archive) as outer:
            if "original_apex" in outer.namelist():
                inner_tmp = work / f"{dest.name}.inner.apex"
                with outer.open("original_apex") as src, inner_tmp.open("wb") as dst:
                    shutil.copyfileobj(src, dst, 1024 * 1024)
                inner = inner_tmp

        inner_sha = sha256(inner)
        with zipfile.ZipFile(inner) as zf:
            if "apex_payload.img" not in zf.namelist():
                raise ApexError(f"apex_payload_missing={archive}")
            with zf.open("apex_payload.img") as src, payload.open("wb") as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)

        payload_sha = sha256(payload)
        fs = payload_fs(payload)
        dest.mkdir(parents=True)

        if fs == "ext4":
            run(
                [str(debugfs), "-R", f"rdump / {dest}", str(payload)],
                work / f"{dest.name}.debugfs.log",
            )
        else:
            if fsck_erofs is None or not fsck_erofs.is_file():
                raise ApexError("fsck_erofs_missing_for_erofs_apex")
            run(
                [str(fsck_erofs), f"--extract={dest}", str(payload)],
                work / f"{dest.name}.erofs.log",
            )

        if not any(dest.iterdir()):
            raise ApexError(f"apex_extract_empty={archive}")
        return outer_sha, inner_sha, payload_sha, fs
    finally:
        payload.unlink(missing_ok=True)
        if inner_tmp is not None:
            inner_tmp.unlink(missing_ok=True)


def discover(roots: list[Path]) -> list[Path]:
    found: dict[str, Path] = {}
    for root in roots:
        if not root.is_dir():
            raise ApexError(f"root_missing={root}")
        candidates = sorted(
            p
            for p in root.rglob("*")
            if p.is_file() and p.suffix in (".apex", ".capex")
        )
        for path in candidates:
            # Only preinstalled APEX locations, never arbitrary archives.
            parts = path.parts
            if "apex" not in parts:
                continue
            mod = module_name(path)
            previous = found.get(mod)
            if previous is not None and previous.resolve() != path.resolve():
                raise ApexError(
                    f"duplicate_preinstalled_apex_module={mod}:{previous}:{path}"
                )
            found[mod] = path
    return [found[k] for k in sorted(found)]


def selftest() -> int:
    assert module_name(Path("com.android.art.apex")) == "com.android.art"
    assert module_name(Path("com.android.art@360000000.capex")) == "com.android.art"
    print("N1I_D0_APEX_MATERIALIZER_SELFTEST=PASS")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, action="append", default=[])
    ap.add_argument("--out", type=Path)
    ap.add_argument("--debugfs", type=Path)
    ap.add_argument("--fsck-erofs", type=Path)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if not args.root or args.out is None or args.debugfs is None:
        ap.error("--root, --out and --debugfs are required")
    if not args.debugfs.is_file():
        raise ApexError(f"debugfs_missing={args.debugfs}")

    out = args.out.resolve()
    if out.exists():
        raise ApexError(f"output_exists={out}")
    out.mkdir(parents=True)
    work = out / ".work"
    work.mkdir()

    rows: list[list[str]] = []
    try:
        archives = discover([p.resolve() for p in args.root])
        if not archives:
            raise ApexError("no_preinstalled_apex_archives")

        for archive in archives:
            mod = module_name(archive)
            dest = out / f"{mod}.apex"
            outer_sha, inner_sha, payload_sha, fs = extract_archive(
                archive.resolve(),
                dest,
                work,
                args.debugfs.resolve(),
                args.fsck_erofs.resolve()
                if args.fsck_erofs is not None and args.fsck_erofs.is_file()
                else None,
            )
            rows.append(
                [
                    mod,
                    str(archive.resolve()),
                    outer_sha,
                    inner_sha,
                    payload_sha,
                    fs,
                ]
            )

        with (out / "APEX_MANIFEST.tsv").open(
            "w",
            encoding="utf-8",
            newline="",
        ) as fp:
            writer = csv.writer(fp, delimiter="\t", lineterminator="\n")
            writer.writerow(
                [
                    "module",
                    "archive",
                    "outer_sha256",
                    "inner_sha256",
                    "payload_sha256",
                    "payload_fs",
                ]
            )
            writer.writerows(rows)

        sums = []
        for path in sorted(
            p for p in out.rglob("*") if p.is_file() and ".work" not in p.parts
        ):
            sums.append(f"{sha256(path)}  {path.relative_to(out)}\n")
        (out / "SHA256SUMS.txt").write_text("".join(sums), encoding="utf-8")
    finally:
        shutil.rmtree(work, ignore_errors=True)

    print(f"N1I_D0_APEX_MATERIALIZE=PASS modules={len(rows)}")
    print(f"N1I_D0_APEX_ROOT={out}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ApexError, OSError, zipfile.BadZipFile) as exc:
        print(f"N1I_D0_APEX_MATERIALIZE=FAIL reason={exc}")
        raise SystemExit(2)
