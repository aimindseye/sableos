from pathlib import Path

from sablectl.checks.boot import verify_boot
from sablectl.target_files import ART_PATHS, FileExpectation, TargetFilesExpectation
from sablectl.types import Status


class FakeAdb:
    def __init__(self, sha_map):
        self.sha_map = sha_map
        self.sha_calls = []

    def getprop(self, name):
        return {
            "ro.product.device": "panther",
            "sys.boot_completed": "1",
            "ro.boot.slot_suffix": "_b",
            "ro.crypto.state": "encrypted",
        }[name]

    def sha256(self, path):
        self.sha_calls.append(path)
        return self.sha_map[path]


def test_verify_boot_checks_all_five_art_images():
    art = [FileExpectation(p, 1, f"{i:064x}") for i, p in enumerate(ART_PATHS, 1)]
    expected = TargetFilesExpectation(
        path=Path("x.zip"), size=1, manifest_pb_sha256="a" * 64,
        buildmanifest_apk_sha256="b" * 64, fastboot_info_sha256=None, art=art,
    )
    sha_map = {"/system/etc/security/fsverity/BuildManifest.apk": "b" * 64}
    for item in art:
        sha_map["/" + item.installed_path] = item.sha256
    adb = FakeAdb(sha_map)

    results = verify_boot(adb, expected, expected_slot="b")
    aggregate = next(r for r in results if r.id == "artifact.art.count")

    assert aggregate.status is Status.PASS
    assert aggregate.actual == 5
    assert len([p for p in adb.sha_calls if p.endswith(".art")]) == 5
