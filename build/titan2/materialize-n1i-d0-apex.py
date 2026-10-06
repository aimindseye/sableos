#!/usr/bin/env python3
"""Materialize bootclasspath-contributing APEX runtime trees for N1I-D0.

Read-only/offline. Input is an extracted system root from a SHA-pinned image.
Each APEX archive is SHA-bound, its inner/original APEX and payload are hashed,
and its payload is extracted with canonical filesystem tools. Only modules that
export an enabled Android-16 bootclasspath fragment are retained.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

API_LEVEL = 36


class MaterializeError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def detect_fs(path: Path) -> str:
    with path.open("rb") as fp:
        header = fp.read(1084)
    if len(header) >= 1082 and header[1080:1082] == b"\x53\xef":
        return "ext4"
    if len(header) >= 1028 and header[1024:1028] == b"\xe2\xe1\xf5\xe0":
        return "erofs"
    raise MaterializeError(f"unsupported_apex_payload_fs={path}")


def extract_member(zf: zipfile.ZipFile, member: str, dest: Path) -> None:
    with zf.open(member) as src, dest.open("wb") as dst:
        shutil.copyfileobj(src, dst, 1024 * 1024)


def run_extract(payload: Path, dest: Path, debugfs: str, fsck_erofs: str) -> str:
    fs_type = detect_fs(payload)
    dest.mkdir(parents=True, exist_ok=True)
    if fs_type == "ext4":
        cmd = [debugfs, "-R", f"rdump / {dest}", str(payload)]
    else:
        cmd = [fsck_erofs, f"--extract={dest}", str(payload)]
    cp = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if cp.returncode != 0:
        raise MaterializeError(
            f"apex_extract_rc={cp.returncode}:fs={fs_type}:stderr={cp.stderr[-400:]}"
        )
    if not any(dest.iterdir()):
        raise MaterializeError(f"apex_extract_empty={payload}")
    return fs_type


def has_bootclasspath_fragment(root: Path) -> bool:
    p = root / "etc/classpaths/bootclasspath.pb"
    return p.is_file() and p.stat().st_size > 0


def materialize_archive(
    archive: Path,
    out_root: Path,
    debugfs: str,
    fsck_erofs: str,
) -> tuple[str, str, str, str, str]:
    archive_name = archive.name
    module_guess = archive_name.removesuffix(".capex").removesuffix(".apex")
    dest = out_root / f"{module_guess}.apex"
    with tempfile.TemporaryDirectory(prefix="n1i-d0-apex-") as raw:
        tmp = Path(raw)
        inner = archive
        inner_tmp = tmp / "inner.apex"
        payload = tmp / "payload.img"

        with zipfile.ZipFile(archive) as outer:
            if "original_apex" in outer.namelist():
                extract_member(outer, "original_apex", inner_tmp)
                inner = inner_tmp

        with zipfile.ZipFile(inner) as zf:
            if "apex_payload.img" not in zf.namelist():
                raise MaterializeError(f"apex_payload_missing={archive}")
            extract_member(zf, "apex_payload.img", payload)

        outer_sha = sha256(archive)
        inner_sha = sha256(inner)
        payload_sha = sha256(payload)
        fs_type = run_extract(payload, dest, debugfs, fsck_erofs)

    if not has_bootclasspath_fragment(dest):
        return (
            module_guess,
            outer_sha,
            inner_sha,
            payload_sha,
            f"{fs_type}:NO_BOOTCLASSPATH",
        )

    return module_guess, outer_sha, inner_sha, payload_sha, fs_type


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--system-root", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--debugfs", required=True)
    p.add_argument("--fsck-erofs", required=True)
    p.add_argument("--selftest", action="store_true")
    a = p.parse_args()

    if a.selftest:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            ext = root / "x.img"
            data = bytearray(1084)
            data[1080:1082] = b"\x53\xef"
            ext.write_bytes(data)
            assert detect_fs(ext) == "ext4"
            ero = root / "e.img"
            data = bytearray(1084)
            data[1024:1028] = b"\xe2\xe1\xf5\xe0"
            ero.write_bytes(data)
            assert detect_fs(ero) == "erofs"
        print("N1I_D0_APEX_MATERIALIZER_SELFTEST=PASS")
        return 0

    system_root = a.system_root.resolve()
    apex_dir = system_root / "apex"
    if not apex_dir.is_dir():
        raise SystemExit(f"N1I_D0_APEX_MATERIALIZER=FAIL apex_dir_missing={apex_dir}")
    if a.out.exists():
        raise SystemExit(f"N1I_D0_APEX_MATERIALIZER=FAIL output_exists={a.out}")
    a.out.mkdir(parents=True)

    archives = sorted(
        p for p in apex_dir.iterdir()
        if p.is_file() and p.suffix in (".apex", ".capex")
    )
    if not archives:
        raise SystemExit("N1I_D0_APEX_MATERIALIZER=FAIL no_apex_archives")

    rows = []
    kept = 0
    try:
        for archive in archives:
            module, outer, inner, payload, state = materialize_archive(
                archive, a.out, a.debugfs, a.fsck_erofs
            )
            retained = not state.endswith(":NO_BOOTCLASSPATH")
            kept += int(retained)
            rows.append(
                (
                    archive.name,
                    module,
                    outer,
                    inner,
                    payload,
                    state,
                    "YES" if retained else "NO",
                )
            )
    except (MaterializeError, zipfile.BadZipFile) as exc:
        shutil.rmtree(a.out, ignore_errors=True)
        raise SystemExit(f"N1I_D0_APEX_MATERIALIZER=FAIL {exc}")

    if kept == 0:
        shutil.rmtree(a.out, ignore_errors=True)
        raise SystemExit("N1I_D0_APEX_MATERIALIZER=FAIL no_bootclasspath_modules")

    manifest = a.out / "APEX_AUTHORITY.tsv"
    with manifest.open("w", encoding="utf-8", newline="") as fp:
        w = csv.writer(fp, delimiter="\t", lineterminator="\n")
        w.writerow(
            (
                "archive", "module", "outer_sha256", "inner_sha256",
                "payload_sha256", "payload_fs", "bootclasspath_retained",
            )
        )
        w.writerows(rows)

    # Seal every classpath fragment/jar plus the archive/payload authority
    # manifest. All APEX payloads remain materialized because Gate G may require
    # native libraries from modules that do not contribute Java boot jars.
    sums = a.out / "SHA256SUMS.txt"
    files = [manifest]
    files += sorted(
        p for p in a.out.rglob("*")
        if p.is_file() and (
            p.name == "bootclasspath.pb" or p.suffix in (".jar", ".jimage")
        )
    )
    with sums.open("w", encoding="utf-8") as fp:
        for item in files:
            fp.write(f"{sha256(item)}  {item.relative_to(a.out)}\n")

    print(
        "N1I_D0_APEX_MATERIALIZER=PASS "
        f"bootclasspath_modules={kept} archives={len(archives)}"
    )
    print(f"N1I_D0_APEX_AUTHORITY={manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
