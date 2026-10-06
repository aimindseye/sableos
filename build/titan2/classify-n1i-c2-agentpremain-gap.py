#!/usr/bin/env python3
"""Classify the only C2-permitted unresolved IMS member surface.

Read-only and host-only. This does not weaken the fatal C1 member resolver.
It accepts only the exact dormant kotlinx.coroutines AgentPremain references
already admitted by the C2 MVP policy, after proving:
- mediatek-common and mediatek-ims-base remain fully resolved;
- the IMS APK has exactly eight unresolved rows;
- every unresolved row is AgentPremain -> java.lang.instrument/sun.misc;
- no TelephonyMetrics compatibility failure remains;
- no non-AgentPremain DEX code directly references AgentPremain.
"""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
C1_GAP = ROOT / "build/titan2/audit-n1i-c1-member-gap-classification.py"

EXPECTED_AGENT_FAILURES = 8
EXPECTED_AGENT_NAMESPACES = (
    "Ljava/lang/instrument/",
    "Lsun/misc/",
)
AGENT_PREFIX = "Lkotlinx/coroutines/debug/internal/AgentPremain"


class ClassificationError(Exception):
    pass


def load_c1_gap():
    spec = importlib.util.spec_from_file_location("n1i_c1_gap_for_c2", C1_GAP)
    if spec is None or spec.loader is None:
        raise ClassificationError(f"cannot_load_c1_gap={C1_GAP}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def parse_scalar(text: str, key: str) -> str:
    prefix = key + "="
    values = [
        raw[len(prefix):]
        for raw in text.splitlines()
        if raw.startswith(prefix)
    ]
    if len(values) != 1:
        raise ClassificationError(
            f"scalar_count={key}:expected:1:actual:{len(values)}"
        )
    return values[0]


def classify(
    evidence: Path,
    product_out: Path,
    expected_system_sha: str,
) -> int:
    linkage = evidence / "runtime-linkage.txt"
    parity_summary = evidence / "apex-runtime-parity/summary.env"
    ims_apk = (
        product_out
        / "system/system_ext/priv-app/ImsService/ImsService.apk"
    )

    for path in (linkage, parity_summary, ims_apk):
        if not path.is_file():
            raise ClassificationError(f"required_input_missing={path}")

    parity = parity_summary.read_text(encoding="utf-8")
    if parse_scalar(
        parity,
        "N1I_C1_APEX_PARITY_C1_SYSTEM_SHA256",
    ) != expected_system_sha:
        raise ClassificationError("apex_parity_system_sha_binding_mismatch")
    bound_product = parse_scalar(
        parity,
        "N1I_C1_APEX_PARITY_PRODUCT_OUT",
    )
    if Path(bound_product).resolve() != product_out:
        raise ClassificationError(
            f"apex_parity_product_out_binding_mismatch={bound_product}"
        )
    if parse_scalar(
        parity,
        "N1I_C1_APEX_JAVA_BOOT_RUNTIME_PARITY",
    ) != "PASS":
        raise ClassificationError("apex_java_boot_runtime_parity_not_pass")

    text = linkage.read_text(encoding="utf-8")

    expected_scalars = {
        "N1I_C1_LINKAGE_RUNTIME_CORE_SANITY": "PASS",
        "N1I_C1_LINKAGE_BASELINE_BOOT_DUPLICATE_CLASS_COUNT": "0",
        "N1I_C1_LINKAGE_IMPORTED_BOOT_DUPLICATE_CLASS_COUNT": "0",
        "N1I_C1_LINKAGE_POST_IMPORT_BOOT_DUPLICATE_CLASS_COUNT": "0",
        "N1I_C1_LINKAGE_COMMON_UNRESOLVED": "0",
        "N1I_C1_LINKAGE_IMS_BASE_UNRESOLVED": "0",
        "N1I_C1_LINKAGE_IMS_APK_CLASS_MISSING":
            str(EXPECTED_AGENT_FAILURES),
        "N1I_C1_LINKAGE_IMS_APK_METHOD_MISSING": "0",
        "N1I_C1_LINKAGE_IMS_APK_FIELD_MISSING": "0",
        "N1I_C1_LINKAGE_IMS_APK_DESCRIPTOR_MISMATCH": "0",
        "N1I_C1_LINKAGE_IMS_APK_STATIC_INSTANCE_MISMATCH": "0",
        "N1I_C1_LINKAGE_IMS_APK_ACCESS_VIOLATION": "0",
        "N1I_C1_LINKAGE_IMS_APK_ICCE_KIND": "0",
        "N1I_C1_LINKAGE_IMS_APK_UNRESOLVED": str(EXPECTED_AGENT_FAILURES),
        "N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT":
            f"FAIL_UNRESOLVED_MEMBERS count={EXPECTED_AGENT_FAILURES}",
    }
    for key, expected in expected_scalars.items():
        actual = parse_scalar(text, key)
        if actual != expected:
            raise ClassificationError(
                f"unexpected_scalar={key}:expected:{expected}:actual:{actual}"
            )

    gap = load_c1_gap()
    agent_failures, telephony_failures, other_failures = (
        gap.parse_linkage_failures(linkage)
    )

    if telephony_failures:
        raise ClassificationError(
            f"telephony_failure_count={len(telephony_failures)}"
        )
    if other_failures:
        raise ClassificationError(
            f"other_failure_count={len(other_failures)}"
        )
    if len(agent_failures) != EXPECTED_AGENT_FAILURES:
        raise ClassificationError(
            "agent_failure_count="
            f"expected:{EXPECTED_AGENT_FAILURES}:actual:{len(agent_failures)}"
        )

    for row in agent_failures:
        if AGENT_PREFIX not in row:
            raise ClassificationError("agent_failure_outside_agentpremain")
        if not any(namespace in row for namespace in EXPECTED_AGENT_NAMESPACES):
            raise ClassificationError(
                f"agent_failure_unexpected_namespace={row}"
            )

    S = gap.load_static()
    app, app_source = gap.load_container_with_vdex(S, ims_apk)
    _calls, inbound, agent_classes = gap.scan_app(S, app)

    if not agent_classes:
        raise ClassificationError("agentpremain_classes_absent")
    if inbound:
        raise ClassificationError(
            f"agentpremain_external_inbound_count={len(inbound)}"
        )

    print("===== N1I-C2 AGENTPREMAIN FULL CLASSIFICATION =====")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("NETWORK_FETCH_AUTHORIZED=NO")
    print("BUILD_AUTHORIZED=NO")
    print("FLASH_AUTHORIZED=NO")
    print("SOURCE_MUTATION_AUTHORIZED=NO")
    print(f"PRODUCT_OUT={product_out}")
    print(f"LINKAGE_EVIDENCE={evidence}")
    print(f"N1I_C2_AGENTPREMAIN_APP_DEX_SOURCE={app_source}")
    print(
        "N1I_C2_AGENTPREMAIN_FAILURE_COUNT="
        f"{len(agent_failures)}"
    )
    print(
        "N1I_C2_AGENTPREMAIN_EXTERNAL_INBOUND_REF_COUNT="
        f"{len(inbound)}"
    )
    print(
        "N1I_C2_AGENTPREMAIN_TELEPHONY_FAILURE_COUNT="
        f"{len(telephony_failures)}"
    )
    print(
        "N1I_C2_AGENTPREMAIN_OTHER_FAILURE_COUNT="
        f"{len(other_failures)}"
    )
    print(
        "N1I_C2_AGENTPREMAIN_CLASS_COUNT="
        f"{len(agent_classes)}"
    )
    print(
        "N1I_C2_AGENTPREMAIN_BROAD_RUNTIME_FAILURE_SUPPRESSION=NO"
    )
    print(
        "N1I_C2_AGENTPREMAIN_CLASSIFICATION="
        "PASS_EXACT_DORMANT_NON_ANDROID_DEBUG_AGENT"
    )
    print(
        "N1I_C2_RUNTIME_MEMBER_LINKAGE="
        "PASS_FULL_CLASSIFICATION_AGENTPREMAIN_8"
    )
    return 0


def selftest() -> int:
    sample = (
        "N1I_C1_LINKAGE_COMMON_UNRESOLVED=0\n"
        "N1I_C1_LINKAGE_IMS_BASE_UNRESOLVED=0\n"
        "N1I_C1_LINKAGE_IMS_APK_UNRESOLVED=8\n"
    )
    assert parse_scalar(
        sample,
        "N1I_C1_LINKAGE_IMS_APK_UNRESOLVED",
    ) == "8"
    try:
        parse_scalar(sample, "MISSING")
    except ClassificationError:
        pass
    else:
        raise AssertionError("missing scalar accepted")
    print("N1I_C2_AGENTPREMAIN_CLASSIFICATION_SELFTEST=PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--product-out", type=Path)
    parser.add_argument("--expected-system-sha")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        return selftest()

    if (
        args.evidence is None
        or args.product_out is None
        or args.expected_system_sha is None
    ):
        parser.error(
            "--evidence, --product-out and --expected-system-sha are required"
        )
    if (
        len(args.expected_system_sha) != 64
        or any(
            ch not in "0123456789abcdef"
            for ch in args.expected_system_sha
        )
    ):
        parser.error(
            "--expected-system-sha must be 64 lowercase hex characters"
        )

    try:
        return classify(
            args.evidence.resolve(),
            args.product_out.resolve(),
            args.expected_system_sha,
        )
    except (
        ClassificationError,
        OSError,
        ValueError,
    ) as exc:
        print(
            "N1I_C2_AGENTPREMAIN_CLASSIFICATION="
            f"FAIL reason={exc}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
