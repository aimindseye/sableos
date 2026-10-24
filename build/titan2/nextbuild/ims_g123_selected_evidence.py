#!/usr/bin/env python3
"""Bounded, read-only Track B selected FLOSS IMS G1/G2/G3 evidence census.

Source/config evidence is never promoted to runtime registration or HAL acceptance.
No ADB, Android build, image extraction, or vendor modification.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

IMS_MODULES = ('PhhIms', 'PhhImsOverlay', 'Iwlan', 'QualifiedNetworksService')
IMS_PACKAGE = 'me.phh.ims'
MAX_XML = 96
MAX_XML_BYTES = 512 * 1024
MAX_TARGET_MEMBERS = 250_000
MAX_HITS = 80

class Hold(Exception):
    pass


def safe_file(path: Path, limit: int = MAX_XML_BYTES) -> bytes:
    if not path.is_file() or path.is_symlink() or path.stat().st_size > limit:
        raise Hold('MISSING_LINK_OR_OVERSIZED_SOURCE:' + str(path))
    return path.read_bytes()


def selected_modules(text: str) -> dict[str, int]:
    # This is makefile source cardinality, NOT the evaluated Soong module graph.
    return {name: len(re.findall(r'^\s*' + re.escape(name) + r'\s*\\?\s*$', text, re.M))
            for name in IMS_MODULES}


def binding_values(xml_bytes: bytes) -> set[str]:
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return set()
    values = set()
    for el in root.iter():
        if el.attrib.get('name') in ('config_ims_mmtel_package', 'config_ims_rcs_package'):
            if (el.text or '').strip():
                values.add((el.text or '').strip())
    return values


def inspect_source(android: Path) -> dict:
    fl = android / 'vendor/sable/trackb13ims/track-b.mk'
    perm = android / 'vendor/sable/trackb13ims/privapp-permissions-me.phh.ims.xml'
    text = safe_file(fl).decode('utf-8')
    counts = selected_modules(text)
    perms_root = ET.fromstring(safe_file(perm))
    identities = [e.attrib.get('package') for e in perms_root.iter()
                  if e.tag == 'privapp-permissions']
    correct = all(n == 1 for n in counts.values()) and identities.count(IMS_PACKAGE) == 1
    overlay_dir = fl.parent
    candidates = []
    for p in overlay_dir.rglob('*.xml'):
        if len(candidates) >= MAX_XML:
            raise Hold('TOO_MANY_IMS_XML_SOURCES')
        if p.is_symlink():
            raise Hold('IMS_XML_SYMLINK')
        bindings = binding_values(safe_file(p))
        if bindings:
            candidates.append({'source': str(p.relative_to(android)), 'values': sorted(bindings)})
    return {
        'ims_source_selection': 'PASS_FLOSS_SOURCE_CARDINALITY' if correct else 'HOLD_SOURCE_SELECTION',
        'module_counts': counts,
        'privapp_package_matches': identities.count(IMS_PACKAGE),
        'overlay_binding_candidates': sorted(candidates, key=lambda entry: entry['source']),
        'g1_effective_compiled_binding': 'OPEN_REQUIRES_COMPILED_RESOURCES_AND_PACKAGE_MANAGER',
        'limitation': 'Makefile/XML text is not the evaluated image or an effective system overlay.',
    }


def inspect_target_files(path: Path | None) -> dict:
    if path is None:
        return {'status': 'NOT_SUPPLIED', 'g2_linker_namespace_abi': 'OPEN'}
    if not path.is_file() or path.is_symlink() or not zipfile.is_zipfile(path):
        raise Hold('TARGET_FILES_MISSING_LINK_OR_INVALID')
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
    if len(names) > MAX_TARGET_MEMBERS:
        raise Hold('TARGET_FILES_MEMBER_LIMIT')
    apps = sorted(n for n in names if n.endswith('.apk') and
                  any(token in n.lower() for token in ('phhims', 'imsservice', 'iwlan', 'qualifiednetworks')))
    libs = sorted(n for n in names if n.endswith('.so') and
                  any(token in n.lower() for token in ('ims', 'qns', 'iwlan')))
    return {
        'status': 'CANDIDATE_INVENTORY_ONLY',
        'target_files': str(path), 'archive_bytes': path.stat().st_size,
        'apk_candidates': apps[:MAX_HITS], 'shared_library_candidates': libs[:MAX_HITS],
        'apk_candidates_total': len(apps), 'shared_library_candidates_total': len(libs),
        'g2_linker_namespace_abi': 'OPEN_REQUIRES_ELF_DT_NEEDED_SYMBOLS_LINKER_NAMESPACE',
        'limitation': 'File paths do not prove package identity, class loading, ABI, or dynamic linker compatibility.',
    }


def inspect_vendor(vendor: Path | None) -> dict:
    if vendor is None:
        return {'status': 'NOT_SUPPLIED', 'g3_vendor_transport': 'OPEN'}
    if not vendor.is_dir() or vendor.is_symlink():
        raise Hold('VENDOR_DIRECTORY_MISSING_OR_LINK')
    candidates = []
    for rel in ('etc/vintf', 'etc/init'):
        root = vendor / rel
        if not root.exists():
            continue
        if root.is_symlink():
            raise Hold('VENDOR_EVIDENCE_SYMLINK')
        for index, p in enumerate(root.rglob('*')):
            if index >= 2000:
                raise Hold('VENDOR_CONFIG_PATH_SCAN_LIMIT')
            if not p.is_file():
                continue
            if p.is_symlink():
                raise Hold('VENDOR_EVIDENCE_SYMLINK')
            if len(candidates) >= MAX_HITS:
                raise Hold('VENDOR_EVIDENCE_FILE_LIMIT')
            if p.suffix not in ('.xml', '.rc'):
                continue
            raw = safe_file(p)
            if re.search(rb'ims|mtkradio|iwlan|qns', raw, re.I):
                candidates.append(str(p.relative_to(vendor)))
    return {
        'status': 'CANDIDATE_CONFIG_ONLY', 'config_candidates': sorted(candidates),
        'g3_vendor_transport': 'OPEN_REQUIRES_SELECTED_HAL_BINDER_TRANSACTIONS_AND_REGISTRATION',
        'limitation': 'VINTF and init declarations are not proof that a service starts or IPC succeeds.',
    }


def inspect(android: Path, target_files: Path | None, vendor: Path | None) -> dict:
    if not (android / 'build/envsetup.sh').is_file():
        raise Hold('INVALID_SELECTED_ANDROID_ROOT')
    return {
        'schema': 'PR347_SELECTED_FLOSS_IMS_G123_EVIDENCE_V1',
        'selected_android_source': str(android),
        'hardware_contact': False, 'source_mutation': False,
        'image_build': False, 'flash': False,
        'g1': inspect_source(android),
        'g2': inspect_target_files(target_files),
        'g3': inspect_vendor(vendor),
        'g123_runtime_acceptance': 'OPEN',
        'qualification': 'SOURCE_AND_ARTIFACT_CANDIDATES_ONLY_NOT_IMS_RUNTIME_PASS',
    }


def main(argv=None) -> int:
    pa = argparse.ArgumentParser()
    pa.add_argument('--android', required=True, type=Path)
    pa.add_argument('--out', required=True, type=Path)
    pa.add_argument('--target-files', type=Path)
    pa.add_argument('--vendor-root', type=Path)
    args = pa.parse_args(argv)
    try:
        android = args.android.resolve(strict=True)
        out = args.out.resolve(strict=False)
        if out.exists() or out.is_symlink():
            raise Hold('OUTPUT_EXISTS')
        if out.is_relative_to(android):
            raise Hold('OUTPUT_INSIDE_SELECTED_ANDROID')
        if args.vendor_root and out.is_relative_to(args.vendor_root.resolve(strict=True)):
            raise Hold('OUTPUT_INSIDE_VENDOR')
        result = inspect(android, args.target_files, args.vendor_root)
        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open('x', encoding='utf-8') as f:
            json.dump(result, f, indent=2, sort_keys=True)
            f.write('\n')
        print(json.dumps({'status': 'PASS_READ_ONLY_EVIDENCE_SAVED_NOT_RUNTIME_QUALIFIED',
                          'out': str(out), 'g1_source': result['g1']['ims_source_selection'],
                          'g123_runtime': 'OPEN'}, sort_keys=True))
        return 0 if result['g1']['ims_source_selection'].startswith('PASS') else 78
    except (Hold, OSError, ValueError, ET.ParseError, zipfile.BadZipFile) as e:
        print('PR347_IMS_EVIDENCE_HOLD=' + str(e), file=sys.stderr)
        return 78

if __name__ == '__main__':
    sys.exit(main())
