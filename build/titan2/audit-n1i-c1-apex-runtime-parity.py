#!/usr/bin/env python3
"""Audit C3A -> C1 APEX runtime parity for the N1I-C1 Java linkage model.

This is a host-only, read-only diagnostic. It does not build, contact a
device, fetch from the network, or mutate source. It compares every
bootclasspath-contributing APEX present in the fresh V6 N1I-A/C3A replay with
the corresponding packaged C1 APEX at four layers:

  * outer .apex/.capex archive bytes;
  * inner APEX bytes (after .capex original_apex, when applicable);
  * apex_payload.img bytes;
  * bootclasspath.pb plus every enabled Java boot jar.

An outer archive mismatch alone is not a Java linkage failure. The decisive
result for the member-linkage model is N1I_C1_APEX_JAVA_BOOT_RUNTIME_PARITY.
Payload mismatch remains separately visible because non-Java APEX contents may
still differ even when the Java boot jars are identical.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

EXPECTED_C1_SHA = (
    "137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
)
API_LEVEL = 36


class AuditError(Exception):
    pass


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def detect_payload_fs(path: Path) -> str:
    with path.open("rb") as fp:
        header = fp.read(1084)
    if len(header) >= 1082 and header[1080:1082] == b"\x53\xef":
        return "ext4"
    if len(header) >= 1028 and header[1024:1028] == b"\xe2\xe1\xf5\xe0":
        return "erofs"
    raise AuditError(f"unsupported_apex_payload_fs={path}")


def extract_zip_member(
    zf: zipfile.ZipFile,
    member: str,
    dest: Path,
) -> None:
    with zf.open(member) as src, dest.open("wb") as dst:
        shutil.copyfileobj(src, dst, 1024 * 1024)


def load_deriver(repo: Path):
    path = repo / "build/titan2/derive-n1i-c1-runtime-classpath.py"
    spec = importlib.util.spec_from_file_location("n1i_c1_deriver", path)
    if spec is None or spec.loader is None:
        raise AuditError(f"cannot_load_deriver={path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def materialize_layers(
    archive: Path,
    key: str,
    work: Path,
    logs: Path,
    extract_root: Path | None,
) -> tuple[str, str, str, str]:
    safe = key.replace("/", "_")
    inner_tmp = work / f"{safe}.inner.apex"
    payload_tmp = work / f"{safe}.payload.img"

    outer_sha = sha256(archive)
    inner_path = archive
    inner_is_temp = False

    try:
        with zipfile.ZipFile(archive) as outer:
            if "original_apex" in outer.namelist():
                extract_zip_member(outer, "original_apex", inner_tmp)
                inner_path = inner_tmp
                inner_is_temp = True

        inner_sha = sha256(inner_path)
        with zipfile.ZipFile(inner_path) as inner:
            if "apex_payload.img" not in inner.namelist():
                raise AuditError(f"apex_payload_missing={archive}")
            extract_zip_member(inner, "apex_payload.img", payload_tmp)

        payload_sha = sha256(payload_tmp)
        fs_type = detect_payload_fs(payload_tmp)

        if extract_root is not None:
            extract_root.mkdir(parents=True)
            log = logs / f"{safe}.{fs_type}.log"
            if fs_type == "ext4":
                tool = shutil.which("debugfs")
                if not tool:
                    raise AuditError("required_tool_missing=debugfs")
                cmd = [
                    tool,
                    "-R",
                    f"rdump / {extract_root}",
                    str(payload_tmp),
                ]
            else:
                tool = shutil.which("fsck.erofs")
                if not tool:
                    raise AuditError("required_tool_missing=fsck.erofs")
                cmd = [
                    tool,
                    f"--extract={extract_root}",
                    str(payload_tmp),
                ]

            with log.open("wb") as fp:
                rc = subprocess.run(
                    cmd,
                    stdout=fp,
                    stderr=subprocess.STDOUT,
                    check=False,
                ).returncode
            if rc != 0:
                raise AuditError(
                    f"apex_payload_extract_rc={rc}:archive={archive}:log={log}"
                )
            if not any(extract_root.iterdir()):
                raise AuditError(f"apex_payload_extract_empty={archive}")

        return outer_sha, inner_sha, payload_sha, fs_type
    finally:
        payload_tmp.unlink(missing_ok=True)
        if inner_is_temp:
            inner_tmp.unlink(missing_ok=True)


def read_env(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        if "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        result[key] = value.strip().strip('"')
    return result


def selftest() -> int:
    import tempfile

    with tempfile.TemporaryDirectory() as raw:
        root = Path(raw)

        ext4 = root / "ext4.img"
        data = bytearray(1084)
        data[1080:1082] = b"\x53\xef"
        ext4.write_bytes(data)
        assert detect_payload_fs(ext4) == "ext4"

        erofs = root / "erofs.img"
        data = bytearray(1084)
        data[1024:1028] = b"\xe2\xe1\xf5\xe0"
        erofs.write_bytes(data)
        assert detect_payload_fs(erofs) == "erofs"

    print("N1I_C1_APEX_RUNTIME_PARITY_SELFTEST=PASS")
    return 0


def run(args: argparse.Namespace) -> int:
    repo = args.repo.resolve()
    evidence = args.v6_evidence.resolve()
    product_out = args.product_out.resolve()
    out = args.out.resolve()

    if out.exists():
        raise AuditError(f"output_exists={out}")

    deriver = load_deriver(repo)

    git_head = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    status = subprocess.run(
        [
            "git",
            "-C",
            str(repo),
            "status",
            "--porcelain=v1",
            "--untracked-files=all",
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    if status:
        raise AuditError("source_worktree_not_clean")

    c1_system = product_out / "system.img"
    if not c1_system.is_file():
        raise AuditError(f"c1_system_missing={c1_system}")
    c1_system_sha = sha256(c1_system)
    if c1_system_sha != EXPECTED_C1_SHA:
        raise AuditError("c1_system_sha_mismatch")

    replay = evidence / "n1i-a-replay"
    replay_env = replay / "n1i-a-v010014-oem-ims.env"
    c3a_tree = replay / "work/c3a/system_img"
    c3a_apex_root = replay / "work/apex/c3a"
    for required in (replay_env, c3a_tree, c3a_apex_root):
        if not required.exists():
            raise AuditError(f"v6_replay_input_missing={required}")

    replay_values = read_env(replay_env)
    if (
        replay_values.get("N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE")
        != "PASS"
    ):
        raise AuditError("v6_replay_n1i_a_authority_not_pass")

    c3a_sys = deriver.system_root(c3a_tree)
    c3a_archive_root = c3a_sys / "apex"
    c1_archive_root = product_out / "system/apex"
    if not c3a_archive_root.is_dir():
        raise AuditError(f"c3a_apex_archive_root_missing={c3a_archive_root}")
    if not c1_archive_root.is_dir():
        raise AuditError(f"c1_apex_archive_root_missing={c1_archive_root}")

    fragments = deriver.apex_fragments(c3a_apex_root, API_LEVEL)
    fragments_by_module = {fragment.module: fragment for fragment in fragments}
    if len(fragments_by_module) != len(fragments):
        raise AuditError("duplicate_c3a_apex_module")

    c3a_system_fragment = c3a_sys / "etc/classpaths/bootclasspath.pb"
    c1_system_fragment = product_out / "system/etc/classpaths/bootclasspath.pb"
    if not c3a_system_fragment.is_file():
        raise AuditError(
            f"c3a_system_bootclasspath_missing={c3a_system_fragment}"
        )
    if not c1_system_fragment.is_file():
        raise AuditError(
            f"c1_system_bootclasspath_missing={c1_system_fragment}"
        )

    c3a_system_paths = [
        jar.path
        for jar in deriver.boot_jars(c3a_system_fragment, API_LEVEL)
    ]
    c1_system_paths = [
        jar.path
        for jar in deriver.boot_jars(c1_system_fragment, API_LEVEL)
    ]
    c1_without_imports = [
        path
        for path in c1_system_paths
        if path not in (deriver.COMMON, deriver.IMS_BASE)
    ]
    if c1_without_imports != c3a_system_paths:
        raise AuditError("c1_system_bootclasspath_not_c3a_plus_imports")

    def group_system_apex(paths: list[str]) -> dict[str, list[str]]:
        grouped: dict[str, list[str]] = {}
        for path in paths:
            if not path.startswith("/apex/"):
                continue
            module = deriver.module_from_apex_path(path)
            grouped.setdefault(module, []).append(path)
        return grouped

    c3a_system_apex = group_system_apex(c3a_system_paths)
    c1_system_apex = group_system_apex(c1_without_imports)
    if c1_system_apex != c3a_system_apex:
        raise AuditError("c1_system_apex_exports_differ_from_c3a")

    modules = sorted(set(fragments_by_module) | set(c3a_system_apex))

    out.mkdir(parents=True)
    work = out / "work"
    logs = out / "logs"
    c1_extract_root = work / "c1-apex"
    work.mkdir()
    logs.mkdir()
    c1_extract_root.mkdir()

    print("===== N1I-C1 APEX RUNTIME PARITY =====")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("NETWORK_FETCH_AUTHORIZED=NO")
    print("BUILD_AUTHORIZED=NO")
    print("FLASH_AUTHORIZED=NO")
    print("SOURCE_MUTATION_AUTHORIZED=NO")
    print(f"TOOL_SOURCE_COMMIT={git_head}")
    print(f"V6_EVIDENCE={evidence}")
    print(f"PRODUCT_OUT={product_out}")
    print(f"N1I_C1_APEX_MODULE_COUNT={len(modules)}")

    module_rows: list[list[object]] = []
    jar_rows: list[list[object]] = []

    outer_mismatch = 0
    inner_mismatch = 0
    payload_mismatch = 0
    fragment_mismatch = 0
    path_mismatch = 0
    jar_hash_mismatch = 0

    def ordered_unique(paths: list[str]) -> list[str]:
        seen: set[str] = set()
        result: list[str] = []
        for path in paths:
            if path in seen:
                continue
            seen.add(path)
            result.append(path)
        return result

    for module in modules:
        c3_fragment = fragments_by_module.get(module)
        if c3_fragment is not None:
            c3_root = c3_fragment.root
            c3_owned_paths = [jar.path for jar in c3_fragment.jars]
            c3_fragment_sha = sha256(c3_fragment.fragment)
        else:
            c3_root = deriver.find_extracted_apex_root(
                c3a_apex_root,
                module,
            )
            c3_owned_paths = []
            c3_fragment_sha = "-"

        c3_archive = deriver.find_archive(c3a_archive_root, module)
        c1_archive = deriver.find_archive(c1_archive_root, module)

        c3_outer, c3_inner, c3_payload, c3_fs = materialize_layers(
            c3_archive,
            f"c3a-{module}",
            work,
            logs,
            None,
        )

        c1_root = c1_extract_root / f"{module}.apex"
        c1_outer, c1_inner, c1_payload, c1_fs = materialize_layers(
            c1_archive,
            f"c1-{module}",
            work,
            logs,
            c1_root,
        )

        c1_fragment_path = c1_root / "etc/classpaths/bootclasspath.pb"
        if c1_fragment_path.is_file():
            c1_owned_paths = [
                jar.path
                for jar in deriver.boot_jars(
                    c1_fragment_path,
                    API_LEVEL,
                )
            ]
            c1_fragment_sha = sha256(c1_fragment_path)
        else:
            c1_owned_paths = []
            c1_fragment_sha = "-"

        if c3_fragment is not None and not c1_fragment_path.is_file():
            raise AuditError(
                f"c1_bootclasspath_fragment_missing="
                f"{module}:{c1_fragment_path}"
            )

        c3_system_paths = c3a_system_apex.get(module, [])
        c1_module_system_paths = c1_system_apex.get(module, [])
        c3_paths = ordered_unique(c3_owned_paths + c3_system_paths)
        c1_paths = ordered_unique(
            c1_owned_paths + c1_module_system_paths
        )

        outer_equal = c3_outer == c1_outer
        inner_equal = c3_inner == c1_inner
        payload_equal = c3_payload == c1_payload
        fragment_equal = (
            c3_fragment_sha == c1_fragment_sha
            and c3_owned_paths == c1_owned_paths
        )
        paths_equal = c3_paths == c1_paths

        outer_mismatch += int(not outer_equal)
        inner_mismatch += int(not inner_equal)
        payload_mismatch += int(not payload_equal)
        fragment_mismatch += int(not fragment_equal)
        path_mismatch += int(not paths_equal)

        runtime_sources: list[str] = []
        if c3_fragment is not None:
            runtime_sources.append("APEX_FRAGMENT")
        if c3_system_paths:
            runtime_sources.append("SYSTEM_FRAGMENT")
        if not runtime_sources:
            raise AuditError(f"apex_runtime_source_missing={module}")

        module_jar_mismatches = 0
        for device in sorted(set(c3_paths) | set(c1_paths)):
            c3_host: Path | None = None
            c1_host: Path | None = None
            c3_sha = "-"
            c1_sha = "-"

            if device in c3_paths:
                c3_host = deriver.c3a_apex_jar_from_root(
                    c3_root,
                    module,
                    device,
                )
                c3_sha = sha256(c3_host)

            if device in c1_paths:
                rel = device.split("/", 3)[3]
                c1_host = c1_root / rel
                if not c1_host.is_file():
                    raise AuditError(
                        f"c1_boot_jar_missing={device}:{c1_host}"
                    )
                c1_sha = sha256(c1_host)

            equal = c3_sha == c1_sha and c3_sha != "-"
            if not equal:
                module_jar_mismatches += 1
                jar_hash_mismatch += 1

            jar_rows.append(
                [
                    module,
                    device,
                    c3_sha,
                    c1_sha,
                    "YES" if equal else "NO",
                    str(c3_host) if c3_host else "-",
                    str(c1_host) if c1_host else "-",
                ]
            )

        module_rows.append(
            [
                module,
                "+".join(runtime_sources),
                c3_outer,
                c1_outer,
                "YES" if outer_equal else "NO",
                c3_inner,
                c1_inner,
                "YES" if inner_equal else "NO",
                c3_payload,
                c1_payload,
                "YES" if payload_equal else "NO",
                c3_fs,
                c1_fs,
                c3_fragment_sha,
                c1_fragment_sha,
                "YES" if fragment_equal else "NO",
                len(c3_paths),
                len(c1_paths),
                "YES" if paths_equal else "NO",
                module_jar_mismatches,
            ]
        )

    module_tsv = out / "apex-module-parity.tsv"
    with module_tsv.open("w", newline="", encoding="utf-8") as fp:
        writer = csv.writer(fp, delimiter="\t", lineterminator="\n")
        writer.writerow(
            [
                "module",
                "runtime_sources",
                "c3a_outer_sha256",
                "c1_outer_sha256",
                "outer_match",
                "c3a_inner_sha256",
                "c1_inner_sha256",
                "inner_match",
                "c3a_payload_sha256",
                "c1_payload_sha256",
                "payload_match",
                "c3a_fs",
                "c1_fs",
                "c3a_fragment_sha256",
                "c1_fragment_sha256",
                "fragment_match",
                "c3a_boot_jar_count",
                "c1_boot_jar_count",
                "boot_jar_paths_match",
                "boot_jar_hash_mismatch_count",
            ]
        )
        writer.writerows(module_rows)

    jar_tsv = out / "apex-boot-jar-parity.tsv"
    with jar_tsv.open("w", newline="", encoding="utf-8") as fp:
        writer = csv.writer(fp, delimiter="\t", lineterminator="\n")
        writer.writerow(
            [
                "module",
                "device_path",
                "c3a_sha256",
                "c1_sha256",
                "match",
                "c3a_host_path",
                "c1_host_path",
            ]
        )
        writer.writerows(jar_rows)

    java_pass = (
        fragment_mismatch == 0
        and path_mismatch == 0
        and jar_hash_mismatch == 0
    )

    summary = out / "summary.env"
    with summary.open("w", encoding="utf-8") as fp:
        fp.write(f"TOOL_SOURCE_COMMIT={git_head}\n")
        fp.write(f"N1I_C1_APEX_PARITY_V6_EVIDENCE={evidence}\n")
        fp.write(f"N1I_C1_APEX_PARITY_PRODUCT_OUT={product_out}\n")
        fp.write(
            f"N1I_C1_APEX_PARITY_C1_SYSTEM_SHA256={c1_system_sha}\n"
        )
        fp.write(f"N1I_C1_APEX_MODULE_COUNT={len(module_rows)}\n")
        fp.write(
            f"N1I_C1_APEX_OUTER_MISMATCH_COUNT={outer_mismatch}\n"
        )
        fp.write(
            f"N1I_C1_APEX_INNER_MISMATCH_COUNT={inner_mismatch}\n"
        )
        fp.write(
            f"N1I_C1_APEX_PAYLOAD_MISMATCH_COUNT={payload_mismatch}\n"
        )
        fp.write(
            f"N1I_C1_APEX_FRAGMENT_MISMATCH_COUNT={fragment_mismatch}\n"
        )
        fp.write(
            "N1I_C1_APEX_BOOT_JAR_PATH_MISMATCH_COUNT="
            f"{path_mismatch}\n"
        )
        fp.write(
            "N1I_C1_APEX_BOOT_JAR_HASH_MISMATCH_COUNT="
            f"{jar_hash_mismatch}\n"
        )
        fp.write(
            "N1I_C1_APEX_JAVA_BOOT_RUNTIME_PARITY="
            + ("PASS" if java_pass else "FAIL")
            + "\n"
        )

    for line in summary.read_text(encoding="utf-8").splitlines():
        print(line)

    print(f"N1I_C1_APEX_RUNTIME_PARITY_EVIDENCE={out}")

    # Extracted APEX trees are reproducible scratch data. Keep compact hashes
    # and logs, then remove the bulk extraction before sealing the result.
    shutil.rmtree(work)

    sums = out / "SHA256SUMS.txt"
    with sums.open("w", encoding="utf-8") as fp:
        for path in sorted(
            [
                module_tsv,
                jar_tsv,
                summary,
                *logs.glob("*.log"),
            ],
            key=lambda item: item.name,
        ):
            fp.write(f"{sha256(path)}  {path.relative_to(out)}\n")

    final_status = subprocess.run(
        [
            "git",
            "-C",
            str(repo),
            "status",
            "--porcelain=v1",
            "--untracked-files=all",
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    if final_status:
        raise AuditError("source_worktree_changed_during_audit")

    if not java_pass:
        print(
            "N1I_C1_APEX_RUNTIME_PARITY=FAIL_JAVA_BOOT_RUNTIME_DELTA",
            file=sys.stderr,
        )
        return 3

    print("N1I_C1_APEX_RUNTIME_PARITY=PASS_JAVA_BOOT_RUNTIME_IDENTICAL")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--v6-evidence", type=Path)
    parser.add_argument("--product-out", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        return selftest()
    if args.v6_evidence is None or args.product_out is None or args.out is None:
        parser.error(
            "--v6-evidence, --product-out and --out are required"
        )

    try:
        return run(args)
    except (
        AuditError,
        OSError,
        subprocess.SubprocessError,
        zipfile.BadZipFile,
    ) as exc:
        print(
            f"N1I_C1_APEX_RUNTIME_PARITY=FAIL reason={exc}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
