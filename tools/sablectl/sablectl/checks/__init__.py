from .acceptance import manual_d4_gates, verify_d4_host_acceptance as _verify_d4_host_acceptance
from .boot import verify_boot
from .preserved_data import verify_preserved_data
from .smoke import verify_smoke_health
from .usb import verify_adb_usb_health


def verify_d4_host_acceptance(adb):
    # v0.2's original USB check treated an empty sys.usb.state as FAIL even
    # while the same authorized ADB transport was executing the suite. Retain
    # the rest of the acceptance implementation, supersede only that result,
    # and add transport + observability checks with non-contradictory semantics.
    results = [r for r in _verify_d4_host_acceptance(adb) if r.id != "usb.adb"]
    results.extend(verify_adb_usb_health(adb))
    return results


__all__ = [
    "manual_d4_gates",
    "verify_adb_usb_health",
    "verify_boot",
    "verify_d4_host_acceptance",
    "verify_preserved_data",
    "verify_smoke_health",
]
