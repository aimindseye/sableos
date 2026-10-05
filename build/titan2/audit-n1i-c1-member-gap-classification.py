#!/usr/bin/env python3
"""Classify the first N1I-C1 exact member-linkage failures.

Host-only and read-only. This diagnostic does not change the fatal member
resolver. It answers two questions from sealed V6 evidence:

1. Is the TelephonyMetrics.writeRilAnswer(II)V reference a stock/C3A/C1 ABI
   delta, and is there an app-local shadow that parent-first ART cannot use?
2. Are the java.lang.instrument / sun.misc failures confined to the
   kotlinx.coroutines debug AgentPremain surface, with no direct inbound DEX
   reference from non-AgentPremain app code?

The second result is deliberately a reachability *candidate*, not an
authorization to suppress verifier failures.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
from pathlib import Path
import re
import sys
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
STATIC_PATH = ROOT / "build/titan2/n1i_static.py"

EXPECTED_C1_SHA = (
    "137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
)
TELEPHONY = "Lcom/android/internal/telephony/metrics/TelephonyMetrics;"
RIL_ADAPTER = "Lcom/mediatek/ims/ril/ImsRILAdapter;"
AGENT_PREFIX = "Lkotlinx/coroutines/debug/internal/AgentPremain"
EXPECTED_AGENT_NAMESPACES = (
    "Ljava/lang/instrument/",
    "Lsun/misc/",
)


class AuditError(Exception):
    pass


def load_static():
    spec = importlib.util.spec_from_file_location("n1i_static_gap", STATIC_PATH)
    if spec is None or spec.loader is None:
        raise AuditError(f"cannot_load_static={STATIC_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def system_root(tree: Path) -> Path:
    nested = tree / "system"
    if (nested / "build.prop").is_file():
        return nested
    return tree


def load_container_with_vdex(S, path: Path):
    container = S.load_container(path)
    if container.dexes:
        return container, "ARCHIVE_DEX"

    stem = path.stem
    for arch in ("arm64", "arm"):
        vdex = path.parent / "oat" / arch / f"{stem}.vdex"
        if not vdex.is_file():
            continue
        data = vdex.read_bytes()
        dexes = []
        for index, match in enumerate(
            re.finditer(rb"dex\n0[0-9]{2}\x00", data),
            start=1,
        ):
            start = match.start()
            if start + 0x24 > len(data):
                continue
            size = int.from_bytes(data[start + 0x20:start + 0x24], "little")
            end = start + size
            if size < 0x70 or end > len(data):
                continue
            name = f"{vdex.name}!embedded{index}.dex"
            dexes.append((name, S.DexFile(data[start:end], name)))
        if dexes:
            return S.DexContainer(str(path), dexes, []), f"VDEX_{arch}"
        if b"cdex" in data:
            return container, f"CDEX_UNPARSED_{arch}"
        return container, f"VDEX_NO_STANDARD_DEX_{arch}"

    return container, "NO_DEX_OR_VDEX"


def find_class(container, desc: str):
    found = []
    for entry, dex in container.dexes:
        for cd in dex.classes:
            if cd.descriptor == desc:
                found.append((entry, dex, cd))
    return found


def method_protos(container, desc: str, name: str) -> list[str]:
    out = []
    for _entry, _dex, cd in find_class(container, desc):
        out.extend(method.ref.proto for method in cd.methods if method.ref.name == name)
    return sorted(set(out))


def ref_classes(S, ref) -> Iterable[str]:
    if isinstance(ref, str):
        if ref.startswith("L") or ref.startswith("[L"):
            yield ref.lstrip("[")
        return
    if isinstance(ref, S.MethodRef):
        yield ref.cls
        return
    if isinstance(ref, S.FieldRef):
        yield ref.cls
        yield ref.type.lstrip("[")
        return
    if isinstance(ref, S.MethodHandle):
        yield from ref_classes(S, ref.target)
        return
    if isinstance(ref, S.CallSite):
        yield from ref_classes(S, ref.bootstrap)
        for extra in ref.extra:
            yield from ref_classes(S, extra)


def scan_app(S, app):
    telephony_calls = []
    agent_inbound = []
    agent_classes = []

    for entry, dex in app.dexes:
        for cd in dex.classes:
            is_agent = cd.descriptor.startswith(AGENT_PREFIX)
            if is_agent:
                agent_classes.append(cd.descriptor)

            if not is_agent:
                for kind, target in (
                    ("superclass", cd.superclass),
                    *[("interface", item) for item in cd.interfaces],
                ):
                    if target and target.startswith(AGENT_PREFIX):
                        agent_inbound.append(
                            (cd.descriptor, "<class>", kind, target)
                        )

            for method in cd.methods:
                if method.code is None:
                    continue
                for ins in S.instructions(dex, method):
                    ref = ins.ref
                    if (
                        isinstance(ref, S.MethodRef)
                        and ref.cls == TELEPHONY
                        and ref.name == "writeRilAnswer"
                    ):
                        telephony_calls.append(
                            (
                                cd.descriptor,
                                method.ref.name + method.ref.proto,
                                ins.offset,
                                ref.proto,
                            )
                        )

                    if is_agent:
                        continue
                    for target in ref_classes(S, ref):
                        if target.startswith(AGENT_PREFIX):
                            agent_inbound.append(
                                (
                                    cd.descriptor,
                                    method.ref.name + method.ref.proto,
                                    ins.name,
                                    target,
                                )
                            )

    return telephony_calls, sorted(set(agent_inbound)), sorted(set(agent_classes))


def parse_linkage_failures(path: Path):
    if not path.is_file():
        raise AuditError(f"runtime_linkage_missing={path}")
    agent = []
    telephony = []
    other = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        is_member_failure = "N1I_C1_LINKAGE_IMS_APK_FAILURE[" in raw
        is_class_failure = "N1I_C1_LINKAGE_IMS_APK_CLASS_FAILURE[" in raw
        if not (is_member_failure or is_class_failure):
            continue
        if "AgentPremain" in raw:
            agent.append(raw)
        elif (
            is_member_failure
            and "TelephonyMetrics;" in raw
            and "|writeRilAnswer|(II)V|DESCRIPTOR_MISMATCH|" in raw
        ):
            telephony.append(raw)
        else:
            other.append(raw)
    return agent, telephony, other


def fmt(values: list[str]) -> str:
    return ",".join(values) if values else "NONE"


def selftest() -> int:
    assert system_root(Path("/tmp/example")) == Path("/tmp/example")
    assert list(ref_classes(type("S", (), {})(), "Ljava/lang/String;")) == [
        "Ljava/lang/String;"
    ]
    print("N1I_C1_MEMBER_GAP_CLASSIFICATION_SELFTEST=PASS")
    return 0


def run(args: argparse.Namespace) -> int:
    S = load_static()

    evidence = args.v6_evidence.resolve()
    product_out = args.product_out.resolve()
    linkage = evidence / "runtime-linkage.txt"
    replay = evidence / "n1i-a-replay"

    c1_system = product_out / "system.img"
    if not c1_system.is_file() or sha256(c1_system) != EXPECTED_C1_SHA:
        raise AuditError("c1_system_authority_mismatch")

    app_path = (
        product_out
        / "system/system_ext/priv-app/ImsService/ImsService.apk"
    )
    c1_telephony = product_out / "system/framework/telephony-common.jar"

    c3a_sys = system_root(replay / "work/c3a/system_img")
    stock_sys = system_root(replay / "work/stock/system_img")
    c3a_telephony = c3a_sys / "framework/telephony-common.jar"
    stock_telephony = stock_sys / "framework/telephony-common.jar"

    for required in (app_path, c1_telephony, c3a_telephony):
        if not required.is_file():
            raise AuditError(f"required_input_missing={required}")

    app, app_source = load_container_with_vdex(S, app_path)
    c1, c1_source = load_container_with_vdex(S, c1_telephony)
    c3a, c3a_source = load_container_with_vdex(S, c3a_telephony)

    stock = None
    stock_source = "MISSING"
    if stock_telephony.is_file():
        stock, stock_source = load_container_with_vdex(S, stock_telephony)

    c1_protos = method_protos(c1, TELEPHONY, "writeRilAnswer")
    c3a_protos = method_protos(c3a, TELEPHONY, "writeRilAnswer")
    stock_protos = (
        method_protos(stock, TELEPHONY, "writeRilAnswer")
        if stock is not None and stock.dexes
        else []
    )
    app_local_protos = method_protos(app, TELEPHONY, "writeRilAnswer")

    calls, inbound, agent_classes = scan_app(S, app)
    agent_failures, telephony_failures, other_failures = parse_linkage_failures(
        linkage
    )

    print("===== N1I-C1 MEMBER GAP CLASSIFICATION =====")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("NETWORK_FETCH_AUTHORIZED=NO")
    print("BUILD_AUTHORIZED=NO")
    print("FLASH_AUTHORIZED=NO")
    print("SOURCE_MUTATION_AUTHORIZED=NO")
    print(f"V6_EVIDENCE={evidence}")
    print(f"PRODUCT_OUT={product_out}")
    print(f"N1I_C1_GAP_APP_DEX_SOURCE={app_source}")
    print(f"N1I_C1_GAP_C1_TELEPHONY_DEX_SOURCE={c1_source}")
    print(f"N1I_C1_GAP_C3A_TELEPHONY_DEX_SOURCE={c3a_source}")
    print(f"N1I_C1_GAP_STOCK_TELEPHONY_DEX_SOURCE={stock_source}")

    print(
        "N1I_C1_GAP_C1_WRITE_RIL_ANSWER_PROTOS="
        + fmt(c1_protos)
    )
    print(
        "N1I_C1_GAP_C3A_WRITE_RIL_ANSWER_PROTOS="
        + fmt(c3a_protos)
    )
    print(
        "N1I_C1_GAP_STOCK_WRITE_RIL_ANSWER_PROTOS="
        + fmt(stock_protos)
    )
    print(
        "N1I_C1_GAP_APP_LOCAL_WRITE_RIL_ANSWER_PROTOS="
        + fmt(app_local_protos)
    )

    print(f"N1I_C1_GAP_IMS_WRITE_RIL_ANSWER_CALL_COUNT={len(calls)}")
    for index, row in enumerate(calls):
        caller, method, offset, proto = row
        print(
            f"N1I_C1_GAP_IMS_WRITE_RIL_ANSWER_CALL[{index}]="
            f"caller={caller}|method={method}|offset=0x{offset:04x}|proto={proto}"
        )

    stock_gap = (
        "(II)V" in stock_protos
        and "(II)V" not in c1_protos
        and any(row[3] == "(II)V" for row in calls)
    )
    c3a_same_as_c1 = c3a_protos == c1_protos and bool(c1_protos)
    print(
        "N1I_C1_GAP_STOCK_TO_C1_TELEPHONY_ABI="
        + ("CONFIRMED" if stock_gap else "NOT_CONFIRMED")
    )
    print(
        "N1I_C1_GAP_C3A_C1_TELEPHONY_METHOD_PARITY="
        + ("PASS" if c3a_same_as_c1 else "FAIL")
    )
    print(
        "N1I_C1_GAP_APP_LOCAL_TELEPHONY_SHADOW="
        + ("PRESENT_PARENT_FIRST_NON_AUTHORITY" if app_local_protos else "ABSENT")
    )

    print(f"N1I_C1_GAP_AGENT_CLASS_COUNT={len(agent_classes)}")
    print(f"N1I_C1_GAP_AGENT_FAILURE_COUNT={len(agent_failures)}")
    print(f"N1I_C1_GAP_AGENT_EXTERNAL_INBOUND_REF_COUNT={len(inbound)}")
    for index, row in enumerate(inbound):
        print(
            f"N1I_C1_GAP_AGENT_EXTERNAL_INBOUND_REF[{index}]="
            + "|".join(row)
        )

    expected_agent_surface = bool(agent_failures) and all(
        any(namespace in row for namespace in EXPECTED_AGENT_NAMESPACES)
        for row in agent_failures
    )
    agent_candidate = expected_agent_surface and not inbound
    print(
        "N1I_C1_GAP_AGENTPREMAIN_CLASSIFICATION="
        + (
            "CANDIDATE_ISOLATED_NON_ANDROID_DEBUG_AGENT"
            if agent_candidate
            else "REQUIRES_FURTHER_ANALYSIS"
        )
    )
    print(
        "N1I_C1_GAP_AGENTPREMAIN_FATAL_SUPPRESSION_AUTHORIZED=NO"
    )

    print(
        f"N1I_C1_GAP_TELEPHONY_FAILURE_ROW_COUNT={len(telephony_failures)}"
    )
    print(f"N1I_C1_GAP_OTHER_FAILURE_ROW_COUNT={len(other_failures)}")

    if other_failures:
        print("N1I_C1_MEMBER_GAP_CLASSIFICATION=FAIL_UNCLASSIFIED_FAILURES")
        return 3
    if len(telephony_failures) != 1:
        print("N1I_C1_MEMBER_GAP_CLASSIFICATION=FAIL_TELEPHONY_SHAPE")
        return 3
    if not c1_protos or not c3a_protos or not calls:
        print("N1I_C1_MEMBER_GAP_CLASSIFICATION=FAIL_BINARY_AUTHORITY")
        return 3

    if stock is not None and stock.dexes:
        if not stock_gap:
            print("N1I_C1_MEMBER_GAP_CLASSIFICATION=FAIL_STOCK_GAP_NOT_PROVEN")
            return 3
        print(
            "N1I_C1_MEMBER_GAP_CLASSIFICATION="
            "PASS_STOCK_TO_C1_ABI_GAP_PLUS_AGENT_CANDIDATE"
        )
        return 0

    print(
        "N1I_C1_MEMBER_GAP_CLASSIFICATION="
        "PASS_C1_C3A_BINARY_FACTS_STOCK_MEMBER_AUTHORITY_UNAVAILABLE"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--v6-evidence", type=Path)
    parser.add_argument("--product-out", type=Path)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        return selftest()
    if args.v6_evidence is None or args.product_out is None:
        parser.error("--v6-evidence and --product-out are required")

    try:
        return run(args)
    except (AuditError, OSError, ValueError) as exc:
        print(
            f"N1I_C1_MEMBER_GAP_CLASSIFICATION=FAIL reason={exc}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
