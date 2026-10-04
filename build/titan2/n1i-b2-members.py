#!/usr/bin/env python3
"""Titan 2 N1I-B2 exact method/field resolver. Offline only: no device, no network, no imports.

Resolves every member/type reference in an app's DEX code against the classpath the app would see
at runtime on one side (stock or C3A), with ART/JVM resolution semantics:

  class visibility   boot classpath (incl. APEX fragments) -> declared shared libraries
                     (uses-library order) -> app dexes (multidex order). First definition wins, so
                     an app-local duplicate never overrides a boot class (parent-first delegation).
                     services.jar and other non-visible jars never resolve; they are only used to
                     say where a missing class would have come from.
  fields             exact name + type; declared -> superinterfaces -> superclasses
  methods            exact name + proto; class / interface resolution per invoke kind;
                     constructors are looked up in the referenced class only (never inherited);
                     invoke-static/direct on an interface use only that interface's own methods
  kind checks        invoke-virtual on interface / invoke-interface on class -> ICCE_KIND;
                     static/instance disagreement -> STATIC_INSTANCE_MISMATCH;
                     invoke-super must name a superclass or a direct superinterface of the caller
  access             public / private / protected (subclass or same runtime package) / package;
                     runtime package = (defining loader, package name); final-field writes
                     outside the declaring class are violations

Results: RESOLVED CLASS_MISSING METHOD_MISSING FIELD_MISSING DESCRIPTOR_MISMATCH
         STATIC_INSTANCE_MISMATCH ACCESS_VIOLATION ICCE_KIND

Subcommands
  resolve   one side -> MEMBERS.tsv, CLASS_CHECKS.tsv, DUPLICATES.tsv, MEMBERS_SUMMARY.env
  compare   stock vs C3A resolve outputs -> BEHAVIOR_GAP_CANDIDATES.tsv. A reference that resolves on
            stock but not on C3A is only a candidate AOSP_EQUIVALENT_WITH_BEHAVIOR_GAP, never an
            authorization to import stock framework code.

Not modelled (reported as limitations, never silently assumed): hidden-API enforcement, the
verification-time protected target receiver subtype rule, verifier type checks of arguments,
nest-based access, and selection-time AbstractMethodError for invoke-super. Link-time protected
symbolic-owner access is modelled explicitly.

Exit codes: 0 completed   2 input error or decoder/oracle disagreement (nothing written)
"""
from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import n1i_static as S  # noqa: E402

TOOL_VERSION = "1.0.0"
RESULTS = ("RESOLVED", "CLASS_MISSING", "METHOD_MISSING", "FIELD_MISSING", "DESCRIPTOR_MISMATCH",
           "STATIC_INSTANCE_MISMATCH", "ACCESS_VIOLATION", "ICCE_KIND")
ACC_VARARGS = 0x80
POLYMORPHIC_OWNERS = ("Ljava/lang/invoke/MethodHandle;", "Ljava/lang/invoke/VarHandle;")
OBJECT = "Ljava/lang/Object;"


class InputError(Exception):
    pass


@dataclass
class Klass:
    cd: S.ClassDef
    loader: str          # boot | shared:<name> | app
    provider: str        # BOOT | APEX | SHARED_LIB:<name> | APP
    path: str

    @property
    def desc(self) -> str:
        return self.cd.descriptor

    @property
    def is_interface(self) -> bool:
        return bool(self.cd.access & S.ACC_INTERFACE)

    @property
    def package(self) -> str:
        d = self.desc[1:-1]
        return d.rsplit("/", 1)[0] if "/" in d else ""


def package_of(desc: str) -> str:
    d = desc[1:-1]
    return d.rsplit("/", 1)[0] if "/" in d else ""


@dataclass
class Outcome:
    result: str
    detail: str = ""
    decl: Klass | None = None
    member_access: int = 0


class World:
    """The class space visible to the app on one side, in ART lookup order."""

    def __init__(self):
        self.classes: dict[str, Klass] = {}
        self.duplicates: list[tuple[str, str, str]] = []
        self.hidden: dict[str, str] = {}        # class -> non-visible jar it lives in

    def add(self, container: S.DexContainer, loader: str, provider: str) -> None:
        for entry, dex in container.dexes:
            for cd in dex.classes:
                where = f"{container.path}!{entry}"
                if cd.descriptor in self.classes:
                    first = self.classes[cd.descriptor]
                    self.duplicates.append((cd.descriptor, f"{first.provider}:{first.path}", f"{provider}:{where}"))
                else:
                    self.classes[cd.descriptor] = Klass(cd, loader, provider, where)

    def add_hidden(self, container: S.DexContainer) -> None:
        for entry, dex in container.dexes:
            for cd in dex.classes:
                self.hidden.setdefault(cd.descriptor, f"{container.path}!{entry}")

    # ---- class resolution
    def klass(self, desc: str) -> Klass | None:
        return self.classes.get(desc)

    def missing_detail(self, desc: str) -> str:
        if desc in self.hidden:
            return f"present only in non-visible {Path(self.hidden[desc].split('!')[0]).name}"
        return "not on the visible classpath"

    def type_ok(self, desc: str) -> tuple[bool, str]:
        """Array element / class type existence. Primitives always exist."""
        el = desc.lstrip("[")
        if len(el) == 1:
            return True, ""
        k = self.klass(el)
        return (k is not None), ("" if k else f"{el} {self.missing_detail(el)}")

    def superclasses(self, k: Klass) -> tuple[list[Klass], str | None]:
        """k's superclass chain (excluding k). Second value names a missing superclass, if any."""
        out, cur, seen = [], k, {k.desc}
        while cur.cd.superclass:
            nxt = self.klass(cur.cd.superclass)
            if nxt is None:
                return out, cur.cd.superclass
            if nxt.desc in seen:
                return out, f"{nxt.desc} (cycle)"
            seen.add(nxt.desc)
            out.append(nxt)
            cur = nxt
        return out, None

    def superinterfaces(self, k: Klass) -> tuple[list[Klass], str | None]:
        """All superinterfaces of k and of its superclasses, breadth-first, without duplicates."""
        out, seen, queue = [], set(), list(k.cd.interfaces)
        sups, missing = self.superclasses(k)
        for s in sups:
            queue += list(s.cd.interfaces)
        while queue:
            d = queue.pop(0)
            if d in seen:
                continue
            seen.add(d)
            ik = self.klass(d)
            if ik is None:
                return out, d
            out.append(ik)
            queue += list(ik.cd.interfaces)
        return out, missing

    def is_subclass(self, k: Klass, of: Klass) -> bool:
        if k.desc == of.desc:
            return True
        return any(s.desc == of.desc for s in self.superclasses(k)[0])


# =============================================================================
# Access rules
# =============================================================================
def same_runtime_package(a: Klass, b: Klass) -> bool:
    return a.loader == b.loader and a.package == b.package


def class_accessible(caller: Klass, target: Klass) -> bool:
    return bool(target.cd.access & S.ACC_PUBLIC) or same_runtime_package(caller, target)


def member_accessible(
    w: World,
    caller: Klass,
    symbolic_owner: Klass,
    decl: Klass,
    acc: int,
    is_static: bool,
) -> tuple[bool, str]:
    if acc & S.ACC_PUBLIC:
        return True, ""
    if acc & S.ACC_PRIVATE:
        return caller.desc == decl.desc, "private member of another class"
    if acc & S.ACC_PROTECTED:
        if same_runtime_package(caller, decl):
            return True, ""
        if not w.is_subclass(caller, decl):
            return False, "protected member, caller is neither a subclass nor in the same runtime package"
        if not is_static:
            owner_related = w.is_subclass(caller, symbolic_owner) or w.is_subclass(symbolic_owner, caller)
            if not owner_related:
                return False, (
                    "protected instance member: symbolic owner is neither caller, "
                    "a superclass of caller, nor a subclass of caller"
                )
        return True, ""
    if same_runtime_package(caller, decl):
        return True, ""
    if caller.package == decl.package:
        return False, "package-private member: same package name but different class loader"
    return False, "package-private member of another package"


# =============================================================================
# Field and method lookup
# =============================================================================
def lookup_field(w: World, c: Klass, name: str, ftype: str):
    """JVMS 5.4.3.2 recursive order. Returns (decl, field/near_type, missing_type)."""
    near = None
    seen: set[str] = set()

    def visit(k: Klass):
        nonlocal near
        if k.desc in seen:
            return None, None, f"{k.desc} (cycle)"
        seen.add(k.desc)
        for f in k.cd.fields:
            if f.ref.name == name:
                if f.ref.type == ftype:
                    return k, f, None
                near = near or f.ref.type
        # Field resolution searches this class/interface's direct superinterfaces
        # recursively before recursing into its direct superclass.
        for desc in k.cd.interfaces:
            ik = w.klass(desc)
            if ik is None:
                return None, None, desc
            decl, field, missing = visit(ik)
            if field is not None or missing is not None:
                return decl, field, missing
        if k.cd.superclass:
            sk = w.klass(k.cd.superclass)
            if sk is None:
                return None, None, k.cd.superclass
            return visit(sk)
        return None, None, None

    decl, field, missing = visit(c)
    if field is not None:
        return decl, field, None
    return None, near, missing


def _find(k: Klass, name: str, proto: str, near: list):
    for m in k.cd.methods:
        if m.ref.name == name:
            if m.ref.proto == proto:
                return m
            near.append(m.ref.proto)
    return None


def lookup_class_method(w: World, c: Klass, name: str, proto: str):
    """JVMS 5.4.3.3 (class method resolution) without the interface check, which callers do."""
    near: list = []
    for k in [c] + w.superclasses(c)[0]:
        m = _find(k, name, proto, near)
        if m:
            return k, m, near
    # maximally-specific superinterface methods: non-static, non-private; prefer non-abstract
    cands = []
    for ik in w.superinterfaces(c)[0]:
        m = _find(ik, name, proto, near)
        if m and not m.access & (S.ACC_STATIC | S.ACC_PRIVATE):
            cands.append((ik, m))
    concrete = [x for x in cands if not x[1].access & S.ACC_ABSTRACT]
    pick = (concrete or cands or [None])[0]
    return (pick[0], pick[1], near) if pick else (None, None, near)


def lookup_interface_method(w: World, c: Klass, name: str, proto: str):
    """JVMS 5.4.3.4 (interface method resolution) without the interface check."""
    near: list = []
    m = _find(c, name, proto, near)
    if m:
        return c, m, near
    obj = w.klass(OBJECT)
    if obj:
        m = _find(obj, name, proto, near)
        if m and m.access & S.ACC_PUBLIC and not m.access & S.ACC_STATIC:
            return obj, m, near
    cands = []
    for ik in w.superinterfaces(c)[0]:
        m = _find(ik, name, proto, near)
        if m and not m.access & (S.ACC_STATIC | S.ACC_PRIVATE):
            cands.append((ik, m))
    concrete = [x for x in cands if not x[1].access & S.ACC_ABSTRACT]
    pick = (concrete or cands or [None])[0]
    return (pick[0], pick[1], near) if pick else (None, None, near)


def lookup_declared(c: Klass, name: str, proto: str):
    near: list = []
    m = _find(c, name, proto, near)
    return (c, m, near) if m else (None, None, near)


# =============================================================================
# Reference resolution
# =============================================================================
def resolve_type(w: World, caller: Klass, desc: str) -> Outcome:
    el = desc.lstrip("[")
    if len(el) == 1:
        return Outcome("RESOLVED", "primitive")
    k = w.klass(el)
    if k is None:
        return Outcome("CLASS_MISSING", f"{el} {w.missing_detail(el)}")
    if not class_accessible(caller, k):
        return Outcome("ACCESS_VIOLATION", f"class {el} is not public and not in the caller's runtime package", k)
    return Outcome("RESOLVED", "", k)


def _owner(w: World, caller: Klass, owner: str) -> tuple[Klass | None, Outcome | None]:
    if owner.startswith("["):
        # array clone()/Object methods: resolve against java.lang.Object
        o = w.klass(OBJECT)
        return (o, None) if o else (None, Outcome("CLASS_MISSING", f"{OBJECT} {w.missing_detail(OBJECT)}"))
    k = w.klass(owner)
    if k is None:
        return None, Outcome("CLASS_MISSING", f"{owner} {w.missing_detail(owner)}")
    if not class_accessible(caller, k):
        return None, Outcome("ACCESS_VIOLATION", f"class {owner} is not accessible from {caller.desc}", k)
    return k, None


def resolve_field(w: World, caller: Klass, ref: S.FieldRef, kind: str) -> Outcome:
    c, bad = _owner(w, caller, ref.cls)
    if bad:
        return bad
    decl, f, missing_super = lookup_field(w, c, ref.name, ref.type)
    if decl is None:
        near = f  # when not found, the second slot carries the near-miss field type (or None)
        if missing_super:
            return Outcome("CLASS_MISSING",
                           f"superclass/interface {missing_super} of {ref.cls} {w.missing_detail(missing_super)}")
        if near:
            return Outcome("DESCRIPTOR_MISMATCH", f"field {ref.name} exists with type {near}, referenced as {ref.type}")
        return Outcome("FIELD_MISSING", f"{ref.cls}.{ref.name}:{ref.type}")
    want_static = kind in ("sget", "sput")
    if bool(f.access & S.ACC_STATIC) != want_static:
        return Outcome("STATIC_INSTANCE_MISMATCH",
                       f"{kind} on {'static' if f.access & S.ACC_STATIC else 'instance'} field", decl, f.access)
    ok, why = member_accessible(w, caller, c, decl, f.access, bool(f.access & S.ACC_STATIC))
    if not ok:
        return Outcome("ACCESS_VIOLATION", why, decl, f.access)
    if kind in ("iput", "sput") and f.access & S.ACC_FINAL and caller.desc != decl.desc:
        return Outcome("ACCESS_VIOLATION", "write to a final field outside its declaring class", decl, f.access)
    return Outcome("RESOLVED", "", decl, f.access)


def resolve_method(w: World, caller: Klass, ref: S.MethodRef, kind: str) -> Outcome:
    c, bad = _owner(w, caller, ref.cls)
    if bad:
        return bad
    if kind == "polymorphic":
        if ref.cls not in POLYMORPHIC_OWNERS:
            return Outcome("ICCE_KIND", f"invoke-polymorphic on {ref.cls}")
        for m in c.cd.methods:
            if m.ref.name == ref.name and m.access & S.ACC_NATIVE and m.access & ACC_VARARGS:
                return Outcome("RESOLVED", "signature-polymorphic", c, m.access)
        return Outcome("METHOD_MISSING", f"no signature-polymorphic {ref.cls}.{ref.name}")
    if kind in ("virtual",) and c.is_interface:
        return Outcome("ICCE_KIND", f"invoke-virtual on interface {ref.cls}", c)
    if kind == "interface" and not c.is_interface:
        return Outcome("ICCE_KIND", f"invoke-interface on class {ref.cls}", c)
    if kind == "super":
        if c.is_interface:
            if ref.cls not in caller.cd.interfaces:
                return Outcome("ICCE_KIND", f"invoke-super on {ref.cls}, not a direct superinterface of {caller.desc}", c)
        elif not any(s.desc == c.desc for s in w.superclasses(caller)[0]):
            return Outcome("ICCE_KIND", f"invoke-super on {ref.cls}, not a superclass of {caller.desc}", c)
    if ref.name == "<init>":
        if kind != "direct":
            return Outcome("ICCE_KIND", f"constructor invoked with invoke-{kind}", c)
        decl, m, near = lookup_declared(c, ref.name, ref.proto)     # constructors are never inherited
    elif kind in ("static", "direct") and c.is_interface:
        decl, m, near = lookup_declared(c, ref.name, ref.proto)
    elif kind == "interface" or (kind == "super" and c.is_interface):
        decl, m, near = lookup_interface_method(w, c, ref.name, ref.proto)
    else:
        decl, m, near = lookup_class_method(w, c, ref.name, ref.proto)
    if m is None:
        miss = w.superclasses(c)[1] or w.superinterfaces(c)[1]
        if miss:
            return Outcome("CLASS_MISSING", f"superclass/interface {miss} of {ref.cls} {w.missing_detail(miss)}")
        if ref.name == "<init>":
            inherited = [k.desc for k in w.superclasses(c)[0] if lookup_declared(k, "<init>", ref.proto)[1]]
            return Outcome("METHOD_MISSING", f"constructor {ref.cls}-><init>{ref.proto} not declared"
                           + (f"; {inherited[0]} declares it but constructors are not inherited" if inherited else ""))
        if near:
            return Outcome("DESCRIPTOR_MISMATCH",
                           f"{ref.name} exists as {','.join(sorted(set(near)))}, referenced as {ref.proto}")
        return Outcome("METHOD_MISSING", f"{ref.cls}->{ref.name}{ref.proto}")
    is_static = bool(m.access & S.ACC_STATIC)
    if (kind == "static") != is_static:
        return Outcome("STATIC_INSTANCE_MISMATCH",
                       f"invoke-{kind} on {'static' if is_static else 'instance'} method", decl, m.access)
    ok, why = member_accessible(w, caller, c, decl, m.access, bool(m.access & S.ACC_STATIC))
    if not ok:
        return Outcome("ACCESS_VIOLATION", why, decl, m.access)
    return Outcome("RESOLVED", "", decl, m.access)


HANDLE_KIND = {0: ("field", "sput"), 1: ("field", "sget"), 2: ("field", "iput"), 3: ("field", "iget"),
               4: ("method", "static"), 5: ("method", "virtual"), 6: ("method", "direct"),
               7: ("method", "direct"), 8: ("method", "interface")}


def resolve_handle(w: World, caller: Klass, mh: S.MethodHandle) -> tuple[str, Outcome]:
    what, kind = HANDLE_KIND[mh.kind]
    if what == "field":
        return f"method-handle-{kind}", resolve_field(w, caller, mh.target, kind)
    if mh.kind == 5 and (k := w.klass(mh.target.cls)) is not None and k.is_interface:
        kind = "interface"
    return f"method-handle-invoke-{kind}", resolve_method(w, caller, mh.target, kind)


# =============================================================================
# Driver
# =============================================================================
@dataclass
class Row:
    caller: str
    site: str
    ref_kind: str
    owner: str
    name: str
    desc: str
    out: Outcome


def references(w: World, caller: Klass, dex: S.DexFile, m: S.EncodedMethod):
    for ins in S.instructions(dex, m):
        site = f"{m.ref.name}{m.ref.proto}@{ins.offset:#06x}"
        rk = ins.ref_kind
        if rk == "type":
            yield Row(caller.desc, site, ins.name, ins.ref, "", "", resolve_type(w, caller, ins.ref))
        elif rk == "field":
            fk = S.FIELD_KIND[ins.op]
            yield Row(caller.desc, site, fk, ins.ref.cls, ins.ref.name, ins.ref.type,
                      resolve_field(w, caller, ins.ref, fk))
        elif rk == "method":
            kind = S.INVOKE_KIND[ins.op]
            yield Row(caller.desc, site, f"invoke-{kind}", ins.ref.cls, ins.ref.name, ins.ref.proto,
                      resolve_method(w, caller, ins.ref, kind))
        elif rk == "call_site":
            cs: S.CallSite = ins.ref
            handles = [cs.bootstrap] + [v for v in cs.extra if isinstance(v, S.MethodHandle)]
            for i, mh in enumerate(handles):
                label, out = resolve_handle(w, caller, mh)
                t = mh.target
                yield Row(caller.desc, site, ("invoke-custom-bootstrap/" if i == 0 else "invoke-custom-arg/") + label,
                          t.cls, t.name, getattr(t, "proto", getattr(t, "type", "")), out)
        elif rk == "method_handle":
            label, out = resolve_handle(w, caller, ins.ref)
            t = ins.ref.target
            yield Row(caller.desc, site, "const-" + label, t.cls, t.name, getattr(t, "proto", getattr(t, "type", "")), out)


def class_checks(w: World, k: Klass) -> list[tuple[str, str, Outcome]]:
    out = []
    if k.cd.superclass:
        s = w.klass(k.cd.superclass)
        if s is None:
            out.append(("superclass", k.cd.superclass, Outcome("CLASS_MISSING", w.missing_detail(k.cd.superclass))))
        elif s.is_interface:
            out.append(("superclass", s.desc, Outcome("ICCE_KIND", "superclass is an interface", s)))
        elif not class_accessible(k, s):
            out.append(("superclass", s.desc, Outcome("ACCESS_VIOLATION", "superclass not accessible", s)))
        else:
            out.append(("superclass", s.desc, Outcome("RESOLVED", "", s)))
    for i in k.cd.interfaces:
        ik = w.klass(i)
        if ik is None:
            out.append(("interface", i, Outcome("CLASS_MISSING", w.missing_detail(i))))
        elif not ik.is_interface:
            out.append(("interface", i, Outcome("ICCE_KIND", "implements a class", ik)))
        else:
            out.append(("interface", i, Outcome("RESOLVED", "", ik)))
    return out


def parse_badging(path: Path) -> list[tuple[str, bool]]:
    libs = []
    for line in path.read_text(errors="replace").splitlines():
        m = re.match(r"^uses-library(-not-required)?:'([^']+)'", line)
        if m:
            libs.append((m.group(2), m.group(1) is None))
    return libs


def sha256(path: Path) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def clean(v) -> str:
    return str(v).replace("\t", " ").replace("\n", " ")


def write_out(final: Path, files: dict[str, str]) -> None:
    final = final.resolve()
    if final.exists() and any(final.iterdir()):
        raise InputError(f"output directory must be empty or absent: {final}")
    tmp = Path(tempfile.mkdtemp(prefix=".n1ib2-"))
    try:
        for name, text in files.items():
            (tmp / name).write_text(text)
        final.parent.mkdir(parents=True, exist_ok=True)
        if final.exists():
            final.rmdir()
        shutil.move(str(tmp), str(final))
    except BaseException:
        shutil.rmtree(tmp, ignore_errors=True)
        raise


def load(path: Path) -> S.DexContainer:
    if not Path(path).is_file():
        raise InputError(f"missing input {path}")
    return S.load_container(Path(path))


def cmd_resolve(a) -> int:
    uses = list(a.uses_library or [])
    parsed = []
    for u in uses:
        m = re.fullmatch(r"([A-Za-z0-9_.-]+):(required|optional)", u)
        if not m:
            raise InputError(f"--uses-library must be NAME:required|optional, got {u!r}")
        parsed.append((m.group(1), m.group(2) == "required"))
    if a.badging:
        parsed += parse_badging(a.badging)
    names = [n for n, _ in parsed]
    if len(set(names)) != len(names):
        raise InputError("a uses-library is declared twice")
    shared = {}
    for s in a.shared_lib or []:
        name, _, paths = s.partition("=")
        if not name or not paths:
            raise InputError(f"--shared-lib must be NAME=PATH[,PATH], got {s!r}")
        shared[name] = [Path(p) for p in paths.split(",")]

    w = World()
    inputs = []
    for p in a.bootclasspath:
        apex = p in (a.apex_jar or []) or "/apex/" in p
        c = load(Path(p))
        w.add(c, "boot", "APEX" if apex else "BOOT")
        inputs.append(("boot-apex" if apex else "boot", p, sha256(Path(p))))
    lib_status = []
    for name, required in parsed:
        if name in shared:
            for p in shared[name]:
                w.add(load(p), f"shared:{name}", f"SHARED_LIB:{name}")
                inputs.append((f"shared:{name}", str(p), sha256(p)))
            lib_status.append((name, "required" if required else "optional", "PROVIDED"))
        else:
            lib_status.append((name, "required" if required else "optional",
                               "UNAVAILABLE_INSTALL_FAILS" if required else "UNAVAILABLE_NOT_LOADED"))
    unused_shared = sorted(set(shared) - set(names))
    if unused_shared:
        raise InputError(f"--shared-lib given for libraries the app does not declare: {unused_shared}")
    app = load(a.app)
    if not app.dexes:
        raise InputError(f"{a.app}: no classes.dex")
    w.add(app, "app", "APP")
    inputs.append(("app", str(a.app), sha256(a.app)))
    for p in a.non_visible or []:
        w.add_hidden(load(Path(p)))
        inputs.append(("non-visible", p, sha256(Path(p))))

    oracle = "NOT_RUN"
    if a.oracle != "none":
        targets = [d for _, d in app.dexes]
        if a.oracle == "all":
            targets = []
            for p in a.bootclasspath:
                targets += [d for _, d in load(Path(p)).dexes]
            targets += [d for _, d in app.dexes]
        for d in targets:
            S.oracle_check_dex(d)            # raises DexError on any disagreement
        oracle = f"PASS({a.oracle}:{len(targets)})"

    rows: dict[tuple, list] = {}
    checks = []
    for entry, dex in app.dexes:
        for cd in dex.classes:
            k = w.klass(cd.descriptor)
            if k is None or k.provider != "APP" or k.cd is not cd:
                continue   # shadowed app copy: ART never runs its code
            for kind, target, out in class_checks(w, k):
                checks.append((k.desc, kind, target, out))
            for m in cd.methods:
                for r in references(w, k, dex, m):
                    key = (r.caller, r.ref_kind, r.owner, r.name, r.desc)
                    if key in rows:
                        rows[key][1] += 1
                    else:
                        rows[key] = [r, 1]

    counts = {x: 0 for x in RESULTS}
    lines = ["caller\tfirst_site\tref_kind\towner\tname\tdescriptor\tresult\tdetail\tresolved_in\tprovider\t"
             "provider_path\tevidence_strength\toccurrences"]
    for key in sorted(rows):
        r, n = rows[key]
        o = r.out
        counts[o.result] += 1
        lines.append("\t".join(clean(x) for x in (
            r.caller, r.site, r.ref_kind, r.owner, r.name or "-", r.desc or "-", o.result, o.detail or "-",
            o.decl.desc if o.decl else "-", o.decl.provider if o.decl else "-", o.decl.path if o.decl else "-",
            "DEX_CALLSITE", n)))
    cl = ["class\tcheck\ttarget\tresult\tdetail\tprovider"]
    for c, kind, t, o in checks:
        counts[o.result] += 1
        cl.append("\t".join(clean(x) for x in (c, kind, t, o.result, o.detail or "-", o.decl.provider if o.decl else "-")))
    shadow = [d for d in w.duplicates if d[2].startswith("APP:")]
    dl = ["class\twinner\tshadowed"] + ["\t".join(clean(x) for x in d) for d in w.duplicates]
    env = [("N1I_B2_MEMBERS_TOOL_VERSION", TOOL_VERSION),
           ("N1I_B2_MEMBERS_SIDE", a.side),
           ("N1I_B2_MEMBERS_APP_SHA256", sha256(a.app)),
           ("N1I_B2_MEMBERS_REFERENCES", str(len(rows))),
           ("N1I_B2_MEMBERS_CLASS_CHECKS", str(len(checks)))]
    env += [(f"N1I_B2_MEMBERS_{x}", str(counts[x])) for x in RESULTS]
    env += [("N1I_B2_MEMBERS_DUPLICATE_CLASSES", str(len(w.duplicates))),
            ("N1I_B2_MEMBERS_APP_CLASSES_SHADOWED", str(len(shadow))),
            ("N1I_B2_MEMBERS_USES_LIBRARIES", ";".join(f"{n}:{r}:{s}" for n, r, s in lib_status) or "NONE"),
            ("N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE",
             ",".join(n for n, r, s in lib_status if s == "UNAVAILABLE_INSTALL_FAILS") or "NONE"),
            ("N1I_B2_MEMBERS_DEXDUMP_ORACLE", oracle),
            ("N1I_B2_MEMBERS_UNRESOLVED", str(sum(v for k, v in counts.items() if k != "RESOLVED"))),
            ("N1I_B2_MEMBERS_DEVICE_CONTACT", "NO")]
    files = {
        "MEMBERS.tsv": "\n".join(lines) + "\n",
        "CLASS_CHECKS.tsv": "\n".join(cl) + "\n",
        "DUPLICATES.tsv": "\n".join(dl) + "\n",
        "INPUTS.tsv": "role\tpath\tsha256\n" + "".join(f"{r}\t{p}\t{h}\n" for r, p, h in inputs),
        "MEMBERS_SUMMARY.env": "".join(f"{k}={clean(v)}\n" for k, v in env),
    }
    write_out(a.out, files)
    print(f"N1I_B2_MEMBERS_SIDE={a.side}")
    print(f"N1I_B2_MEMBERS_UNRESOLVED={dict(env)['N1I_B2_MEMBERS_UNRESOLVED']}")
    print(f"OUTPUT={a.out.resolve()}")
    return 0


def read_members(d: Path) -> tuple[dict, dict]:
    env = dict(l.split("=", 1) for l in (d / "MEMBERS_SUMMARY.env").read_text().splitlines() if "=" in l)
    rows = {}
    lines = (d / "MEMBERS.tsv").read_text().splitlines()
    head = lines[0].split("\t")
    for l in lines[1:]:
        r = dict(zip(head, l.split("\t")))
        rows[(r["caller"], r["ref_kind"], r["owner"], r["name"], r["descriptor"])] = r
    return env, rows


def cmd_compare(a) -> int:
    for d in (a.stock, a.c3a):
        if not (d / "MEMBERS_SUMMARY.env").is_file():
            raise InputError(f"{d}: not a resolve output")
    se, sr = read_members(a.stock)
    ce, cr = read_members(a.c3a)
    if se.get("N1I_B2_MEMBERS_APP_SHA256") != ce.get("N1I_B2_MEMBERS_APP_SHA256"):
        raise InputError("stock and C3A outputs were produced for different app bytes")
    out = ["caller\tref_kind\towner\tname\tdescriptor\tstock_result\tc3a_result\tcomparison\tcandidate_class\t"
           "stock_provider\tc3a_detail"]
    n_gap = n_c3a_only = n_both = 0
    for key in sorted(set(sr) | set(cr)):
        s, c = sr.get(key), cr.get(key)
        sres = s["result"] if s else "NOT_REFERENCED"
        cres = c["result"] if c else "NOT_REFERENCED"
        if sres == "RESOLVED" and cres not in ("RESOLVED", "NOT_REFERENCED"):
            cmp_, cand = "STOCK_ONLY_RESOLVES", "AOSP_EQUIVALENT_WITH_BEHAVIOR_GAP(candidate)"
            n_gap += 1
        elif cres == "RESOLVED" and sres not in ("RESOLVED", "NOT_REFERENCED"):
            cmp_, cand = "C3A_ONLY_RESOLVES", "-"
            n_c3a_only += 1
        elif sres != "RESOLVED" and cres != "RESOLVED":
            cmp_, cand = "UNRESOLVED_ON_BOTH", "-"
            n_both += 1
        else:
            continue
        out.append("\t".join(clean(x) for x in (*key, sres, cres, cmp_, cand,
                                                 s["provider"] if s else "-", c["detail"] if c else "-")))
    env = [("N1I_B2_MEMBERS_COMPARE_APP_SHA256", se["N1I_B2_MEMBERS_APP_SHA256"]),
           ("N1I_B2_AOSP_BEHAVIOR_GAP_CANDIDATE_COUNT", str(n_gap)),
           ("N1I_B2_MEMBERS_C3A_ONLY_RESOLVES_COUNT", str(n_c3a_only)),
           ("N1I_B2_MEMBERS_UNRESOLVED_ON_BOTH_COUNT", str(n_both)),
           ("N1I_B2_MEMBERS_GAP_IS_IMPORT_AUTHORIZATION", "NO"),
           ("N1I_B2_CORE_AOSP_BINARY_IMPORT_AUTHORIZED", "NO")]
    write_out(a.out, {"BEHAVIOR_GAP_CANDIDATES.tsv": "\n".join(out) + "\n",
                      "MEMBERS_COMPARE.env": "".join(f"{k}={v}\n" for k, v in env)})
    print(f"N1I_B2_AOSP_BEHAVIOR_GAP_CANDIDATE_COUNT={n_gap}")
    print(f"OUTPUT={a.out.resolve()}")
    return 0


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("resolve")
    r.add_argument("--side", required=True, choices=("stock", "c3a"))
    r.add_argument("--app", type=Path, required=True)
    r.add_argument("--bootclasspath", action="append", required=True,
                   help="boot classpath jar/dex in BOOTCLASSPATH order (repeatable), APEX fragments included")
    r.add_argument("--apex-jar", action="append", help="mark a --bootclasspath entry as an APEX fragment")
    r.add_argument("--shared-lib", action="append", help="NAME=PATH[,PATH] providing a uses-library on this side")
    r.add_argument("--uses-library", action="append", help="NAME:required|optional declared by the app")
    r.add_argument("--badging", type=Path, help="`aapt2 dump badging` output for uses-library declarations")
    r.add_argument("--non-visible", action="append", help="jar never visible to apps (e.g. services.jar), diagnostics only")
    r.add_argument("--oracle", choices=("app", "all", "none"), default="app",
                   help="cross-check the DEX decoder against dexdump (default: app dexes)")
    r.add_argument("--out", type=Path, required=True)
    c = sub.add_parser("compare")
    c.add_argument("--stock", type=Path, required=True)
    c.add_argument("--c3a", type=Path, required=True)
    c.add_argument("--out", type=Path, required=True)
    a = p.parse_args(argv)
    try:
        return cmd_resolve(a) if a.cmd == "resolve" else cmd_compare(a)
    except (InputError, S.DexError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
