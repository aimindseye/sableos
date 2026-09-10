from sablectl.checks.preserved_data import verify_preserved_data
from sablectl.types import Status


class FakeAdb:
    def getprop(self, name):
        assert name == "sys.user.0.ce_available"
        return "true"

    def third_party_packages(self):
        return ["a.pkg", "b.pkg"]

    def users(self):
        return ["UserInfo{0:Owner:...}"]


def test_preserved_data_exact_package_set():
    baseline = {
        "device": {
            "third_party_packages": ["a.pkg", "b.pkg"],
            "users": ["UserInfo{0:Owner:...}"],
        }
    }
    results = verify_preserved_data(FakeAdb(), baseline)
    assert all(r.status is Status.PASS for r in results)
