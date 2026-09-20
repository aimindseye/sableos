#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import shlex
import shutil
import sys
import tempfile
import zipfile

CHUNK = 4 * 1024 * 1024
FASTBOOT_INFO_MEMBER = "META/fastboot-info.txt"


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        while True:
            block = fp.read(CHUNK)
            if not block:
                break
            h.update(block)
    return h.hexdigest()


def sha256_stream(src) -> tuple[int, str]:
    h = hashlib.sha256()
    total = 0
    while True:
        block = src.read(CHUNK)
        if not block:
            break
        h.update(block)
        total += len(block)
    return total, h.hexdigest()


def parse_fastboot_info(text: str) -> dict:
    unsafe: list[dict[str, object]] = []
    required: dict[str, set[str]] = {}
    commands: list[dict[str, object]] = []
    conditional_wipes = 0
    noncomment = 0

    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        noncomment += 1
        try:
            tok = shlex.split(line)
        except ValueError as exc:
            unsafe.append({"line": lineno, "text": line, "reason": f"parse_error:{exc}"})
            continue
        if not tok:
            continue

        cmd = tok[0]
        commands.append({"line": lineno, "tokens": tok})

        if cmd == "version":
            if len(tok) != 2 or not tok[1].isdigit():
                unsafe.append({"line": lineno, "text": line, "reason": "invalid_version"})
            continue

        if cmd == "if-wipe":
            if len(tok) != 3 or tok[1] != "erase" or tok[2] not in {"userdata", "metadata"}:
                unsafe.append({"line": lineno, "text": line, "reason": "unexpected_if_wipe_form"})
            else:
                conditional_wipes += 1
            continue

        if cmd == "update-super":
            if len(tok) != 1:
                unsafe.append({"line": lineno, "text": line, "reason": "invalid_update_super"})
            else:
                required.setdefault("super_empty.img", set()).add("__update_super__")
            continue

        if cmd == "reboot":
            if len(tok) != 2 or tok[1] not in {"bootloader", "fastboot"}:
                unsafe.append({"line": lineno, "text": line, "reason": "unexpected_reboot_target"})
            continue

        if cmd == "erase":
            unsafe.append({"line": lineno, "text": line, "reason": "unconditional_erase_forbidden"})
            continue

        if cmd != "flash":
            unsafe.append({"line": lineno, "text": line, "reason": f"unsupported_command:{cmd}"})
            continue

        args = tok[1:]
        if "--slot-other" in args:
            unsafe.append({"line": lineno, "text": line, "reason": "inactive_slot_directive_forbidden"})
            continue

        positional: list[str] = []
        for arg in args:
            if arg == "--apply-vbmeta":
                continue
            if arg.startswith("--"):
                unsafe.append({"line": lineno, "text": line, "reason": f"unsupported_flash_option:{arg}"})
                continue
            positional.append(arg)

        if len(positional) not in {1, 2}:
            unsafe.append({"line": lineno, "text": line, "reason": "invalid_flash_arity"})
            continue

        partition = positional[0]
        filename = positional[1] if len(positional) == 2 else f"{partition}.img"
        if partition.lower() in {"userdata", "metadata"}:
            unsafe.append({"line": lineno, "text": line, "reason": f"forbidden_partition:{partition}"})
            continue
        required.setdefault(filename, set()).add(partition)

    return {
        "noncomment_line_count": noncomment,
        "conditional_wipe_count": conditional_wipes,
        "unsafe": unsafe,
        "required": {k: sorted(v) for k, v in sorted(required.items())},
        "commands": commands,
    }


def inspect_and_optionally_stage(args: argparse.Namespace) -> int:
    target_files = pathlib.Path(args.target_files).resolve()
    evidence = pathlib.Path(args.evidence_dir).resolve()
    evidence.mkdir(parents=True, exist_ok=True)

    if not target_files.is_file():
        raise FileNotFoundError(target_files)

    actual_sha = sha256_file(target_files)
    print(f"TARGET_FILES={target_files}")
    print(f"EXPECTED_TARGET_FILES_SHA256={args.expected_sha256}")
    print(f"ACTUAL_TARGET_FILES_SHA256={actual_sha}")
    if actual_sha != args.expected_sha256:
        print("SABLE_TARGET_FILES_IDENTITY=FAIL")
        return 32
    print("SABLE_TARGET_FILES_IDENTITY=PASS")

    with zipfile.ZipFile(target_files, "r") as zf:
        names = set(zf.namelist())
        if FASTBOOT_INFO_MEMBER not in names:
            print("SABLE_FASTBOOT_INFO_PRESENT=FAIL")
            return 33

        fastboot_bytes = zf.read(FASTBOOT_INFO_MEMBER)
        fastboot_text = fastboot_bytes.decode("utf-8", "strict")
        plan = parse_fastboot_info(fastboot_text)
        (evidence / "fastboot-info.txt").write_bytes(fastboot_bytes)

        print(f"FASTBOOT_INFO_NONCOMMENT_LINE_COUNT={plan['noncomment_line_count']}")
        print(f"FASTBOOT_INFO_CONDITIONAL_WIPE_COUNT={plan['conditional_wipe_count']}")
        print(f"FASTBOOT_INFO_UNSAFE_DIRECTIVE_COUNT={len(plan['unsafe'])}")
        for item in plan["unsafe"]:
            print(f"UNSAFE line={item['line']} reason={item['reason']} text={item['text']!r}")
        if plan["unsafe"]:
            print("SABLE_FASTBOOT_PLAN_POLICY=FAIL")
            return 34

        missing: list[str] = []
        image_rows: list[dict[str, object]] = []
        total = 0
        for filename, partitions in plan["required"].items():
            member = f"IMAGES/{filename}"
            if member not in names:
                missing.append(member)
                continue
            info = zf.getinfo(member)
            total += info.file_size
            image_rows.append(
                {
                    "filename": filename,
                    "member": member,
                    "size": info.file_size,
                    "partitions": partitions,
                }
            )

        print(f"FLASH_REQUIRED_IMAGE_COUNT={len(plan['required'])}")
        print(f"FLASH_REQUIRED_IMAGE_BYTES={total}")
        print(f"FLASH_MISSING_IMAGE_COUNT={len(missing)}")
        for member in missing:
            print(f"IMAGE_MISSING={member}")
        if missing:
            print("SABLE_TARGET_FILES_FLASH_PAYLOAD_COMPLETE=FAIL")
            return 35

        plan_doc = {
            "target_files": str(target_files),
            "target_files_sha256": actual_sha,
            "fastboot_info_sha256": hashlib.sha256(fastboot_bytes).hexdigest(),
            "noncomment_line_count": plan["noncomment_line_count"],
            "conditional_wipe_count": plan["conditional_wipe_count"],
            "images": image_rows,
            "required_image_bytes": total,
        }
        (evidence / "flash-plan.json").write_text(
            json.dumps(plan_doc, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

        if args.stage_dir:
            stage = pathlib.Path(args.stage_dir).resolve()
            if stage.exists() and any(stage.iterdir()):
                print(f"SABLE_STAGE_DIR_EMPTY=FAIL path={stage}")
                return 36
            stage.mkdir(parents=True, exist_ok=True)

            free = shutil.disk_usage(stage).free
            reserve = max(512 * 1024 * 1024, total // 10)
            print(f"STAGE_REQUIRED_BYTES={total}")
            print(f"STAGE_FREE_BYTES={free}")
            print(f"STAGE_RESERVE_BYTES={reserve}")
            if free < total + reserve:
                print("SABLE_STAGE_SPACE=FAIL")
                return 37
            print("SABLE_STAGE_SPACE=PASS")

            staged_rows: list[tuple[str, int, str, str]] = []
            for index, row in enumerate(image_rows, 1):
                filename = str(row["filename"])
                member = str(row["member"])
                dest = stage / filename
                print(f"STAGE_IMAGE index={index}/{len(image_rows)} filename={filename}")
                h = hashlib.sha256()
                total_written = 0
                with zf.open(member, "r") as src, dest.open("xb") as out:
                    while True:
                        block = src.read(CHUNK)
                        if not block:
                            break
                        out.write(block)
                        h.update(block)
                        total_written += len(block)
                if total_written != int(row["size"]):
                    print(f"SABLE_STAGE_IMAGE_SIZE=FAIL filename={filename}")
                    return 38
                staged_rows.append((filename, total_written, h.hexdigest(), member))

            (stage / "fastboot-info.txt").write_bytes(fastboot_bytes)
            if args.android_info:
                android_info = pathlib.Path(args.android_info).resolve()
                if not android_info.is_file():
                    print(f"SABLE_ANDROID_INFO_PRESENT=FAIL path={android_info}")
                    return 39
                shutil.copyfile(android_info, stage / "android-info.txt")
                print(f"ANDROID_INFO_SHA256={sha256_file(android_info)}")

            with (evidence / "staged-images.tsv").open("w", encoding="utf-8") as fp:
                fp.write("filename\tsize\tsha256\tsource_member\n")
                for filename, size, digest, member in staged_rows:
                    fp.write(f"{filename}\t{size}\t{digest}\t{member}\n")
            with (stage / "SHA256SUMS.txt").open("w", encoding="utf-8") as fp:
                for filename, _size, digest, _member in staged_rows:
                    fp.write(f"{digest}  {filename}\n")
                fp.write(f"{hashlib.sha256(fastboot_bytes).hexdigest()}  fastboot-info.txt\n")
                if args.android_info:
                    fp.write(f"{sha256_file(stage / 'android-info.txt')}  android-info.txt\n")
            print("SABLE_TARGET_FILES_STAGE=PASS")

    print("SABLE_FASTBOOT_PLAN_POLICY=PASS")
    print("SABLE_TARGET_FILES_FLASH_PAYLOAD_COMPLETE=PASS")
    return 0


def self_test() -> int:
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        safe = root / "safe.zip"
        with zipfile.ZipFile(safe, "w", zipfile.ZIP_STORED) as zf:
            zf.writestr(
                FASTBOOT_INFO_MEMBER,
                "version 1\nflash boot\nreboot fastboot\nupdate-super\nflash system\nif-wipe erase userdata\n",
            )
            zf.writestr("IMAGES/boot.img", b"boot")
            zf.writestr("IMAGES/super_empty.img", b"super")
            zf.writestr("IMAGES/system.img", b"system")
        safe_plan = parse_fastboot_info(zipfile.ZipFile(safe).read(FASTBOOT_INFO_MEMBER).decode())
        assert not safe_plan["unsafe"]
        assert safe_plan["conditional_wipe_count"] == 1
        assert set(safe_plan["required"]) == {"boot.img", "super_empty.img", "system.img"}

        bad = parse_fastboot_info("version 1\nerase userdata\nflash --slot-other boot\n")
        reasons = {str(x["reason"]) for x in bad["unsafe"]}
        assert "unconditional_erase_forbidden" in reasons
        assert "inactive_slot_directive_forbidden" in reasons
    print("SABLE_TARGET_FILES_PLAN_SELF_TEST=PASS")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser()
    p.add_argument("--self-test", action="store_true")
    p.add_argument("--target-files")
    p.add_argument("--expected-sha256")
    p.add_argument("--evidence-dir")
    p.add_argument("--stage-dir")
    p.add_argument("--android-info")
    return p


def main() -> int:
    args = build_parser().parse_args()
    if args.self_test:
        return self_test()
    missing = [
        name
        for name in ("target_files", "expected_sha256", "evidence_dir")
        if not getattr(args, name)
    ]
    if missing:
        print("missing required arguments: " + ", ".join(missing), file=sys.stderr)
        return 64
    return inspect_and_optionally_stage(args)


if __name__ == "__main__":
    raise SystemExit(main())
