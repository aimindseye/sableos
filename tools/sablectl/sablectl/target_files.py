from __future__ import annotations

import hashlib
import io
import zipfile
from dataclasses import dataclass
from pathlib import Path


BUILD_MANIFEST_MEMBER = "SYSTEM/etc/security/fsverity/BuildManifest.apk"
FASTBOOT_INFO_MEMBER = "META/fastboot-info.txt"
ART_PATHS = [
    "system/framework/oat/arm64/apex@com.android.appsearch@javalib@service-appsearch.jar@classes.art",
    "system/framework/oat/arm64/apex@com.android.art@javalib@service-art.jar@classes.art",
    "system/framework/oat/arm64/apex@com.android.telephonycore@javalib@service-telecom.jar@classes.art",
    "system/framework/oat/arm64/apex@com.android.tethering@javalib@service-connectivity.jar@classes.art",
    "system/framework/oat/arm64/services.art",
]


@dataclass(slots=True)
class FileExpectation:
    installed_path: str
    size: int
    sha256: str


@dataclass(slots=True)
class TargetFilesExpectation:
    path: Path
    size: int
    manifest_pb_sha256: str
    buildmanifest_apk_sha256: str
    fastboot_info_sha256: str | None
    art: list[FileExpectation]
    container_sha256: str | None = None


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _stream_member(zf: zipfile.ZipFile, member: str) -> tuple[int, str]:
    h = hashlib.sha256()
    total = 0
    with zf.open(member, "r") as f:
        while True:
            chunk = f.read(4 * 1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
            total += len(chunk)
    return total, h.hexdigest()


def hash_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(4 * 1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def installed_to_member(installed_path: str) -> str:
    head, rest = installed_path.split("/", 1)
    return f"{head.upper()}/{rest}"


def inspect_target_files(path: str | Path, *, hash_container: bool = False) -> TargetFilesExpectation:
    p = Path(path)
    if not p.is_file():
        raise FileNotFoundError(p)

    with zipfile.ZipFile(p, "r") as zf:
        bm_apk = zf.read(BUILD_MANIFEST_MEMBER)
        with zipfile.ZipFile(io.BytesIO(bm_apk), "r") as nested:
            pb = nested.read("assets/build_manifest.pb")

        fastboot_sha = None
        if FASTBOOT_INFO_MEMBER in zf.namelist():
            fastboot_sha = _sha256_bytes(zf.read(FASTBOOT_INFO_MEMBER))

        art = []
        for installed in ART_PATHS:
            member = installed_to_member(installed)
            size, digest = _stream_member(zf, member)
            art.append(FileExpectation(installed, size, digest))

    return TargetFilesExpectation(
        path=p,
        size=p.stat().st_size,
        manifest_pb_sha256=_sha256_bytes(pb),
        buildmanifest_apk_sha256=_sha256_bytes(bm_apk),
        fastboot_info_sha256=fastboot_sha,
        art=art,
        container_sha256=hash_file(p) if hash_container else None,
    )
