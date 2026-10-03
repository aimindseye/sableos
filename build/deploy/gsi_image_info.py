#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import pathlib
import struct
import tempfile

SPARSE_MAGIC = 0xED26FF3A
SPARSE_HEADER = struct.Struct("<IHHHHIIII")


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inspect_image(path: pathlib.Path) -> dict[str, object]:
    file_bytes = path.stat().st_size
    logical_bytes = file_bytes
    image_format = "raw"

    with path.open("rb") as fp:
        header = fp.read(SPARSE_HEADER.size)

    if len(header) == SPARSE_HEADER.size:
        (
            magic,
            major,
            minor,
            file_hdr_sz,
            chunk_hdr_sz,
            block_size,
            total_blocks,
            total_chunks,
            checksum,
        ) = SPARSE_HEADER.unpack(header)

        if magic == SPARSE_MAGIC:
            if major != 1:
                raise ValueError(f"unsupported sparse major version: {major}")
            if file_hdr_sz < SPARSE_HEADER.size:
                raise ValueError(f"invalid sparse file header size: {file_hdr_sz}")
            if chunk_hdr_sz < 12:
                raise ValueError(f"invalid sparse chunk header size: {chunk_hdr_sz}")
            if block_size <= 0 or total_blocks <= 0 or total_chunks <= 0:
                raise ValueError("invalid sparse image geometry")
            logical_bytes = block_size * total_blocks
            image_format = "android-sparse"

    return {
        "format": image_format,
        "file_bytes": file_bytes,
        "logical_bytes": logical_bytes,
    }


def self_test() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)

        raw = root / "raw.img"
        raw.write_bytes(b"sable-gsi")
        info = inspect_image(raw)
        assert info["format"] == "raw"
        assert info["file_bytes"] == 9
        assert info["logical_bytes"] == 9

        sparse = root / "sparse.img"
        sparse.write_bytes(
            SPARSE_HEADER.pack(
                SPARSE_MAGIC,
                1,
                0,
                SPARSE_HEADER.size,
                12,
                4096,
                123,
                1,
                0,
            )
            + b"payload"
        )
        info = inspect_image(sparse)
        assert info["format"] == "android-sparse"
        assert info["logical_bytes"] == 4096 * 123

    print("SABLE_GSI_IMAGE_INFO_SELF_TEST=PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", type=pathlib.Path)
    parser.add_argument("--expected-sha256")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    if args.image is None:
        parser.error("--image is required unless --self-test is used")
    if not args.image.is_file():
        print(f"SABLE_GSI_IMAGE_INFO=FAIL_IMAGE_MISSING path={args.image}")
        return 2

    try:
        info = inspect_image(args.image)
    except (OSError, ValueError, struct.error) as exc:
        print(f"SABLE_GSI_IMAGE_INFO=FAIL reason={exc}")
        return 3

    actual_sha = None
    if args.expected_sha256:
        actual_sha = sha256_file(args.image)
        if actual_sha != args.expected_sha256:
            print(f"GSI_IMAGE_SHA256_EXPECTED={args.expected_sha256}")
            print(f"GSI_IMAGE_SHA256_ACTUAL={actual_sha}")
            print("SABLE_GSI_IMAGE_INFO=FAIL_SHA256")
            return 4

    print(f"GSI_IMAGE_PATH={args.image.resolve()}")
    if actual_sha is not None:
        print(f"GSI_IMAGE_SHA256={actual_sha}")
    print(f"GSI_IMAGE_FILE_BYTES={info['file_bytes']}")
    print(f"GSI_IMAGE_FORMAT={info['format']}")
    print(f"GSI_IMAGE_LOGICAL_BYTES={info['logical_bytes']}")
    print("SABLE_GSI_IMAGE_INFO=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
