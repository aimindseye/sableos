#!/usr/bin/env python3
"""PR347 source-bound Tools APK provenance; no build, sign, device or image actions."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

MODULES = (
    'TB2SableCalculator', 'TB2SableCalendar', 'TB2SableCamera',
    'TB2SableDisplayCompat', 'TB2SableHub', 'TB2SableKeyboard',
    'TB2SableMail', 'TB2SableMedia', 'TB2SableReader', 'TB2SableSetup',
    'TB2SableTextReader', 'TB2SableTools', 'TB2SableWeather',
)
EXPECTED_PACKAGES = {
    'TB2SableCalculator':'org.sableos.calculator',
    'TB2SableCalendar':'org.sableos.calendar',
    'TB2SableCamera':'org.sableos.titan2.camera',
    'TB2SableDisplayCompat':'org.sableos.titan2.displaycompat',
    'TB2SableHub':'org.sableos.hub',
    'TB2SableKeyboard':'org.sableos.titan2.keyboard',
    'TB2SableMail':'org.sableos.mail',
    'TB2SableMedia':'org.sableos.media',
    'TB2SableReader':'org.sableos.reader',
    'TB2SableSetup':'org.sableos.titan2.setup',
    'TB2SableTextReader':'org.sableos.textreader',
    'TB2SableTools':'org.sableos.tools',
    'TB2SableWeather':'org.sableos.weather',
}
EXPECTED_SIGNING = {
    m: ('default_dev_cert' if m in {'TB2SableCamera', 'TB2SableDisplayCompat',
                                   'TB2SableKeyboard', 'TB2SableMail',
                                   'TB2SableSetup', 'TB2SableTools'} else 'presigned')
    for m in MODULES
}
BP_PIN = 'ab2b0654ee4b560aa1b741af913898c2d22d6963d33fbf78899f399e2fffd717'
MK_PIN = '8264edf7985b9aa1f62e36acbdd0d07767834705c6aee8680cd733e9232c6e7f'
TOOLS_REL = 'apps/titan2/platform/tools/build/outputs/apk/release/tools-release-unsigned.apk'
TOOLS_SRC = 'apps/titan2/platform/tools/src/main/java/org/sableos/tools/ui/TasksController.kt'
CI_NAME = 'TOOLS_RELEASE_CANDIDATE_V1.json'
ACK = 'PROMOTE_PR347_TOOLS_UNSIGNED_REVIEWED_SOURCE_BOUND'
SCHEMA = 'TB2_PR347_TOOLS_SOURCE_BOUND_V1'
MAX_BYTES = 128 * 1024 * 1024

class Hold(Exception):
    pass

def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as fh:
        for chunk in iter(lambda: fh.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()

def check_file(path: Path, limit=MAX_BYTES) -> Path:
    if not path.is_file() or path.is_symlink() or path.stat().st_nlink != 1:
        raise Hold(f'UNSAFE_OR_MISSING_FILE:{path}')
    size = path.stat().st_size
    if not 0 < size <= limit:
        raise Hold(f'INVALID_SIZE:{path}:{size}')
    return path

def command(args, cwd=None):
    p = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=12, check=False)
    return p.returncode, p.stdout, p.stderr

def git_commit(root: Path) -> str:
    rc, out, _ = command(['git', '-C', str(root), 'rev-parse', 'HEAD'])
    if rc or not re.fullmatch(r'[a-f0-9]{40}\n?', out):
        raise Hold('GIT_HEAD_UNAVAILABLE')
    return out.strip()

def check_clean(root: Path):
    rc, out, _ = command(['git', '-C', str(root), 'status', '--porcelain', '--untracked-files=all'])
    if rc or out:
        raise Hold('SABLE_SOURCE_NOT_CLEAN')

def check_branch(root: Path):
    rc, out, _ = command(['git', '-C', str(root), 'branch', '--show-current'])
    if rc or out.strip() != 'titan2/nextbuild-q25-app-conformance-20261021':
        raise Hold('WRONG_PR347_BRANCH')

def zip_meta(path: Path):
    check_file(path)
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        if len(names) > 4000 or sum(x.file_size for x in z.infolist()) > 512 * 1024 * 1024:
            raise Hold(f'APK_ZIP_UNCOMPRESSED_BOUNDS:{path}')
        if z.testzip() is not None or len(names) != len(set(names)) or 'AndroidManifest.xml' not in names or 'classes.dex' not in names:
            raise Hold(f'INVALID_APK_ZIP:{path}')
        # Reject ZIP paths that escape or embed weird APK structures.
        if any(n.startswith('/') or '/../' in f'/{n}' or '\\' in n for n in names):
            raise Hold(f'INVALID_APK_ENTRY:{path}')
        v1 = any(re.fullmatch(r'META-INF/[^/]+\.(?:SF|RSA|DSA|EC)', n, re.I) for n in names)
    with path.open('rb') as f:
        # The APK Signing Block magic lies immediately before central directory.
        f.seek(max(0, path.stat().st_size - 66000))
        end = f.read()
        idx = end.rfind(b'PK\x05\x06')
        if idx < 0 or idx + 22 > len(end):
            raise Hold(f'ZIP_END_RECORD_MISSING:{path}')
        cd_off = int.from_bytes(end[idx+16:idx+20], 'little')
        if cd_off >= path.stat().st_size or cd_off < 0:
            raise Hold(f'ZIP_CENTRAL_DIRECTORY_INVALID:{path}')
        f.seek(max(0, cd_off-24))
        apk_v2 = b'APK Sig Block 42' in f.read(24)
    return {'v1_signature_files': v1, 'v2_v3_signing_block': apk_v2}

def aapt_package(apk: Path, aapt: str) -> str:
    rc, out, err = command([aapt, 'dump', 'badging', str(apk)])
    if rc:
        raise Hold(f'AAPT_BADGING_FAILED:{apk}:{err[:130]}')
    m = re.search(r"(?m)^package: name='([^']+)'", out)
    if not m:
        raise Hold(f'APK_PACKAGE_UNPARSEABLE:{apk}')
    return m.group(1)

def _soong_code_views(raw: str) -> tuple[str, str]:
    """Same-length Blueprint views: one hides comments, one hides strings too.

    Braces, import keywords and field names in quoted strings/comments must not
    affect structural parsing. Reject unclosed comments/strings, fail closed.
    """
    uncommented = list(raw)
    structural = list(raw)
    state = 'code'
    i = 0
    while i < len(raw):
        ch = raw[i]
        nxt = raw[i + 1] if i + 1 < len(raw) else ''
        if state == 'code':
            if ch == '"':
                structural[i] = ' '
                state = 'string'
                i += 1
                continue
            if ch == '/' and nxt == '/':
                for j in (i, i+1):
                    uncommented[j] = structural[j] = ' '
                i += 2
                state = 'line_comment'
                continue
            if ch == '/' and nxt == '*':
                for j in (i, i+1):
                    uncommented[j] = structural[j] = ' '
                i += 2
                state = 'block_comment'
                continue
        elif state == 'string':
            structural[i] = ' '
            if ch == '\\':
                if i + 1 >= len(raw):
                    raise Hold('UNTERMINATED_SOONG_STRING_ESCAPE')
                structural[i + 1] = ' '
                i += 2
                continue
            if ch == '"':
                state = 'code'
            i += 1
            continue
        elif state == 'line_comment':
            if ch == '\n':
                state = 'code'
            else:
                uncommented[i] = structural[i] = ' '
            i += 1
            continue
        else:  # block_comment
            if ch == '*' and nxt == '/':
                for j in (i, i+1):
                    uncommented[j] = structural[j] = ' '
                i += 2
                state = 'code'
            else:
                uncommented[i] = structural[i] = ' '
                i += 1
            continue
        i += 1
    if state not in ('code', 'line_comment'):
        raise Hold('UNTERMINATED_SOONG_LITERAL_OR_COMMENT')
    return ''.join(uncommented), ''.join(structural)


def soong_app_import_fields(raw: str) -> list[str]:
    """Extract brace-balanced android_app_import blocks, exposing only top-level fields.

    A pinned Soong file may legitimately contain nested dictionaries; a flat
    ``[^{}]*`` regex wrongly drops those imports. Quotes and comments cannot
    create synthetic imports or braces. All work is bounded by the pinned
    <=256-KiB BP input and one pass per app-import block.
    """
    text, structural = _soong_code_views(raw)
    imports = []
    for match in re.finditer(r'\bandroid_app_import\s*\{', structural):
        opening = structural.find('{', match.start(), match.end())
        depth, closing = 0, None
        for i in range(opening, len(structural)):
            if structural[i] == '{':
                depth += 1
            elif structural[i] == '}':
                depth -= 1
                if depth == 0:
                    closing = i
                    break
                if depth < 0:
                    raise Hold('UNBALANCED_SOONG_IMPORT')
        if closing is None:
            raise Hold('UNBALANCED_SOONG_IMPORT')
        top = list(text[opening + 1:closing])
        depth = 1
        for offset, i in enumerate(range(opening + 1, closing)):
            ch = structural[i]
            if ch == '{':
                depth += 1
            if depth > 1 or ch == '}':
                top[offset] = ' '
            if ch == '}':
                depth -= 1
        imports.append(''.join(top))
    return imports


def bp_modules(bp: Path) -> dict:
    check_file(bp, 250000)
    if sha(bp) != BP_PIN:
        raise Hold('ACTIVE_BP_PIN_DRIFT')
    content = bp.read_text(encoding='utf-8')
    # Nested Soong dictionaries are legitimate. Only top-level property keys
    # of real android_app_import blocks may establish package/source authority.
    blocks = soong_app_import_fields(content)
    entries = {}
    for b in blocks:
        names = re.findall(r'\bname\s*:\s*"([^"\n]+)"', b)
        if len(names) != 1:
            raise Hold('SOONG_IMPORT_NAME_CARDINALITY_DRIFT')
        name = names[0]
        if name not in MODULES:
            continue
        if name in entries:
            raise Hold(f'DUPLICATE_SOONG_IMPORT:{name}')
        sign = ('default_dev_cert' if re.search(r'\bdefault_dev_cert\s*:\s*true\b', b)
                else 'presigned' if re.search(r'\bpresigned\s*:\s*true\b', b)
                else 'unknown')
        sources = re.findall(r'\bapk\s*:\s*"([^"\n]+)"', b)
        if len(sources) != 1:
            raise Hold(f'SOONG_IMPORT_APK_CARDINALITY_DRIFT:{name}')
        entries[name] = {'signing': sign, 'apk_field': sources[0],
                         'privileged': bool(re.search(r'\bprivileged\s*:\s*true\b', b))}
    if set(entries) != set(MODULES):
        raise Hold('ACTIVE_BP_13_MODULE_SET_DRIFT')
    for name, item in entries.items():
        if (item['signing'] != EXPECTED_SIGNING[name]
                or item['apk_field'] not in (f'prebuilt/{name}.apk', f'{name}.apk')
                or item['privileged']):
            raise Hold(f'SOONG_SIGNING_PATH_OR_PRIVILEGE_DRIFT:{name}:{item}')
    return entries

def product_inventory(android: Path, aapt: str) -> list:
    base = android / 'vendor/sable/tb2-rebuilt'
    mk = check_file(base/'tb2-apps.mk', 250000)
    if sha(mk) != MK_PIN:
        raise Hold('ACTIVE_MAKEFILE_PIN_DRIFT')
    # Reuse original product script's exact line-aware single-token extraction.
    chosen = re.findall(r'(?m)^\s*(TB2Sable[A-Za-z0-9]+)\s*\\?\s*$', mk.read_text(encoding='utf-8'))
    if len(chosen) != 13 or len(set(chosen)) != 13 or set(chosen) != set(MODULES):
        raise Hold('ACTIVE_MK_13_MODULE_SET_DRIFT')
    bp = bp_modules(base/'Android.bp')
    records=[]
    for name in MODULES:
        path=check_file(base/'prebuilt'/f'{name}.apk')
        z = zip_meta(path)
        package=aapt_package(path,aapt)
        if package!=EXPECTED_PACKAGES[name]:raise Hold(f'ACTIVE_PREBUILT_PACKAGE_DRIFT:{name}:{package}')
        records.append({'module':name,'signing':bp[name]['signing'],
                        'package':package,'bytes':path.stat().st_size,
                        'sha256':sha(path),'signature_shape':z})
    return records

def tools_candidate(sable: Path, aapt: str) -> dict:
    path=check_file(sable/TOOLS_REL)
    z=zip_meta(path)
    if z['v1_signature_files'] or z['v2_v3_signing_block']:
        raise Hold('TOOLS_RELEASE_APK_ALREADY_SIGNED_NOT_SOONG_DEFAULT_CERT_INPUT')
    pkg=aapt_package(path,aapt)
    if pkg!='org.sableos.tools':
        raise Hold('TOOLS_RELEASE_PACKAGE_DRIFT')
    return {'relative_path':TOOLS_REL,'package':pkg,'bytes':path.stat().st_size,'sha256':sha(path),'signature_shape':z}

def write_new(out: Path, data: dict):
    if out.exists() or out.is_symlink():
        raise Hold(f'OUTPUT_ALREADY_EXISTS:{out}')
    if not out.parent.is_dir():
        raise Hold(f'OUTPUT_PARENT_MISSING:{out.parent}')
    payload=(json.dumps(data,indent=2,sort_keys=True)+'\n').encode('utf-8')
    fd=os.open(out,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'wb') as f:
        f.write(payload)

def seal_tools(sable: Path, evidence: Path, aapt: str):
    check_branch(sable); check_clean(sable)
    commit=git_commit(sable)
    source=check_file(sable/TOOLS_SRC,100000)
    candidate=tools_candidate(sable,aapt)
    data={'schema':SCHEMA,'source_commit':commit,'source_rel':TOOLS_SRC,'source_sha256':sha(source),
          'source_bound_by':'canonical_CI_tools_assembleRelease_post_build',
          'candidate':candidate,'release_qualified':False,'flash_ready':False}
    write_new(evidence/CI_NAME,data)
    print(f'TB2_TOOLS_CANDIDATE=SEALED_UNSIGNED_SOURCE_BOUND sha256={candidate["sha256"]}')

def read_json(path: Path):
    check_file(path,8*1024*1024)
    return json.loads(path.read_text(encoding='utf-8'))

def proof(sable: Path, evidence: Path, aapt: str) -> dict:
    check_branch(sable); check_clean(sable)
    commit=git_commit(sable)
    # Require finished full CI summary and explicitly sealed *same* source commit.
    summary=check_file(evidence/'LOCAL_CI_SUMMARY.txt',2*1024*1024).read_text(encoding='utf-8')
    req=[f'SOURCE_COMMIT={commit}','SABLE_LOCAL_CI_SUMMARY_STATUS=PASS','SABLE_LOCAL_CI=PASS',
         'PROFILE=full','SABLEOS_DEVICE=titan2','SABLEOS_RELEASE_VERSION=TB2','CI_EXIT_CODE=0',
         'SABLE_LOCAL_CI_STAGE_TITAN2_TB2_APPS=PASS']
    if any(summary.count(line+'\n')==0 for line in req):
        raise Hold('CANONICAL_CI_FULL_PASS_FOR_SOURCE_MISSING')
    sealed=read_json(evidence/CI_NAME)
    if sealed.get('schema')!=SCHEMA or sealed.get('source_commit')!=commit:
        raise Hold('TOOLS_CANDIDATE_RECEIPT_COMMIT_DRIFT')
    source=check_file(sable/TOOLS_SRC,100000)
    if sealed.get('source_sha256')!=sha(source) or sealed.get('source_rel')!=TOOLS_SRC:
        raise Hold('TOOLS_SOURCE_FINGERPRINT_DRIFT')
    cand=tools_candidate(sable,aapt)
    if sealed.get('candidate')!=cand:
        raise Hold('TOOLS_CANDIDATE_HASH_PACKAGE_OR_SIGN_DRIFT')
    return {'commit':commit,'candidate':cand,'evidence_sha256':sha(evidence/CI_NAME),
            'summary_sha256':sha(evidence/'LOCAL_CI_SUMMARY.txt')}

def plan(sable: Path, android: Path, evidence: Path, out: Path, aapt: str):
    p=proof(sable,evidence,aapt)
    entries=product_inventory(android,aapt)
    selected=next(r for r in entries if r['module']=='TB2SableTools')
    if selected['package']!=p['candidate']['package']:
        raise Hold('ACTIVE_TOOLS_PREBUILT_PACKAGE_DRIFT')
    state='MATCH' if selected['sha256']==p['candidate']['sha256'] else 'REVIEWED_REPLACEMENT_REQUIRED'
    doc={'schema':SCHEMA,'status':'PASS_REVIEW_PLAN_NO_MUTATION',
         'source_commit':p['commit'],'ci_receipt_sha256':p['evidence_sha256'],
         'ci_summary_sha256':p['summary_sha256'],
         'sable_root':str(sable.resolve()),'android_root':str(android.resolve()),
         'tools_candidate':p['candidate'],'tools_selected_before':selected,
         'tools_disposition':state,'inventory':entries,
         'other_12_freshness':'NOT_PROVEN_BY_THIS_SLICE',
         'source_mutation':False,'aosp_mutation':False,'image':False,'device':False,'flash':False}
    write_new(out,doc)
    print(f'TB2_APK_PROVENANCE=PASS_REVIEW_ONLY tools={state} modules=13 other_12=OPEN')

def stage(sable: Path,android: Path,evidence: Path,plan_file: Path,out_dir: Path,aapt: str,ack: str,plan_sha: str,quiescent_ack=''):
    if quiescent_ack!='AOSP_BUILD_QUIESCENT_CONFIRMED':
        raise Hold('AOSP_BUILD_QUIESCENCE_ACK_MISSING')
    if ack!=ACK or not re.fullmatch('[a-f0-9]{64}',plan_sha):
        raise Hold('EXPLICIT_TOOLS_STAGE_AUTHORIZATION_MISSING')
    if not out_dir.is_dir() or any(out_dir.iterdir()):
        raise Hold('STAGE_OUTPUT_MUST_BE_EXISTING_EMPTY_DIR')
    if sha(check_file(plan_file,5*1024*1024))!=plan_sha:
        raise Hold('REVIEW_PLAN_SHA_DRIFT')
    old=read_json(plan_file)
    if old.get('schema')!=SCHEMA or old.get('status')!='PASS_REVIEW_PLAN_NO_MUTATION':
        raise Hold('REVIEW_PLAN_SCHEMA_DRIFT')
    check_file(sable/TOOLS_REL); candidate=tools_candidate(sable,aapt)
    current=proof(sable,evidence,aapt)
    active=product_inventory(android,aapt)
    selected=next(r for r in active if r['module']=='TB2SableTools')
    if (old['inventory']!=active or old['tools_candidate']!=candidate or old['source_commit']!=current['commit']
        or old['ci_receipt_sha256']!=current['evidence_sha256'] or old['ci_summary_sha256']!=current['summary_sha256']
        or old['sable_root']!=str(sable.resolve()) or old['android_root']!=str(android.resolve())):
        raise Hold('REVIEW_SOURCE_OR_DESTINATION_CHANGED')
    if selected['sha256']==candidate['sha256']:
        raise Hold('ALREADY_MATCHES_NO_STAGE_REQUIRED')
    dest=check_file(android/'vendor/sable/tb2-rebuilt/prebuilt/TB2SableTools.apk')
    if dest.stat().st_nlink!=1:
        raise Hold('DEST_MULTILINK')
    backup=out_dir/'TB2SableTools.before.apk'
    receipt=out_dir/'STAGE_RESULT.json'
    shutil.copy2(dest,backup)
    if sha(backup)!=selected['sha256']:
        raise Hold('BACKUP_BYTES_MISMATCH')
    tmp=None
    try:
        fd,name=tempfile.mkstemp(prefix='.PR347_tools_',suffix='.apk',dir=dest.parent)
        tmp=Path(name)
        with os.fdopen(fd,'wb') as f, (sable/TOOLS_REL).open('rb') as src:
            shutil.copyfileobj(src,f,1024*1024)
            f.flush();os.fsync(f.fileno())
        os.chmod(tmp,0o644)
        if sha(tmp)!=candidate['sha256']:
            raise Hold('STAGE_TEMP_CANDIDATE_HASH_DRIFT')
        if sha(dest)!=selected['sha256']:
            raise Hold('STAGE_DEST_CHANGED_BEFORE_REPLACE')
        os.replace(tmp,dest)
        tmp=None
        if sha(dest)!=candidate['sha256']:
            raise Hold('STAGED_DEST_HASH_MISMATCH')
        write_new(receipt,{'schema':SCHEMA,'status':'PASS_TOOLS_SOURCE_BOUND_AOSP_PREBUILT_PROMOTED_ENGINEERING_ONLY',
            'source_commit':current['commit'],'candidate_sha256':candidate['sha256'],
            'prior_sha256':selected['sha256'],'backup_path':str(backup),'target_path':str(dest),
            'image':False,'release_ready':False,'device':False,'flash':False,
            'other_12_freshness':'NOT_PROVEN'})
    except Exception:
        if tmp and tmp.exists():tmp.unlink()
        # Restore only if the current bytes are exactly the new payload; never clobber unknown external edits.
        if sha(dest)==candidate['sha256']:
            shutil.copy2(backup,dest)
        raise
    print('TB2_TOOLS_PREBUILT=PASS_REVIEWED_SOURCE_BOUND_PROMOTION_RELEASE_HOLD')

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='mode',required=True)
    for mode in ('seal-tools','plan','stage-tools'):
        p=sub.add_parser(mode)
        p.add_argument('--sable',required=True,type=Path)
        p.add_argument('--evidence',required=True,type=Path)
        p.add_argument('--aapt2',required=True)
        if mode!='seal-tools':p.add_argument('--android',required=True,type=Path)
        if mode=='plan':p.add_argument('--out',required=True,type=Path)
        if mode=='stage-tools':
            p.add_argument('--out',required=True,type=Path)
            p.add_argument('--plan-file',required=True,type=Path)
            p.add_argument('--plan-sha256',required=True)
            p.add_argument('--ack',required=True)
            p.add_argument('--quiescent-ack',required=True)
    a=parser.parse_args(argv)
    try:
        sable=a.sable.resolve(strict=True)
        if a.mode=='seal-tools':seal_tools(sable,a.evidence,a.aapt2)
        elif a.mode=='plan':plan(sable,a.android.resolve(strict=True),a.evidence,a.out,a.aapt2)
        else:stage(sable,a.android.resolve(strict=True),a.evidence,a.plan_file,a.out,a.aapt2,a.ack,a.plan_sha256,a.quiescent_ack)
    except (Hold, OSError, ValueError, zipfile.BadZipFile, subprocess.TimeoutExpired, KeyError, json.JSONDecodeError) as e:
        print(f'TB2_APK_PROVENANCE_HOLD={e}',file=sys.stderr)
        return 78
    return 0

if __name__=='__main__':sys.exit(main())
