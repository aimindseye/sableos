from __future__ import annotations

import importlib.util, json, os, subprocess, sys
from pathlib import Path
from unittest import mock
import pytest

SCRIPT = Path(__file__).with_name("SABLE_R1_R2_STATIC_PREFLIGHT.py")
spec = importlib.util.spec_from_file_location("r1r2", SCRIPT); assert spec and spec.loader
m = importlib.util.module_from_spec(spec); sys.modules[spec.name] = m; spec.loader.exec_module(m)
SIGNING = m.SIGNING_DOMAINS


def git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=repo, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout.strip()


def init_repo(path: Path) -> str:
    git(path, "init", "-q"); git(path, "config", "user.email", "test@example.invalid"); git(path, "config", "user.name", "test")
    git(path, "add", "."); git(path, "commit", "-q", "-m", "fixture"); return git(path, "rev-parse", "HEAD")


def fixture(tmp: Path):
    ws=tmp/"ws"; sr=ws/"script"; ur=ws/"packages/apps/Updater"; dev=ws/"development/tools"
    sr.mkdir(parents=True); (ur/"res/values").mkdir(parents=True); dev.mkdir(parents=True)
    gen=("#!/bin/bash\nsource x\n    CN=GrapheneOS\n"+"\n".join(["../../development/tools/make_key x", "openssl genrsa 4096", "../../external/avb/avbtool.py extract_public_key"]) + "\n")
    (sr/"generate-keys").write_text(gen); (sr/"common.sh").write_text("\n".join(SIGNING)+"\n")
    cfg=ur/"res/values/config.xml"; cfg.write_text('<resources>\n    <string name="url" translatable="false">https://releases.grapheneos.org/</string>\n</resources>\n')
    mk=dev/"make_key"; mk.write_text("# named pipes\nread -rp \"password will be visible\" password\nmknod ${one} p\nmknod ${two} p\necho \"creating ${1}.pk8 with password [${password}]\"\n")
    sh,uh=init_repo(sr),init_repo(ur)
    policy=tmp/"policy.json"; policy.write_text(json.dumps({"update_endpoint":{"url":"https://updates.sableos.org/","owner":"SableOS","ownership_status":"OPERATOR_VERIFIED"}},indent=2)+"\n")
    muts=[]
    for ident,repo,path,rel,old,new in [
      ("generator_subject",sr,sr/"generate-keys","generate-keys","    CN=GrapheneOS\n","    CN=SableOS\n"),
      ("updater_url",ur,cfg,"res/values/config.xml",'    <string name="url" translatable="false">https://releases.grapheneos.org/</string>\n','    <string name="url" translatable="false">https://updates.sableos.org/</string>\n')]:
        b=path.read_bytes(); a=b.replace(old.encode(),new.encode(),1)
        muts.append({"id":ident,"repo":"script" if repo==sr else "updater","workspace_path":str(path.relative_to(ws)),"repo_relative_path":rel,"preimage_git_blob":git(repo,"hash-object",rel),"preimage_sha256":m.sha256_bytes(b),"postimage_sha256":m.sha256_bytes(a),"postimage_git_blob":m.git_blob_bytes(a),"old":old,"new":new,"replacement_count":1})
    pb=policy.read_bytes(); plan=tmp/"plan.json"; plan.write_text(json.dumps({"r1_r1_policy":{"sha256":m.sha256_bytes(pb),"git_blob":m.git_blob_bytes(pb)},"source_repositories":{"script":{"path":"script","head":sh},"updater":{"path":"packages/apps/Updater","head":uh}},"mutations":muts},indent=2)+"\n")
    req={"sable_owned_harness":True,"raw_private_key_staging":"TMPFS_ONLY","persistent_key_store":"OFFLINE_ENCRYPTED_EXTERNAL_TO_ANDROID_WORKSPACE","persistent_workspace_key_material":False,"passphrase_prompt_hidden":True,"passphrase_in_argv":False,"passphrase_in_environment":False,"passphrase_in_logs":False,"passphrase_child_transport":"INHERITED_FILE_DESCRIPTOR_OR_EQUIVALENT_NON_ARGV_NON_ENV_CHANNEL","apk_key_algorithm":"RSA_4096","apk_cert_digest":"SHA256","apk_cert_validity_days":10000,"apk_private_format":"PKCS8_DER_SCRYPT_ENCRYPTED","avb_algorithm":"SHA256_RSA4096","atomic_external_publish_after_complete_inventory":True,"refuse_existing_destination":True,"operator_authorization_required":True,"signing_session_audit_required":True}
    contract=tmp/"keygen.json"; contract.write_text(json.dumps({"schema_version":1,"device":"panther","status":"STATIC_CONTRACT_ONLY_NO_KEY_GENERATION","certificate_subject":"CN=SableOS","signing_key_domains":SIGNING,"upstream_make_key":{"workspace_path":"development/tools/make_key","git_blob":m.git_blob_bytes(mk.read_bytes())},"production_harness_requirements":req,"expected_private_inventory":[*(f"{x}.pk8" for x in SIGNING),"avb.pem","id_ed25519"],"expected_public_inventory":[*(f"{x}.x509.pem" for x in SIGNING),"avb_pkmd.bin","id_ed25519.pub"],"execution_authorized":False},indent=2)+"\n")
    return ws,policy,plan,contract


def bind(plan: Path, contract: Path):
    m.EXPECTED_PLAN_SHA256=m.sha256_bytes(plan.read_bytes()); m.EXPECTED_KEYGEN_CONTRACT_SHA256=m.sha256_bytes(contract.read_bytes())


def call(tmp: Path, capsys, mutate=None):
    ws,p,pl,c=fixture(tmp); bind(pl,c)
    if mutate: mutate(ws,p,pl,c); bind(pl,c)
    with mock.patch.dict(os.environ,{},clear=True): rc=m.main(["--workspace",str(ws),"--policy",str(p),"--plan",str(pl),"--keygen-contract",str(c),"--evidence-root",str(tmp/"e")])
    return rc,capsys.readouterr().out,ws,p,pl,c


def test_git_allowlist(tmp_path):
    (tmp_path/"r").mkdir()
    with pytest.raises(RuntimeError): m.run_git(tmp_path/"r","clean","-fdx")


def test_auth_rejected_before_inputs(tmp_path,capsys):
    with mock.patch.dict(os.environ,{"KEY_GENERATION_AUTHORIZED":"YES"},clear=True): assert m.main(["--workspace",str(tmp_path/"missing")])==2
    assert "authorization.read_only_boundary" in capsys.readouterr().out


def test_clean_full_run(tmp_path,capsys):
    rc,out,*_=call(tmp_path,capsys); assert rc==0; assert "READY_TO_REQUEST_SOURCE_MUTATION_AUTHORIZATION" in out and "ERROR=0" in out


def test_workspace_unchanged_and_candidates_tmp(tmp_path,capsys):
    ws,p,pl,c=fixture(tmp_path); bind(pl,c); before=[(ws/"script/generate-keys").read_bytes(),(ws/"packages/apps/Updater/res/values/config.xml").read_bytes()]
    with mock.patch.dict(os.environ,{},clear=True): assert m.main(["--workspace",str(ws),"--policy",str(p),"--plan",str(pl),"--keygen-contract",str(c),"--evidence-root",str(tmp_path/"e")])==0
    out=capsys.readouterr().out; ev=Path(next(x.split("=",1)[1] for x in out.splitlines() if x.startswith("EVIDENCE_DIR=")))
    assert [x.read_bytes() for x in [ws/"script/generate-keys",ws/"packages/apps/Updater/res/values/config.xml"]]==before
    assert (ev/"candidates/script/generate-keys").is_file() and (ev/"SOURCE_MUTATION.patch").is_file()


@pytest.mark.parametrize("case",["blob","head","duplicate","policy","endpoint","makekey","existing_keys","postimage"])
def test_fail_closed_drift_cases(case,tmp_path,capsys):
    def mutate(ws,p,pl,c):
        if case=="blob": (ws/"script/generate-keys").write_text((ws/"script/generate-keys").read_text()+"#drift\n")
        elif case=="head": (ws/"script/extra").write_text("x"); git(ws/"script","add","extra"); git(ws/"script","commit","-q","-m","drift")
        elif case=="duplicate":
            f=ws/"script/generate-keys"; f.write_text(f.read_text()+"    CN=GrapheneOS\n"); o=json.loads(pl.read_text()); o["mutations"][0]["preimage_git_blob"]=git(ws/"script","hash-object","generate-keys"); o["mutations"][0]["preimage_sha256"]=m.sha256_bytes(f.read_bytes()); pl.write_text(json.dumps(o,indent=2)+"\n")
        elif case=="policy": p.write_text(p.read_text()+" \n")
        elif case=="endpoint":
            o=json.loads(p.read_text()); o["update_endpoint"]["ownership_status"]="UNVERIFIED"; p.write_text(json.dumps(o,indent=2)+"\n"); q=json.loads(pl.read_text()); b=p.read_bytes(); q["r1_r1_policy"]={"sha256":m.sha256_bytes(b),"git_blob":m.git_blob_bytes(b)}; pl.write_text(json.dumps(q,indent=2)+"\n")
        elif case=="makekey": (ws/"development/tools/make_key").write_text("drift\n")
        elif case=="existing_keys": (ws/"keys/panther").mkdir(parents=True)
        elif case=="postimage": o=json.loads(pl.read_text()); o["mutations"][0]["postimage_sha256"]="0"*64; pl.write_text(json.dumps(o,indent=2)+"\n")
    rc,out,*_=call(tmp_path,capsys,mutate); assert rc==2 and "ERROR" in out


@pytest.mark.parametrize("field,bad",[("passphrase_prompt_hidden",False),("passphrase_in_argv",True),("passphrase_in_environment",True),("passphrase_in_logs",True),("persistent_workspace_key_material",True),("raw_private_key_staging","DISK")])
def test_keygen_secret_policy_drift(field,bad,tmp_path,capsys):
    def mutate(ws,p,pl,c): o=json.loads(c.read_text()); o["production_harness_requirements"][field]=bad; c.write_text(json.dumps(o,indent=2)+"\n")
    rc,out,*_=call(tmp_path,capsys,mutate); assert rc==2 and f"keygen.requirement.{field}" in out


def test_upstream_password_findings_bound(tmp_path,capsys):
    rc,out,*_=call(tmp_path,capsys); assert rc==0; assert "visible_password_prompt" in out and "password_echo" in out


def test_repeated_20_unique_dirs(tmp_path,capsys):
    ws,p,pl,c=fixture(tmp_path); bind(pl,c); root=tmp_path/"e"
    with mock.patch.dict(os.environ,{},clear=True):
        for _ in range(20): assert m.main(["--workspace",str(ws),"--policy",str(p),"--plan",str(pl),"--keygen-contract",str(c),"--evidence-root",str(root)])==0
    assert len(list(root.iterdir()))==20; capsys.readouterr()


def test_plan_binding_mismatch(tmp_path,capsys):
    ws,p,pl,c=fixture(tmp_path); bind(pl,c); m.EXPECTED_PLAN_SHA256="0"*64
    with mock.patch.dict(os.environ,{},clear=True): assert m.main(["--workspace",str(ws),"--policy",str(p),"--plan",str(pl),"--keygen-contract",str(c),"--evidence-root",str(tmp_path/"e")])==2
    assert "plan.sha256" in capsys.readouterr().out


def test_contract_binding_mismatch(tmp_path,capsys):
    ws,p,pl,c=fixture(tmp_path); bind(pl,c); m.EXPECTED_KEYGEN_CONTRACT_SHA256="f"*64
    with mock.patch.dict(os.environ,{},clear=True): assert m.main(["--workspace",str(ws),"--policy",str(p),"--plan",str(pl),"--keygen-contract",str(c),"--evidence-root",str(tmp_path/"e")])==2
    assert "keygen_contract.sha256" in capsys.readouterr().out


def test_no_execution_surface():
    t=SCRIPT.read_text()
    for x in ("fastboot","adb reboot","openssl gen","ssh-keygen","rm -rf","shutil.rmtree","shell=True"): assert x not in t
    assert t.count("subprocess.run(")==1


def test_fresh_help():
    cp=subprocess.run([sys.executable,str(SCRIPT),"--help"],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True); assert cp.returncode==0 and "static source-mutation/keygen-contract preflight" in cp.stdout
