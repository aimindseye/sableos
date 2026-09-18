#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
ANDROID = ROOT / "apps" / "r8" / "android"
EXPECTED_LOCKFILES = {
    "calculator/gradle.lockfile", "convert/gradle.lockfile",
    "design/gradle.lockfile", "games/gradle.lockfile", "media/gradle.lockfile",
}
VERIFICATION_REL = "gradle/verification-metadata.xml"
EXPECTED_VERIFICATION_SHA256 = "d957a59609966206ba71077175032e8b13b4d71a0f51e513d5cbf7370b907905"
EXPECTED_COMPONENT_COUNT = 600
EXPECTED_SHA256_COUNT = 1011
NS = {"v": "https://schema.gradle.org/dependency-verification"}
EXPECTED_AAPT2 = {
    ("com.android.tools.build","aapt2","8.13.2-14304508","aapt2-8.13.2-14304508-linux.jar"):
        "839609d6d776d6dd60a02aa577d97193ce3e650cf1deaabf062321e23bbd6bf6",
    ("com.android.tools.build","aapt2","8.13.2-14304508","aapt2-8.13.2-14304508.pom"):
        "7e085634f503d42a4f3ea14488c25d4a573914db23c64a5a05a0c5c186c93112",
}
EXPECTED_LINT_RESOLUTION = {('com.android.tools', 'play-sdk-proto', '31.13.2', 'play-sdk-proto-31.13.2.jar'): 'c6fc15a5c203064cfd2c8a176fdeac72ae0a2d743ec47a2e66a0238d8d870b6b', ('com.android.tools', 'play-sdk-proto', '31.13.2', 'play-sdk-proto-31.13.2.pom'): '6e345e9ecc22ad3ff37ec679dd0a2f45cdcb7d6fe6aec3247b002c89b36a5461', ('com.android.tools.external.com-intellij', 'intellij-core', '31.13.2', 'intellij-core-31.13.2.jar'): '9a6faa6061d0f3d54a64decb61944c1b2c6927f8d325cd298c82c2a8d867ee68', ('com.android.tools.external.com-intellij', 'intellij-core', '31.13.2', 'intellij-core-31.13.2.pom'): '21f7df870290113ee81b1c5a373c9cc99a3c252a3fbc76737c08532e5e910e51', ('com.android.tools.external.com-intellij', 'kotlin-compiler', '31.13.2', 'kotlin-compiler-31.13.2.jar'): '552dfaffe295d08504870816c27fc09007e1231fb9b14c1ff9bbf861f9b35990', ('com.android.tools.external.com-intellij', 'kotlin-compiler', '31.13.2', 'kotlin-compiler-31.13.2.pom'): '2b2294ed4c07646b7ca29a362e04e5fbe489c5b3cf1d2bc4620a5c317666435f', ('com.android.tools.external.org-jetbrains', 'uast', '31.13.2', 'uast-31.13.2.jar'): '78f18ac2b2509fb6cb19058e8fc9585c361b97990dd7d5db0c2a94744dfb0a96', ('com.android.tools.external.org-jetbrains', 'uast', '31.13.2', 'uast-31.13.2.pom'): '5b5c6c6b71f9815ee531560946bf579b7b9fa806aa9dfbf1b567ed6aa598ee18', ('com.android.tools.lint', 'lint', '31.13.2', 'lint-31.13.2.jar'): '7f875a980ee23916439d368d073cfbc2ee4e4d99ffe1b3e13da794fef347f29a', ('com.android.tools.lint', 'lint', '31.13.2', 'lint-31.13.2.pom'): 'c8a5bb4a6ffbb17c07ff72e52c446e0271fd2b3e16c08be37207fd77008ae93e', ('com.android.tools.lint', 'lint-api', '31.13.2', 'lint-api-31.13.2.jar'): '8f770657dba33f305e583c62953a4f174c75a7b1cd2da7d31134be36a96ae2ac', ('com.android.tools.lint', 'lint-api', '31.13.2', 'lint-api-31.13.2.pom'): '664d7824766a943679cc031f516bd94843a8ba99cfd8ed0c33e68e8fbcc75407', ('com.android.tools.lint', 'lint-checks', '31.13.2', 'lint-checks-31.13.2.jar'): '3b64f395ae17fcea104882b00a4acdc7dc691f5daca5dff2bdde89fa052bb199', ('com.android.tools.lint', 'lint-checks', '31.13.2', 'lint-checks-31.13.2.pom'): '6298a80b18b08ff03b3c939424df874c68f449c1591cfa69680e93e3e516e6a2', ('com.android.tools.lint', 'lint-gradle', '31.13.2', 'lint-gradle-31.13.2.jar'): 'a42b6a41c436d90ca31a13d67afba1157b157efc892a7496f67432bf8a831cbd', ('com.android.tools.lint', 'lint-gradle', '31.13.2', 'lint-gradle-31.13.2.pom'): 'cbd02ebf01bc37b150ad7ace3f2d533c8ebb0b490e8584e09c9bc4152ad85e66', ('com.google.guava', 'guava-parent', '33.3.1-android', 'guava-parent-33.3.1-android.pom'): '6e11986ea7250b51f847157e2dc937f32a306804dfce0007a5e81ddb9b95c579', ('com.google.guava', 'guava-parent', '33.3.1-jre', 'guava-parent-33.3.1-jre.pom'): '55441db27e8869dfefe053059bdf478bdc7e95585642bf391f0023345fd56287', ('commons-codec', 'commons-codec', '1.10', 'commons-codec-1.10.jar'): '4241dfa94e711d435f29a4604a3e2de5c4aa3c165e23bd066be6fc1fc4309569', ('commons-codec', 'commons-codec', '1.10', 'commons-codec-1.10.pom'): 'bdb8db7012d112a6e3ea8fdb7c510b300d99eff0819d27dddba9c43397ea4cfb', ('org.apache', 'apache', '15', 'apache-15.pom'): '36c2f2f979ac67b450c0cb480e4e9baf6b40f3a681f22ba9692287d1139ad494', ('org.apache.commons', 'commons-parent', '35', 'commons-parent-35.pom'): '7098a1ab8336ecd4c9dc21cbbcac869f82c66f64b8ac4f7988d41b4fcb44e49a', ('org.apache.httpcomponents', 'httpclient', '4.5.6', 'httpclient-4.5.6.jar'): 'c03f813195e7a80e3608d0ddd8da80b21696a4c92a6a2298865bf149071551c7', ('org.apache.httpcomponents', 'httpclient', '4.5.6', 'httpclient-4.5.6.pom'): '7efc1241e73e7fbb268bfd33242d11ebd3ca07061d7d85f2962dc32a0f0b8855', ('org.codehaus.groovy', 'groovy', '3.0.22', 'groovy-3.0.22.jar'): 'c92c92c4b9b183f9981ba7399f36592e5e3ad6f4cdac7101b5a22cc17998d13f', ('org.codehaus.groovy', 'groovy', '3.0.22', 'groovy-3.0.22.pom'): '51b731e5cff121efd6d320f4a801cd616869c5bed4e9c0e353b29060b1d2355f', ('org.jetbrains.kotlin', 'kotlin-reflect', '2.2.0', 'kotlin-reflect-2.2.0.jar'): '230d91c2e410e3cfca3a4dc73d255455f62ff52aac091a33397a6e30bde91bf7', ('org.jetbrains.kotlin', 'kotlin-reflect', '2.2.0', 'kotlin-reflect-2.2.0.pom'): 'deed831efcb663e4cf3d5121e5ae796f201e37b813d2c7d607b5f1f8a86fe52e', ('org.jetbrains.kotlinx', 'kotlinx-coroutines-bom', '1.8.0', 'kotlinx-coroutines-bom-1.8.0.pom'): '1239e9dbe1397cd5971342956b2511bc3ace7b641842e4372a088dcfa8b9ad55', ('org.junit', 'junit-bom', '5.10.2', 'junit-bom-5.10.2.module'): 'de23b114b3e4119a8fe6eb17bed5a3852816698bace67071579d6d927ebb080a'}

def sha256(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def fail(reason):
    raise SystemExit(f"SABLE_GRADLE_SUPPLY_CHAIN_FAIL={reason}")

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--manifest")
    args=parser.parse_args()

    actual_locks={
        str(p.relative_to(ANDROID)) for p in ANDROID.rglob("gradle.lockfile") if p.is_file()
    }
    if actual_locks != EXPECTED_LOCKFILES:
        fail(f"LOCKFILE_SET_MISMATCH:actual={sorted(actual_locks)}:expected={sorted(EXPECTED_LOCKFILES)}")

    files=[]
    for rel in sorted(EXPECTED_LOCKFILES):
        path=ANDROID/rel
        text=path.read_text(encoding="utf-8")
        if not text.startswith("# This is a Gradle generated file for dependency locking."):
            fail(f"LOCKFILE_HEADER_INVALID:{rel}")
        if "/home/" in text or "/tmp/" in text:
            fail(f"LOCKFILE_VOLATILE_PATH:{rel}")
        files.append({"path":rel,"sha256":sha256(path),"size":path.stat().st_size})

    verification=ANDROID/VERIFICATION_REL
    if not verification.is_file() or verification.stat().st_size==0:
        fail("VERIFICATION_METADATA_MISSING")
    vsha=sha256(verification)
    if vsha != EXPECTED_VERIFICATION_SHA256:
        fail(f"VERIFICATION_METADATA_SHA256:actual={vsha}:expected={EXPECTED_VERIFICATION_SHA256}")
    raw=verification.read_text(encoding="utf-8")
    if "/home/" in raw or "/tmp/" in raw:
        fail("VERIFICATION_METADATA_VOLATILE_PATH")

    root=ET.parse(verification).getroot()
    config=root.find("v:configuration",NS)
    if config is None:
        fail("VERIFICATION_CONFIGURATION_MISSING")
    vm=config.find("v:verify-metadata",NS)
    vs=config.find("v:verify-signatures",NS)
    if vm is None or vm.text!="true":
        fail("VERIFY_METADATA_NOT_TRUE")
    if vs is None or vs.text!="false":
        fail("VERIFY_SIGNATURES_UNEXPECTED")

    components=root.findall(".//v:component",NS)
    hashes=root.findall(".//v:sha256",NS)
    if len(components)!=EXPECTED_COMPONENT_COUNT:
        fail(f"VERIFICATION_COMPONENT_COUNT:actual={len(components)}:expected={EXPECTED_COMPONENT_COUNT}")
    if len(hashes)!=EXPECTED_SHA256_COUNT:
        fail(f"VERIFICATION_SHA256_COUNT:actual={len(hashes)}:expected={EXPECTED_SHA256_COUNT}")

    actual={}
    for component in components:
        coord=(component.attrib.get("group",""),component.attrib.get("name",""),component.attrib.get("version",""))
        for artifact in component.findall("v:artifact",NS):
            nodes=artifact.findall("v:sha256",NS)
            if len(nodes)==1:
                actual[(*coord,artifact.attrib.get("name",""))]=nodes[0].attrib.get("value","")

    for label,expected in (("AAPT2",EXPECTED_AAPT2),("LINT_RESOLUTION",EXPECTED_LINT_RESOLUTION)):
        selected={key:actual.get(key) for key in expected}
        if selected!=expected:
            fail(f"{label}_VERIFICATION_HASH_MISMATCH:actual={selected}:expected={expected}")

    files.append({"path":VERIFICATION_REL,"sha256":vsha,"size":verification.stat().st_size})
    manifest={
        "schema":"sableos-gradle-supply-chain-state-v1",
        "lockfile_count":len(EXPECTED_LOCKFILES),
        "verification_component_count":len(components),
        "verification_sha256_count":len(hashes),
        "aapt2_verified_artifact_count":len(EXPECTED_AAPT2),
        "lint_resolution_verified_artifact_count":len(EXPECTED_LINT_RESOLUTION),
        "files":files,
    }
    if args.manifest:
        pathlib.Path(args.manifest).write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n",encoding="utf-8")

    print(f"GRADLE_LOCKFILE_COUNT={len(EXPECTED_LOCKFILES)}")
    print(f"GRADLE_VERIFICATION_COMPONENT_COUNT={len(components)}")
    print(f"GRADLE_VERIFICATION_SHA256_COUNT={len(hashes)}")
    print(f"GRADLE_AAPT2_VERIFIED_ARTIFACT_COUNT={len(EXPECTED_AAPT2)}")
    print(f"GRADLE_LINT_RESOLUTION_VERIFIED_ARTIFACT_COUNT={len(EXPECTED_LINT_RESOLUTION)}")
    print("GRADLE_VERIFY_METADATA=true")
    print("GRADLE_VERIFY_SIGNATURES=false")
    print("GRADLE_AAPT2_VERIFICATION=PASS")
    print("GRADLE_LINT_RESOLUTION_VERIFICATION=PASS")
    print("SABLE_GRADLE_SUPPLY_CHAIN_STATE=PASS")

if __name__=="__main__":
    main()
