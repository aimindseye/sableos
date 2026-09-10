import hashlib
import io
import zipfile

from sablectl.target_files import ART_PATHS, inspect_target_files, installed_to_member


def make_target_files(path):
    pb = b"manifest-pb"
    apk_buf = io.BytesIO()
    with zipfile.ZipFile(apk_buf, "w", zipfile.ZIP_STORED) as apk:
        apk.writestr("assets/build_manifest.pb", pb)
    apk_bytes = apk_buf.getvalue()

    with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as zf:
        zf.writestr("SYSTEM/etc/security/fsverity/BuildManifest.apk", apk_bytes)
        zf.writestr("META/fastboot-info.txt", b"version 1\n")
        for i, installed in enumerate(ART_PATHS):
            zf.writestr(installed_to_member(installed), f"art-{i}".encode())
    return pb, apk_bytes


def test_inspect_target_files(tmp_path):
    tf = tmp_path / "panther-target_files.zip"
    pb, apk = make_target_files(tf)
    result = inspect_target_files(tf, hash_container=True)

    assert result.manifest_pb_sha256 == hashlib.sha256(pb).hexdigest()
    assert result.buildmanifest_apk_sha256 == hashlib.sha256(apk).hexdigest()
    assert len(result.art) == 5
    assert result.container_sha256 is not None
