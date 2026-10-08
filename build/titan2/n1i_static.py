#!/usr/bin/env python3
"""Titan 2 N1I-B shared static-analysis foundation: DEX and ELF readers.

Design rules
  * Fail closed. Any structural inconsistency raises DexError / ElfError; callers must treat the
    whole input as unanalysable rather than use partial results.
  * Instruction widths come from the Dalvik instruction FORMAT (the leading digit of the format
    id is the width in 16-bit code units), not from a separate width table. The opcode -> format
    table below is checked by the self-test against `dexdump -d` on a compiled corpus plus crafted
    instruction streams, and every defined opcode must be oracle-validated there.
  * Unused opcodes, unknown nop variants, payloads that no switch/fill-array instruction points
    at, and instruction streams that overrun insns_size are errors.
  * Optional runtime oracle: oracle_check_dex() compares this decoder with `dexdump -d` for a
    whole file and raises on any difference (instruction offsets, mnemonics, reference indices).

No device contact, no network. Read-only on inputs.
"""
from __future__ import annotations

import hashlib
import re
import shutil
import struct
import subprocess
import zipfile
import zlib
from dataclasses import dataclass, field
from pathlib import Path

NO_INDEX = 0xFFFFFFFF


class DexError(Exception):
    """Malformed, truncated or unsupported DEX input. Never use partial results."""


class ElfError(Exception):
    """Malformed, truncated or unsupported ELF input. Never use partial results."""


# =============================================================================
# Dalvik opcode table: opcode -> (mnemonic, format, reference kind or None)
# Reference kinds: string type field method call_site method_handle proto
# =============================================================================
def _ops() -> dict[int, tuple[str, str, str | None]]:
    t: dict[int, tuple[str, str, str | None]] = {}

    def put(op, name, fmt, ref=None):
        if op in t:
            raise AssertionError(f"duplicate opcode {op:#x}")
        t[op] = (name, fmt, ref)

    put(0x00, "nop", "10x")
    put(0x01, "move", "12x"); put(0x02, "move/from16", "22x"); put(0x03, "move/16", "32x")
    put(0x04, "move-wide", "12x"); put(0x05, "move-wide/from16", "22x"); put(0x06, "move-wide/16", "32x")
    put(0x07, "move-object", "12x"); put(0x08, "move-object/from16", "22x"); put(0x09, "move-object/16", "32x")
    put(0x0a, "move-result", "11x"); put(0x0b, "move-result-wide", "11x")
    put(0x0c, "move-result-object", "11x"); put(0x0d, "move-exception", "11x")
    put(0x0e, "return-void", "10x"); put(0x0f, "return", "11x")
    put(0x10, "return-wide", "11x"); put(0x11, "return-object", "11x")
    put(0x12, "const/4", "11n"); put(0x13, "const/16", "21s"); put(0x14, "const", "31i")
    put(0x15, "const/high16", "21h"); put(0x16, "const-wide/16", "21s"); put(0x17, "const-wide/32", "31i")
    put(0x18, "const-wide", "51l"); put(0x19, "const-wide/high16", "21h")
    put(0x1a, "const-string", "21c", "string"); put(0x1b, "const-string/jumbo", "31c", "string")
    put(0x1c, "const-class", "21c", "type")
    put(0x1d, "monitor-enter", "11x"); put(0x1e, "monitor-exit", "11x")
    put(0x1f, "check-cast", "21c", "type"); put(0x20, "instance-of", "22c", "type")
    put(0x21, "array-length", "12x"); put(0x22, "new-instance", "21c", "type")
    put(0x23, "new-array", "22c", "type")
    put(0x24, "filled-new-array", "35c", "type"); put(0x25, "filled-new-array/range", "3rc", "type")
    put(0x26, "fill-array-data", "31t"); put(0x27, "throw", "11x")
    put(0x28, "goto", "10t"); put(0x29, "goto/16", "20t"); put(0x2a, "goto/32", "30t")
    put(0x2b, "packed-switch", "31t"); put(0x2c, "sparse-switch", "31t")
    for i, n in enumerate(("cmpl-float", "cmpg-float", "cmpl-double", "cmpg-double", "cmp-long")):
        put(0x2d + i, n, "23x")
    for i, n in enumerate(("if-eq", "if-ne", "if-lt", "if-ge", "if-gt", "if-le")):
        put(0x32 + i, n, "22t")
    for i, n in enumerate(("if-eqz", "if-nez", "if-ltz", "if-gez", "if-gtz", "if-lez")):
        put(0x38 + i, n, "21t")
    sfx = ("", "-wide", "-object", "-boolean", "-byte", "-char", "-short")
    for i, s in enumerate(sfx):
        put(0x44 + i, "aget" + s, "23x"); put(0x4b + i, "aput" + s, "23x")
        put(0x52 + i, "iget" + s, "22c", "field"); put(0x59 + i, "iput" + s, "22c", "field")
        put(0x60 + i, "sget" + s, "21c", "field"); put(0x67 + i, "sput" + s, "21c", "field")
    for i, k in enumerate(("virtual", "super", "direct", "static", "interface")):
        put(0x6e + i, f"invoke-{k}", "35c", "method")
        put(0x74 + i, f"invoke-{k}/range", "3rc", "method")
    unops = ("neg-int", "not-int", "neg-long", "not-long", "neg-float", "neg-double", "int-to-long",
             "int-to-float", "int-to-double", "long-to-int", "long-to-float", "long-to-double", "float-to-int",
             "float-to-long", "float-to-double", "double-to-int", "double-to-long", "double-to-float",
             "int-to-byte", "int-to-char", "int-to-short")
    for i, n in enumerate(unops):
        put(0x7b + i, n, "12x")
    ib = ("add", "sub", "mul", "div", "rem", "and", "or", "xor", "shl", "shr", "ushr")
    fb = ("add", "sub", "mul", "div", "rem")
    binops = ([f"{o}-int" for o in ib] + [f"{o}-long" for o in ib]
              + [f"{o}-float" for o in fb] + [f"{o}-double" for o in fb])
    for i, n in enumerate(binops):
        put(0x90 + i, n, "23x")
        put(0xb0 + i, n + "/2addr", "12x")
    lit16 = ("add-int/lit16", "rsub-int", "mul-int/lit16", "div-int/lit16", "rem-int/lit16",
             "and-int/lit16", "or-int/lit16", "xor-int/lit16")
    for i, n in enumerate(lit16):
        put(0xd0 + i, n, "22s")
    lit8 = ("add-int/lit8", "rsub-int/lit8", "mul-int/lit8", "div-int/lit8", "rem-int/lit8", "and-int/lit8",
            "or-int/lit8", "xor-int/lit8", "shl-int/lit8", "shr-int/lit8", "ushr-int/lit8")
    for i, n in enumerate(lit8):
        put(0xd8 + i, n, "22b")
    put(0xfa, "invoke-polymorphic", "45cc", "method"); put(0xfb, "invoke-polymorphic/range", "4rcc", "method")
    put(0xfc, "invoke-custom", "35c", "call_site"); put(0xfd, "invoke-custom/range", "3rc", "call_site")
    put(0xfe, "const-method-handle", "21c", "method_handle"); put(0xff, "const-method-type", "21c", "proto")
    return t


OPCODES = _ops()
UNUSED_OPCODES = frozenset(range(256)) - set(OPCODES)
FORMATS = {"10x", "12x", "11n", "11x", "10t", "20t", "22x", "21t", "21s", "21h", "21c", "23x", "22b", "22t",
           "22s", "22c", "30t", "32x", "31i", "31t", "31c", "35c", "3rc", "45cc", "4rcc", "51l"}
assert {f for _, f, _ in OPCODES.values()} <= FORMATS


def fmt_width(fmt: str) -> int:
    return int(fmt[0])


INVOKE_KIND = {}
for _op, (_n, _f, _r) in OPCODES.items():
    if _n.startswith("invoke-"):
        INVOKE_KIND[_op] = _n[len("invoke-"):].split("/")[0]   # virtual super direct static interface polymorphic custom
FIELD_KIND = {op: n.split("-")[0] for op, (n, f, r) in OPCODES.items() if r == "field"}  # iget iput sget sput


# =============================================================================
# Byte reader with strict bounds
# =============================================================================
class _R:
    def __init__(self, data: bytes, what: str):
        self.d = data
        self.what = what

    def need(self, off: int, n: int) -> None:
        if off < 0 or n < 0 or off + n > len(self.d):
            raise DexError(f"{self.what}: read {n} bytes at {off:#x} beyond size {len(self.d):#x}")

    def u1(self, off: int) -> int:
        self.need(off, 1); return self.d[off]

    def u2(self, off: int) -> int:
        self.need(off, 2); return struct.unpack_from("<H", self.d, off)[0]

    def u4(self, off: int) -> int:
        self.need(off, 4); return struct.unpack_from("<I", self.d, off)[0]

    def uleb(self, off: int) -> tuple[int, int]:
        val = shift = 0
        for i in range(5):
            b = self.u1(off + i)
            val |= (b & 0x7F) << shift
            shift += 7
            if not b & 0x80:
                if i == 4 and b > 0x0F:
                    raise DexError(f"{self.what}: uleb128 overflow at {off:#x}")
                return val, off + i + 1
        raise DexError(f"{self.what}: uleb128 longer than 5 bytes at {off:#x}")

    def uleb_p1(self, off: int) -> tuple[int, int]:
        v, o = self.uleb(off)
        return v - 1, o

    def sleb(self, off: int) -> tuple[int, int]:
        val = shift = 0
        for i in range(5):
            b = self.u1(off + i)
            val |= (b & 0x7F) << shift
            shift += 7
            if not b & 0x80:
                if b & 0x40:
                    val -= 1 << shift
                return val, off + i + 1
        raise DexError(f"{self.what}: sleb128 longer than 5 bytes at {off:#x}")


def mutf8_decode(data: bytes, off: int, utf16_len: int, what: str) -> tuple[str, int]:
    """Decode a NUL-terminated MUTF-8 string; the UTF-16 length must match utf16_len exactly."""
    units = []
    i = off
    n = len(data)
    while True:
        if i >= n:
            raise DexError(f"{what}: unterminated MUTF-8 string at {off:#x}")
        b = data[i]
        if b == 0:
            i += 1
            break
        if b < 0x80:
            units.append(b); i += 1
        elif 0xC0 <= b <= 0xDF:
            if i + 1 >= n or data[i + 1] & 0xC0 != 0x80:
                raise DexError(f"{what}: bad MUTF-8 2-byte sequence at {i:#x}")
            units.append(((b & 0x1F) << 6) | (data[i + 1] & 0x3F)); i += 2
        elif 0xE0 <= b <= 0xEF:
            if i + 2 >= n or data[i + 1] & 0xC0 != 0x80 or data[i + 2] & 0xC0 != 0x80:
                raise DexError(f"{what}: bad MUTF-8 3-byte sequence at {i:#x}")
            units.append(((b & 0x0F) << 12) | ((data[i + 1] & 0x3F) << 6) | (data[i + 2] & 0x3F)); i += 3
        else:
            raise DexError(f"{what}: invalid MUTF-8 lead byte {b:#x} at {i:#x}")
    if len(units) != utf16_len:
        raise DexError(f"{what}: string at {off:#x} has {len(units)} UTF-16 units, header says {utf16_len}")
    s = "".join(map(chr, units))
    return s.encode("utf-16-le", "surrogatepass").decode("utf-16-le", "surrogatepass"), i


# =============================================================================
# DEX model
# =============================================================================
ACC_PUBLIC, ACC_PRIVATE, ACC_PROTECTED, ACC_STATIC = 0x1, 0x2, 0x4, 0x8
ACC_FINAL, ACC_NATIVE, ACC_INTERFACE, ACC_ABSTRACT = 0x10, 0x100, 0x200, 0x400
ACC_CONSTRUCTOR = 0x10000
SUPPORTED_DEX_VERSIONS = ("035", "037", "038", "039", "040")
MAP_CALL_SITE_ID, MAP_METHOD_HANDLE = 0x0007, 0x0008


@dataclass(frozen=True)
class MethodRef:
    cls: str
    name: str
    proto: str          # "(Args)Ret" descriptor


@dataclass(frozen=True)
class FieldRef:
    cls: str
    name: str
    type: str


@dataclass(frozen=True)
class MethodHandle:
    kind: int           # 0..8 per dex spec
    target: object      # FieldRef (kinds 0-3) or MethodRef (4-8)


@dataclass(frozen=True)
class CallSite:
    bootstrap: MethodHandle
    name: str
    proto: str
    extra: tuple


@dataclass
class Insn:
    offset: int          # code-unit offset within the method
    op: int
    name: str
    fmt: str
    width: int
    regs: tuple = ()     # operand registers in encoding order (vA.. or the range)
    literal: int | None = None
    target: int | None = None     # branch / payload target (code units)
    ref_kind: str | None = None
    ref_index: int | None = None
    ref: object = None            # resolved str / MethodRef / FieldRef / CallSite / MethodHandle
    proto_index: int | None = None  # invoke-polymorphic second reference
    proto: str | None = None


@dataclass
class Payload:
    offset: int
    kind: str            # packed-switch-data | sparse-switch-data | array-data
    width: int


@dataclass
class Code:
    registers: int
    ins: int
    outs: int
    tries: int
    insns_off: int        # file offset of insns
    insns_units: int


@dataclass
class EncodedMethod:
    ref: MethodRef
    index: int
    access: int
    direct: bool
    code: Code | None


@dataclass
class EncodedField:
    ref: FieldRef
    index: int
    access: int
    static: bool


@dataclass
class ClassDef:
    descriptor: str
    access: int
    superclass: str | None
    interfaces: tuple
    source_file: str | None
    static_fields: list = field(default_factory=list)
    instance_fields: list = field(default_factory=list)
    direct_methods: list = field(default_factory=list)
    virtual_methods: list = field(default_factory=list)

    @property
    def methods(self):
        return self.direct_methods + self.virtual_methods

    @property
    def fields(self):
        return self.static_fields + self.instance_fields


class DexFile:
    """A fully parsed, structurally verified DEX file. Construction fails closed."""

    def __init__(self, data: bytes, name: str = "<dex>", verify_hashes: bool = True):
        self.name = name
        self.data = data
        r = self.r = _R(data, name)
        if len(data) < 0x70:
            raise DexError(f"{name}: truncated header ({len(data)} bytes)")
        magic = data[:8]
        if magic[:4] != b"dex\n" or magic[7] != 0:
            raise DexError(f"{name}: bad DEX magic")
        self.version = magic[4:7].decode("ascii", "replace")
        if self.version not in SUPPORTED_DEX_VERSIONS:
            raise DexError(f"{name}: unsupported DEX version {self.version!r} (041 container format not handled)")
        checksum, = struct.unpack_from("<I", data, 8)
        if verify_hashes and zlib.adler32(data[12:]) & 0xFFFFFFFF != checksum:
            raise DexError(f"{name}: adler32 checksum mismatch")
        if verify_hashes and hashlib.sha1(data[32:]).digest() != data[12:32]:
            raise DexError(f"{name}: SHA-1 signature mismatch")
        (file_size, header_size, endian, link_size, link_off, map_off,
         s_size, s_off, t_size, t_off, p_size, p_off, f_size, f_off, m_size, m_off,
         c_size, c_off, d_size, d_off) = struct.unpack_from("<20I", data, 32)
        if file_size != len(data):
            raise DexError(f"{name}: header file_size {file_size} != actual {len(data)}")
        if header_size != 0x70 or endian != 0x12345678:
            raise DexError(f"{name}: unsupported header size/endianness")
        for what, size, off, item in (("string_ids", s_size, s_off, 4), ("type_ids", t_size, t_off, 4),
                                      ("proto_ids", p_size, p_off, 12), ("field_ids", f_size, f_off, 8),
                                      ("method_ids", m_size, m_off, 8), ("class_defs", c_size, c_off, 32)):
            if size:
                r.need(off, size * item)
        if t_size > 0xFFFF or p_size > 0xFFFF:
            raise DexError(f"{name}: type/proto id count exceeds 16-bit index space")

        self.strings = []
        for i in range(s_size):
            so = r.u4(s_off + 4 * i)
            n, o = r.uleb(so)
            s, _ = mutf8_decode(data, o, n, name)
            self.strings.append(s)
        self.types = [self._str(r.u4(t_off + 4 * i)) for i in range(t_size)]
        self.protos = []
        for i in range(p_size):
            base = p_off + 12 * i
            ret = self._type(r.u4(base + 4))
            params = self._type_list(r.u4(base + 8))
            self.protos.append("(" + "".join(params) + ")" + ret)
        self.field_ids = []
        for i in range(f_size):
            base = f_off + 8 * i
            self.field_ids.append(FieldRef(self._type(r.u2(base)), self._str(r.u4(base + 4)), self._type(r.u2(base + 2))))
        self.method_ids = []
        for i in range(m_size):
            base = m_off + 8 * i
            pidx = r.u2(base + 2)
            if pidx >= len(self.protos):
                raise DexError(f"{name}: method_id {i} proto index {pidx} out of range")
            self.method_ids.append(MethodRef(self._type(r.u2(base)), self._str(r.u4(base + 4)), self.protos[pidx]))

        self.method_handles: list[MethodHandle] = []
        self.call_sites: list[CallSite] = []
        mh_items, cs_items = self._map_items(map_off)
        for off, size in mh_items:
            for i in range(size):
                base = off + 8 * i
                kind, idx = r.u2(base), r.u2(base + 4)
                if kind <= 3:
                    tgt = self._field(idx)
                elif kind <= 8:
                    tgt = self._method(idx)
                else:
                    raise DexError(f"{name}: unknown method handle kind {kind}")
                self.method_handles.append(MethodHandle(kind, tgt))
        for off, size in cs_items:
            for i in range(size):
                vals = self._encoded_array(r.u4(off + 4 * i))
                if len(vals) < 3 or not (isinstance(vals[0], MethodHandle) and isinstance(vals[1], str)
                                         and isinstance(vals[2], ProtoValue)):
                    raise DexError(f"{name}: call site {i} has malformed bootstrap triple")
                self.call_sites.append(CallSite(vals[0], vals[1], vals[2].proto, tuple(vals[3:])))

        self.classes: list[ClassDef] = []
        seen = set()
        for i in range(c_size):
            base = c_off + 32 * i
            (cidx, acc, sup, ioff, src, _ann, cdata, _sv) = struct.unpack_from("<8I", data, base)
            desc = self._type(cidx)
            if desc in seen:
                raise DexError(f"{name}: duplicate class_def {desc}")
            seen.add(desc)
            cd = ClassDef(desc, acc, None if sup == NO_INDEX else self._type(sup),
                          tuple(self._type_list(ioff)), None if src == NO_INDEX else self._str(src))
            if cdata:
                self._class_data(cd, cdata)
            self.classes.append(cd)

    # ---- index helpers
    def _str(self, i: int) -> str:
        if i >= len(self.strings):
            raise DexError(f"{self.name}: string index {i} out of range")
        return self.strings[i]

    def _type(self, i: int) -> str:
        if i >= len(self.types):
            raise DexError(f"{self.name}: type index {i} out of range")
        return self.types[i]

    def _field(self, i: int) -> FieldRef:
        if i >= len(self.field_ids):
            raise DexError(f"{self.name}: field index {i} out of range")
        return self.field_ids[i]

    def _method(self, i: int) -> MethodRef:
        if i >= len(self.method_ids):
            raise DexError(f"{self.name}: method index {i} out of range")
        return self.method_ids[i]

    def _type_list(self, off: int) -> list[str]:
        if off == 0:
            return []
        n = self.r.u4(off)
        self.r.need(off + 4, 2 * n)
        return [self._type(self.r.u2(off + 4 + 2 * k)) for k in range(n)]

    def _map_items(self, map_off: int):
        r = self.r
        n = r.u4(map_off)
        r.need(map_off + 4, 12 * n)
        mh, cs = [], []
        for k in range(n):
            base = map_off + 4 + 12 * k
            typ, size, off = r.u2(base), r.u4(base + 4), r.u4(base + 8)
            if typ == MAP_METHOD_HANDLE:
                r.need(off, 8 * size); mh.append((off, size))
            elif typ == MAP_CALL_SITE_ID:
                r.need(off, 4 * size); cs.append((off, size))
        return mh, cs

    # ---- encoded values (call sites need them)
    def _encoded_array(self, off: int) -> list:
        n, o = self.r.uleb(off)
        out = []
        for _ in range(n):
            v, o = self._encoded_value(o)
            out.append(v)
        return out

    def _encoded_value(self, off: int):
        r = self.r
        b = r.u1(off)
        vtype, varg = b & 0x1F, b >> 5
        o = off + 1
        size = varg + 1

        def raw(signed: bool) -> int:
            r.need(o, size)
            return int.from_bytes(self.data[o:o + size], "little", signed=signed)

        if vtype in (0x00, 0x02, 0x03, 0x04, 0x06):          # byte short char int long
            if (vtype == 0x00 and varg != 0) or (vtype in (0x02, 0x03) and varg > 1) or (vtype == 0x04 and varg > 3):
                raise DexError(f"{self.name}: bad encoded value size at {off:#x}")
            return raw(vtype != 0x03), o + size
        if vtype in (0x10, 0x11):                             # float double (right-zero-extended)
            if (vtype == 0x10 and varg > 3):
                raise DexError(f"{self.name}: bad encoded float size at {off:#x}")
            raw(False)
            return ("float" if vtype == 0x10 else "double"), o + size
        if vtype in (0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b):
            if varg > 3:
                raise DexError(f"{self.name}: bad encoded index size at {off:#x}")
            idx = raw(False)
            if vtype == 0x15:
                if idx >= len(self.protos):
                    raise DexError(f"{self.name}: encoded proto index {idx} out of range")
                return ProtoValue(self.protos[idx]), o + size
            if vtype == 0x16:
                if idx >= len(self.method_handles):
                    raise DexError(f"{self.name}: encoded method handle index {idx} out of range "
                                   f"(method handles must precede call sites)")
                return self.method_handles[idx], o + size
            if vtype == 0x17:
                return self._str(idx), o + size
            if vtype == 0x18:
                return TypeValue(self._type(idx)), o + size
            if vtype in (0x19, 0x1b):
                return self._field(idx), o + size
            return self._method(idx), o + size
        if vtype == 0x1c:                                     # array
            if varg:
                raise DexError(f"{self.name}: encoded array with value_arg at {off:#x}")
            n, o = r.uleb(o)
            vals = []
            for _ in range(n):
                v, o = self._encoded_value(o)
                vals.append(v)
            return tuple(vals), o
        if vtype == 0x1d:                                     # annotation
            if varg:
                raise DexError(f"{self.name}: encoded annotation with value_arg at {off:#x}")
            _t, o = r.uleb(o)
            n, o = r.uleb(o)
            for _ in range(n):
                _name, o = r.uleb(o)
                _v, o = self._encoded_value(o)
            return "annotation", o
        if vtype in (0x1e, 0x1f):                             # null, boolean
            if vtype == 0x1e and varg:
                raise DexError(f"{self.name}: encoded null with value_arg at {off:#x}")
            return (None if vtype == 0x1e else bool(varg)), o
        raise DexError(f"{self.name}: unknown encoded value type {vtype:#x} at {off:#x}")

    # ---- class data
    def _class_data(self, cd: ClassDef, off: int) -> None:
        r = self.r
        nsf, o = r.uleb(off)
        nif, o = r.uleb(o)
        ndm, o = r.uleb(o)
        nvm, o = r.uleb(o)
        for count, static, dest in ((nsf, True, cd.static_fields), (nif, False, cd.instance_fields)):
            idx = 0
            for k in range(count):
                diff, o = r.uleb(o)
                acc, o = r.uleb(o)
                if k and diff == 0:
                    raise DexError(f"{self.name}: duplicate field index in {cd.descriptor}")
                idx += diff
                fr = self._field(idx)
                if fr.cls != cd.descriptor:
                    raise DexError(f"{self.name}: field {fr} listed in class_data of {cd.descriptor}")
                if bool(acc & ACC_STATIC) != static:
                    raise DexError(f"{self.name}: field {fr} static flag disagrees with its list")
                dest.append(EncodedField(fr, idx, acc, static))
        for count, direct, dest in ((ndm, True, cd.direct_methods), (nvm, False, cd.virtual_methods)):
            idx = 0
            for k in range(count):
                diff, o = r.uleb(o)
                acc, o = r.uleb(o)
                coff, o = r.uleb(o)
                if k and diff == 0:
                    raise DexError(f"{self.name}: duplicate method index in {cd.descriptor}")
                idx += diff
                mr = self._method(idx)
                if mr.cls != cd.descriptor:
                    raise DexError(f"{self.name}: method {mr} listed in class_data of {cd.descriptor}")
                code = self._code(coff, mr) if coff else None
                if code is None and not acc & (ACC_ABSTRACT | ACC_NATIVE):
                    raise DexError(f"{self.name}: concrete method without code: {mr}")
                if code is not None and acc & (ACC_ABSTRACT | ACC_NATIVE):
                    raise DexError(f"{self.name}: abstract/native method with code: {mr}")
                dest.append(EncodedMethod(mr, idx, acc, direct, code))

    def _code(self, off: int, mr: MethodRef) -> Code:
        r = self.r
        regs, ins, outs, tries = r.u2(off), r.u2(off + 2), r.u2(off + 4), r.u2(off + 6)
        units = r.u4(off + 12)
        r.need(off + 16, 2 * units)
        if ins > regs:
            raise DexError(f"{self.name}: {mr} ins_size {ins} > registers_size {regs}")
        return Code(regs, ins, outs, tries, off + 16, units)


@dataclass(frozen=True)
class ProtoValue:
    proto: str


@dataclass(frozen=True)
class TypeValue:
    descriptor: str


# =============================================================================
# Instruction decoding
# =============================================================================
def _s(v: int, bits: int) -> int:
    return v - (1 << bits) if v & (1 << (bits - 1)) else v


PAYLOAD_FOR = {0x26: "array-data", 0x2b: "packed-switch-data", 0x2c: "sparse-switch-data"}


def decode_code(dex: DexFile, code: Code, where: str = "") -> list:
    """Decode a method body into Insn and Payload items. Fails closed on any inconsistency."""
    n = code.insns_units
    dex.r.need(code.insns_off, 2 * n)
    u = struct.unpack_from(f"<{n}H", dex.data, code.insns_off) if n else ()
    what = f"{dex.name}:{where}"
    out: list = []
    starts: set[int] = set()
    branch_targets: list[tuple[int, int]] = []
    payload_refs: dict[int, str] = {}
    pc = 0

    def unit(i: int) -> int:
        if i >= n:
            raise DexError(f"{what}: instruction at {pc:#x} runs past insns_size {n:#x}")
        return u[i]

    while pc < n:
        w0 = u[pc]
        op, hi = w0 & 0xFF, w0 >> 8
        starts.add(pc)
        if op == 0x00 and hi:
            if pc % 2:
                raise DexError(f"{what}: payload at odd code unit {pc:#x}")
            if hi == 1:
                width = unit(pc + 1) * 2 + 4; kind = "packed-switch-data"
            elif hi == 2:
                width = unit(pc + 1) * 4 + 2; kind = "sparse-switch-data"
            elif hi == 3:
                ew = unit(pc + 1)
                cnt = unit(pc + 2) | (unit(pc + 3) << 16)
                if ew not in (1, 2, 4, 8):
                    raise DexError(f"{what}: array-data element width {ew} invalid")
                width = (cnt * ew + 1) // 2 + 4; kind = "array-data"
            else:
                raise DexError(f"{what}: unknown nop/payload ident {w0:#06x} at {pc:#x}")
            unit(pc + width - 1)
            out.append(Payload(pc, kind, width))
            pc += width
            continue
        if op in UNUSED_OPCODES:
            raise DexError(f"{what}: unused opcode {op:#04x} at {pc:#x}")
        name, fmt, refk = OPCODES[op]
        width = fmt_width(fmt)
        unit(pc + width - 1)
        ins = Insn(pc, op, name, fmt, width)
        A4, B4 = hi & 0xF, hi >> 4
        u1 = u[pc + 1] if width > 1 else 0
        u2 = u[pc + 2] if width > 2 else 0
        if fmt == "10x":
            pass
        elif fmt == "12x":
            ins.regs = (A4, B4)
        elif fmt == "11n":
            ins.regs = (A4,); ins.literal = _s(B4, 4)
        elif fmt == "11x":
            ins.regs = (hi,)
        elif fmt == "10t":
            ins.target = pc + _s(hi, 8)
        elif fmt == "20t":
            ins.target = pc + _s(u1, 16)
        elif fmt == "22x":
            ins.regs = (hi, u1)
        elif fmt == "21t":
            ins.regs = (hi,); ins.target = pc + _s(u1, 16)
        elif fmt == "21s":
            ins.regs = (hi,); ins.literal = _s(u1, 16)
        elif fmt == "21h":
            ins.regs = (hi,); ins.literal = _s(u1, 16) << (48 if op == 0x19 else 16)
        elif fmt == "21c":
            ins.regs = (hi,); ins.ref_index = u1
        elif fmt == "23x":
            ins.regs = (hi, u1 & 0xFF, u1 >> 8)
        elif fmt == "22b":
            ins.regs = (hi, u1 & 0xFF); ins.literal = _s(u1 >> 8, 8)
        elif fmt == "22t":
            ins.regs = (A4, B4); ins.target = pc + _s(u1, 16)
        elif fmt == "22s":
            ins.regs = (A4, B4); ins.literal = _s(u1, 16)
        elif fmt == "22c":
            ins.regs = (A4, B4); ins.ref_index = u1
        elif fmt == "30t":
            ins.target = pc + _s(u1 | (u2 << 16), 32)
        elif fmt == "32x":
            ins.regs = (u1, u2)
        elif fmt == "31i":
            ins.regs = (hi,); ins.literal = _s(u1 | (u2 << 16), 32)
        elif fmt == "31t":
            ins.regs = (hi,); ins.target = pc + _s(u1 | (u2 << 16), 32)
        elif fmt == "31c":
            ins.regs = (hi,); ins.ref_index = u1 | (u2 << 16)
        elif fmt in ("35c", "45cc"):
            count, g = hi >> 4, hi & 0xF
            if count > 5:
                raise DexError(f"{what}: {name} with {count} registers at {pc:#x}")
            ins.regs = tuple([u2 & 0xF, (u2 >> 4) & 0xF, (u2 >> 8) & 0xF, u2 >> 12, g][:count])
            ins.ref_index = u1
            if fmt == "45cc":
                ins.proto_index = u[pc + 3]
        elif fmt in ("3rc", "4rcc"):
            ins.regs = tuple(range(u2, u2 + hi)); ins.ref_index = u1
            if fmt == "4rcc":
                ins.proto_index = u[pc + 3]
        elif fmt == "51l":
            v = u1 | (u2 << 16) | (u[pc + 3] << 32) | (u[pc + 4] << 48)
            ins.regs = (hi,); ins.literal = _s(v, 64)
        else:  # pragma: no cover - table is checked against FORMATS
            raise DexError(f"{what}: unhandled format {fmt}")
        if refk is not None:
            ins.ref_kind = refk
            ins.ref = _resolve(dex, refk, ins.ref_index, what, pc)
        if ins.proto_index is not None:
            if ins.proto_index >= len(dex.protos):
                raise DexError(f"{what}: proto index {ins.proto_index} out of range at {pc:#x}")
            ins.proto = dex.protos[ins.proto_index]
        if ins.target is not None:
            if op in PAYLOAD_FOR:
                payload_refs[ins.target] = PAYLOAD_FOR[op]
            else:
                branch_targets.append((pc, ins.target))
        out.append(ins)
        pc += width
    if pc != n:
        raise DexError(f"{what}: decoded {pc:#x} units, insns_size is {n:#x}")
    payloads = {p.offset: p.kind for p in out if isinstance(p, Payload)}
    if payloads != payload_refs:
        raise DexError(f"{what}: payload/reference mismatch {sorted(payloads.items())} vs {sorted(payload_refs.items())}")
    insn_starts = {i.offset for i in out if isinstance(i, Insn)}
    for src, tgt in branch_targets:
        if tgt not in insn_starts:
            raise DexError(f"{what}: branch at {src:#x} targets {tgt:#x}, not an instruction start")
    return out


def _resolve(dex: DexFile, kind: str, idx: int, what: str, pc: int):
    tables = {"string": dex.strings, "type": dex.types, "field": dex.field_ids, "method": dex.method_ids,
              "call_site": dex.call_sites, "method_handle": dex.method_handles, "proto": dex.protos}
    tab = tables[kind]
    if idx >= len(tab):
        raise DexError(f"{what}: {kind} index {idx} out of range ({len(tab)}) at {pc:#x}")
    return tab[idx]


def instructions(dex: DexFile, m: EncodedMethod) -> list[Insn]:
    if m.code is None:
        return []
    return [i for i in decode_code(dex, m.code, f"{m.ref.cls}->{m.ref.name}{m.ref.proto}") if isinstance(i, Insn)]


# =============================================================================
# Containers (APK / JAR / bare DEX) and multidex order
# =============================================================================
MAX_DEX_BYTES = 256 << 20


@dataclass
class DexContainer:
    path: str
    dexes: list            # [(entry_name, DexFile)] in ART load order
    ignored_entries: list  # dex-looking entries ART would not load as primary code


def multidex_names(names: list[str]) -> tuple[list[str], list[str]]:
    """ART order: classes.dex, classes2.dex, classes3.dex ... stopping at the first gap."""
    order = []
    if "classes.dex" in names:
        order.append("classes.dex")
        k = 2
        while f"classes{k}.dex" in names:
            order.append(f"classes{k}.dex")
            k += 1
    ignored = sorted(n for n in names if n.endswith(".dex") and n not in order)
    return order, ignored


def load_container(path: Path, verify_hashes: bool = True) -> DexContainer:
    path = Path(path)
    data = path.read_bytes()
    if data[:4] == b"dex\n":
        return DexContainer(str(path), [(path.name, DexFile(data, path.name, verify_hashes))], [])
    if not zipfile.is_zipfile(path):
        raise DexError(f"{path}: neither DEX nor ZIP")
    try:
        with zipfile.ZipFile(path) as z:
            infos = {i.filename: i for i in z.infolist()}
            order, ignored = multidex_names(list(infos))
            dexes = []
            for name in order:
                if infos[name].file_size > MAX_DEX_BYTES:
                    raise DexError(f"{path}!{name}: entry too large")
                dexes.append((name, DexFile(z.read(name), f"{path.name}!{name}", verify_hashes)))
    except (zipfile.BadZipFile, zlib.error, EOFError) as e:
        raise DexError(f"{path}: corrupt zip: {e}") from e
    return DexContainer(str(path), dexes, ignored)


def class_table(containers: list[DexContainer]) -> tuple[dict, list]:
    """First-definition-wins class map across containers in the given order, plus duplicates.
    The caller decides container order (boot classpath before app: parent-first delegation)."""
    table: dict[str, tuple[DexContainer, str, DexFile, ClassDef]] = {}
    dups = []
    for c in containers:
        for entry, dex in c.dexes:
            for cd in dex.classes:
                if cd.descriptor in table:
                    first = table[cd.descriptor]
                    dups.append((cd.descriptor, f"{first[0].path}!{first[1]}", f"{c.path}!{entry}"))
                else:
                    table[cd.descriptor] = (c, entry, dex, cd)
    return table, dups


# =============================================================================
# dexdump oracle (independent decoder from the Android tree)
# =============================================================================
_DD_INSN = re.compile(r"^([0-9a-f]{6}): [0-9a-f .]*\|([0-9a-f]{4,}): (.*)$")
_DD_REFS_TAIL = re.compile(r"//\s+((?:[a-z_]+@[0-9a-f]+)(?:,\s*[a-z_]+@[0-9a-f]+)*)\s*$")
_DD_REF = re.compile(r"([a-z_]+)@([0-9a-f]+)")
_DD_BARE_REF = re.compile(r",\s*((?:call_site|method_handle|proto)@[0-9a-f]+)\s*$")
_DD_PAYLOAD = re.compile(r"^(packed-switch-data|sparse-switch-data|array-data) \((\d+) units\)")



def _dd_regs(mnem: str, ops: str) -> tuple:
    """Register operands as dexdump prints them (braces for invoke/filled-new-array lists)."""
    if ops.startswith("{"):
        inner = ops[1:ops.index("}")] if "}" in ops else ""
        m = re.fullmatch(r"\s*v(\d+)\s*\.\.\s*v(\d+)\s*", inner)
        if m:
            return tuple(range(int(m.group(1)), int(m.group(2)) + 1))
        return tuple(int(x) for x in re.findall(r"v(\d+)", inner))
    if mnem.startswith("const-string"):
        ops = ops.split(", \"", 1)[0]
    elif "//" in ops:
        ops = ops.split("//", 1)[0]
    out = []
    for tok in ops.split(","):
        tok = tok.strip()
        if re.fullmatch(r"v\d+", tok):
            out.append(int(tok[1:]))
        else:
            break
    return tuple(out)


def parse_dexdump(text: str) -> dict:
    """Parse `dexdump -d` output into {class: {...}}. Raises DexError on unexpected structure."""
    classes: dict = {}
    cls = None
    section = None
    member = None
    method_key = None

    def close_member():
        nonlocal member
        if member is not None and cls is not None:
            classes[cls][section].append(member)
        member = None

    # Split on LF only. str.splitlines() also breaks at \v \f \x1c-\x1e U+0085 U+2028 U+2029, which
    # dexdump prints unescaped inside const-string literals; that cut the "// string@" reference tail.
    for line in text.split("\n"):
        m = _DD_INSN.match(line)
        if m:
            if member is None or "insns" not in member:
                raise DexError(f"dexdump: instruction outside a method body: {line[:80]}")
            off, rest = int(m.group(2), 16), m.group(3)
            pm = _DD_PAYLOAD.match(rest)
            if pm:
                member["insns"].append((off, pm.group(1), (), int(pm.group(2)), ()))
                continue
            mnem = rest.split(" ", 1)[0]
            regs = _dd_regs(mnem, rest[len(mnem):].strip())
            refs = ()
            tail = _DD_REFS_TAIL.search(rest)
            if tail:
                refs = tuple((k, int(v, 16)) for k, v in _DD_REF.findall(tail.group(1)))
            else:
                bare = _DD_BARE_REF.search(rest)
                if bare:
                    refs = tuple((k, int(v, 16)) for k, v in _DD_REF.findall(bare.group(1)))
            member["insns"].append((off, mnem, refs, None, regs))
            continue
        s = line.strip()
        if line.startswith("Class #"):
            close_member()
            cls, section = None, None
            continue
        if s.startswith("Class descriptor"):
            cls = s.split(":", 1)[1].strip().strip("'")
            if cls in classes:
                raise DexError(f"dexdump: class {cls} listed twice")
            classes[cls] = {"access": None, "super": None, "interfaces": [], "static": [], "instance": [],
                            "direct": [], "virtual": []}
            continue
        if cls is None:
            continue
        if s.startswith("Access flags"):
            classes[cls]["access"] = int(s.split(":", 1)[1].split()[0], 16)
        elif s.startswith("Superclass"):
            v = s.split(":", 1)[1].strip()
            classes[cls]["super"] = v.strip("'") if v.startswith("'") else None
        elif s.startswith(("Interfaces", "Static fields", "Instance fields", "Direct methods", "Virtual methods")):
            close_member()
            section = {"Interfaces": "interfaces", "Static": "static", "Instance": "instance",
                       "Direct": "direct", "Virtual": "virtual"}[s.split()[0]]
        elif s.startswith("source_file_idx"):
            close_member()
            section = None
        elif s.startswith("#") and section == "interfaces":
            classes[cls]["interfaces"].append(s.split(":", 1)[1].strip().strip("'"))
        elif s.startswith("#") and section in ("static", "instance", "direct", "virtual"):
            close_member()
            member = {}
        elif member is not None and s.startswith("name") and ":" in s:
            member["name"] = s.split(":", 1)[1].strip().strip("'")
        elif member is not None and s.startswith("type") and ":" in s:
            member["type"] = s.split(":", 1)[1].strip().strip("'")
        elif member is not None and s.startswith("access") and ":" in s:
            member["access"] = int(s.split(":", 1)[1].split()[0], 16)
        elif member is not None and s.startswith("code"):
            member["code"] = not s.endswith("(none)")
            if member["code"]:
                member["insns"] = []
        elif member is not None and s.startswith("insns size"):
            member["units"] = int(s.split(":", 1)[1].split()[0])
    close_member()
    return classes


def dex_model(dex: DexFile) -> dict:
    """The same shape as parse_dexdump(), produced by this module's own parser/decoder."""
    out = {}
    for cd in dex.classes:
        c = {"access": cd.access, "super": cd.superclass, "interfaces": list(cd.interfaces),
             "static": [], "instance": [], "direct": [], "virtual": []}
        for sec, fl in (("static", cd.static_fields), ("instance", cd.instance_fields)):
            c[sec] = [{"name": f.ref.name, "type": f.ref.type, "access": f.access} for f in fl]
        for sec, ml in (("direct", cd.direct_methods), ("virtual", cd.virtual_methods)):
            for m in ml:
                d = {"name": m.ref.name, "type": m.ref.proto, "access": m.access, "code": m.code is not None}
                if m.code is not None:
                    d["units"] = m.code.insns_units
                    items = []
                    for it in decode_code(dex, m.code, f"{cd.descriptor}->{m.ref.name}{m.ref.proto}"):
                        if isinstance(it, Payload):
                            items.append((it.offset, it.kind, (), it.width, ()))
                        else:
                            refs = ()
                            if it.ref_kind is not None:
                                refs = ((it.ref_kind, it.ref_index),)
                            if it.proto_index is not None:
                                refs += (("proto", it.proto_index),)
                            items.append((it.offset, it.name, refs, None, tuple(it.regs)))
                    d["insns"] = items
                c[sec].append(d)
        out[cd.descriptor] = c
    return out


def compare_models(ours: dict, oracle: dict, limit: int = 20) -> list[str]:
    diffs = []
    if set(ours) != set(oracle):
        diffs.append(f"class sets differ: only_ours={sorted(set(ours) - set(oracle))[:5]} "
                     f"only_oracle={sorted(set(oracle) - set(ours))[:5]}")
    for c in sorted(set(ours) & set(oracle)):
        a, b = ours[c], oracle[c]
        for k in ("access", "super", "interfaces"):
            if a[k] != b[k]:
                diffs.append(f"{c}: {k} ours={a[k]!r} oracle={b[k]!r}")
        for sec in ("static", "instance", "direct", "virtual"):
            if len(a[sec]) != len(b[sec]):
                diffs.append(f"{c}: {sec} count ours={len(a[sec])} oracle={len(b[sec])}")
                continue
            for x, y in zip(a[sec], b[sec]):
                for k in ("name", "type", "access", "code", "units"):
                    if x.get(k) != y.get(k):
                        diffs.append(f"{c}.{x.get('name')}: {k} ours={x.get(k)!r} oracle={y.get(k)!r}")
                if x.get("insns") != y.get("insns"):
                    xi, yi = x.get("insns") or [], y.get("insns") or []
                    first = next((i for i, (p, q) in enumerate(zip(xi, yi)) if p != q), min(len(xi), len(yi)))
                    diffs.append(f"{c}.{x.get('name')}{x.get('type')}: insn #{first} ours="
                                 f"{xi[first] if first < len(xi) else None} oracle={yi[first] if first < len(yi) else None}")
        if len(diffs) >= limit:
            break
    return diffs


def run_dexdump(dex_bytes: bytes, dexdump: str | None = None, timeout: int = 600) -> str:
    exe = dexdump or shutil.which("dexdump")
    if not exe:
        raise DexError("dexdump oracle not available")
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".dex") as tf:
        tf.write(dex_bytes)
        tf.flush()
        p = subprocess.run([exe, "-d", tf.name], capture_output=True, text=True, errors="replace", timeout=timeout)
    if p.returncode != 0:
        raise DexError(f"dexdump failed rc={p.returncode}: {p.stderr.strip()[:200]}")
    return p.stdout


def oracle_check_dex(dex: DexFile, dexdump: str | None = None) -> dict:
    """Compare this decoder with dexdump for one DEX. Raises DexError on any difference."""
    oracle = parse_dexdump(run_dexdump(dex.data, dexdump))
    ours = dex_model(dex)
    diffs = compare_models(ours, oracle)
    if diffs:
        raise DexError(f"{dex.name}: decoder disagrees with dexdump: " + " | ".join(diffs[:5]))
    insns = sum(len(m.get("insns", [])) for c in ours.values() for s in ("direct", "virtual") for m in c[s])
    ops = {OPCODE_BY_NAME[i[1]] for c in ours.values() for s in ("direct", "virtual") for m in c[s]
           for i in m.get("insns", []) if i[1] in OPCODE_BY_NAME}
    return {"classes": len(ours), "instructions": insns, "opcodes": ops}


OPCODE_BY_NAME = {n: op for op, (n, _, _) in OPCODES.items()}


# =============================================================================
# ELF (shared objects): DT_NEEDED, SONAME, dynamic symbols, JNI evidence
# =============================================================================
PT_LOAD, PT_DYNAMIC = 1, 2
SHT_DYNSYM = 11
DT_NULL, DT_NEEDED, DT_HASH, DT_STRTAB, DT_SYMTAB, DT_STRSZ, DT_SYMENT = 0, 1, 4, 5, 6, 10, 11
DT_SONAME, DT_GNU_HASH = 14, 0x6FFFFEF5
STB_GLOBAL, STB_WEAK, STB_GNU_UNIQUE = 1, 2, 10
STT_FUNC, STT_OBJECT, STT_GNU_IFUNC = 2, 1, 10
EM_NAMES = {3: "x86", 40: "arm", 62: "x86_64", 183: "aarch64", 243: "riscv"}


@dataclass(frozen=True)
class ElfSymbol:
    name: str
    defined: bool
    bind: int
    type: int
    visibility: int


@dataclass
class ElfInfo:
    path: str
    elf_class: int          # 32 or 64
    machine: str
    soname: str | None
    needed: tuple
    symbols: tuple          # ElfSymbol, dynamic symbol table order
    symbol_source: str      # SECTION_DYNSYM | DT_HASH | DT_GNU_HASH

    @property
    def exports(self) -> list[str]:
        return [s.name for s in self.symbols if s.defined and s.name and s.bind in (STB_GLOBAL, STB_WEAK, STB_GNU_UNIQUE)
                and s.visibility in (0, 3)]

    @property
    def imports(self) -> list[str]:
        return [s.name for s in self.symbols if not s.defined and s.name]


class _E:
    def __init__(self, data: bytes, what: str, is64: bool):
        self.d, self.what, self.is64 = data, what, is64

    def need(self, off: int, n: int) -> None:
        if off < 0 or n < 0 or off + n > len(self.d):
            raise ElfError(f"{self.what}: read {n} bytes at {off:#x} beyond size {len(self.d):#x}")

    def unpack(self, fmt: str, off: int):
        self.need(off, struct.calcsize(fmt))
        return struct.unpack_from(fmt, self.d, off)

    def cstr(self, off: int, limit: int | None = None) -> str:
        self.need(off, 1)
        end = self.d.find(b"\0", off, limit if limit is not None else len(self.d))
        if end < 0:
            raise ElfError(f"{self.what}: unterminated string at {off:#x}")
        return self.d[off:end].decode("utf-8", "replace")


def parse_elf(data: bytes, what: str = "<elf>") -> ElfInfo:
    if len(data) < 16 or data[:4] != b"\x7fELF":
        raise ElfError(f"{what}: not an ELF file")
    ei_class, ei_data = data[4], data[5]
    if ei_class not in (1, 2):
        raise ElfError(f"{what}: bad ELF class {ei_class}")
    if ei_data != 1:
        raise ElfError(f"{what}: only little-endian ELF is supported")
    is64 = ei_class == 2
    e = _E(data, what, is64)
    if is64:
        (_t, mach, _v, _entry, phoff, shoff, _fl, _eh, phentsize, phnum, shentsize, shnum, shstrndx) = \
            e.unpack("<HHIQQQIHHHHHH", 16)
    else:
        (_t, mach, _v, _entry, phoff, shoff, _fl, _eh, phentsize, phnum, shentsize, shnum, shstrndx) = \
            e.unpack("<HHIIIIIHHHHHH", 16)
    if phnum and phentsize != (56 if is64 else 32):
        raise ElfError(f"{what}: unexpected program header size {phentsize}")
    loads, dyn = [], None
    for i in range(phnum):
        off = phoff + i * phentsize
        if is64:
            p_type, _pf, p_off, p_vaddr, _pa, p_filesz, _pm, _al = e.unpack("<IIQQQQQQ", off)
        else:
            p_type, p_off, p_vaddr, _pa, p_filesz, _pm, _pf, _al = e.unpack("<IIIIIIII", off)
        if p_type == PT_LOAD:
            loads.append((p_vaddr, p_off, p_filesz))
        elif p_type == PT_DYNAMIC:
            if dyn is not None:
                raise ElfError(f"{what}: more than one PT_DYNAMIC")
            dyn = (p_off, p_filesz)
    if dyn is None:
        raise ElfError(f"{what}: no PT_DYNAMIC (not a dynamically linked object)")

    def v2o(vaddr: int) -> int:
        for va, fo, sz in loads:
            if va <= vaddr < va + sz:
                return fo + (vaddr - va)
        raise ElfError(f"{what}: address {vaddr:#x} not in any PT_LOAD segment")

    ent = 16 if is64 else 8
    tags: dict[int, list[int]] = {}
    off, end = dyn[0], dyn[0] + dyn[1]
    e.need(dyn[0], dyn[1])
    terminated = False
    while off + ent <= end:
        tag, val = e.unpack("<qQ" if is64 else "<iI", off)
        off += ent
        if tag == DT_NULL:
            terminated = True
            break
        tags.setdefault(tag, []).append(val)
    if not terminated:
        raise ElfError(f"{what}: dynamic section not DT_NULL terminated")
    for t in (DT_STRTAB, DT_SYMTAB, DT_STRSZ):
        if len(tags.get(t, [])) != 1:
            raise ElfError(f"{what}: dynamic tag {t} missing or repeated")
    strtab, strsz = v2o(tags[DT_STRTAB][0]), tags[DT_STRSZ][0]
    e.need(strtab, strsz)

    def dstr(o: int) -> str:
        if o >= strsz:
            raise ElfError(f"{what}: dynstr offset {o:#x} beyond DT_STRSZ")
        return e.cstr(strtab + o, strtab + strsz)

    needed = tuple(dstr(v) for v in tags.get(DT_NEEDED, []))
    soname = dstr(tags[DT_SONAME][0]) if DT_SONAME in tags else None

    syment = 24 if is64 else 16
    if tags.get(DT_SYMENT, [syment])[0] != syment:
        raise ElfError(f"{what}: unexpected DT_SYMENT")
    symtab = v2o(tags[DT_SYMTAB][0])
    nsyms, source = None, None
    # Prefer the section header table when present and consistent; fall back to hash tables.
    if shoff and shnum:
        if shentsize != (64 if is64 else 40):
            raise ElfError(f"{what}: unexpected section header size {shentsize}")
        for i in range(shnum):
            so = shoff + i * shentsize
            if is64:
                _n, sh_type, _f, _a, sh_off, sh_size, _l, _i, _al, sh_ent = e.unpack("<IIQQQQIIQQ", so)
            else:
                _n, sh_type, _f, _a, sh_off, sh_size, _l, _i, _al, sh_ent = e.unpack("<IIIIIIIIII", so)
            if sh_type == SHT_DYNSYM:
                if sh_off != symtab:
                    raise ElfError(f"{what}: .dynsym offset disagrees with DT_SYMTAB")
                if sh_ent != syment or sh_size % syment:
                    raise ElfError(f"{what}: bad .dynsym entry size")
                nsyms, source = sh_size // syment, "SECTION_DYNSYM"
    if nsyms is None and DT_HASH in tags:
        h = v2o(tags[DT_HASH][0])
        _nbucket, nchain = e.unpack("<II", h)
        nsyms, source = nchain, "DT_HASH"
    if nsyms is None and DT_GNU_HASH in tags:
        nsyms, source = _gnu_hash_count(e, v2o(tags[DT_GNU_HASH][0]), is64), "DT_GNU_HASH"
    if nsyms is None:
        raise ElfError(f"{what}: cannot determine dynamic symbol count")
    e.need(symtab, nsyms * syment)
    syms = []
    for i in range(nsyms):
        so = symtab + i * syment
        if is64:
            st_name, st_info, st_other, st_shndx, _v, _s = e.unpack("<IBBHQQ", so)
        else:
            st_name, _v, _s, st_info, st_other, st_shndx = e.unpack("<IIIBBH", so)
        syms.append(ElfSymbol(dstr(st_name) if st_name else "", st_shndx != 0, st_info >> 4, st_info & 0xF,
                              st_other & 3))
    return ElfInfo(what, 64 if is64 else 32, EM_NAMES.get(mach, str(mach)), soname, needed, tuple(syms), source)


def _gnu_hash_count(e: _E, off: int, is64: bool) -> int:
    nbuckets, symoffset, bloom_size, _shift = e.unpack("<IIII", off)
    word = 8 if is64 else 4
    buckets_off = off + 16 + bloom_size * word
    e.need(buckets_off, 4 * nbuckets)
    buckets = struct.unpack_from(f"<{nbuckets}I", e.d, buckets_off)
    chains_off = buckets_off + 4 * nbuckets
    last = max(buckets) if buckets else 0
    if last < symoffset:
        return symoffset
    i = last
    while True:
        (h,) = e.unpack("<I", chains_off + 4 * (i - symoffset))
        if h & 1:
            return i + 1
        i += 1


def load_elf(path: Path) -> ElfInfo:
    return parse_elf(Path(path).read_bytes(), str(path))


# ---- JNI evidence ---------------------------------------------------------
def jni_demangle(symbol: str) -> tuple[str, str, str | None] | None:
    """Java_<class>_<method>[__<signature>] -> (class descriptor, method, signature or None).
    Returns None for names that are not valid JNI short/long names (fail closed)."""
    if not symbol.startswith("Java_"):
        return None
    s = symbol[5:]
    parts, cur, i = [], [], 0
    sig = None
    while i < len(s):
        ch = s[i]
        if ch == "_":
            nxt = s[i + 1] if i + 1 < len(s) else ""
            if nxt == "1":
                cur.append("_"); i += 2; continue
            if nxt == "2":
                cur.append(";"); i += 2; continue
            if nxt == "3":
                cur.append("["); i += 2; continue
            if nxt == "0":
                hexs = s[i + 2:i + 6]
                if len(hexs) != 4 or not re.fullmatch(r"[0-9a-f]{4}", hexs):
                    return None
                cur.append(chr(int(hexs, 16))); i += 6; continue
            if nxt == "_":
                parts.append("".join(cur)); cur = []
                sig = _jni_sig_demangle(s[i + 2:])
                if sig is None:
                    return None
                break
            parts.append("".join(cur)); cur = []; i += 1; continue
        if not (ch.isalnum() and ch.isascii()):
            return None
        cur.append(ch); i += 1
    else:
        parts.append("".join(cur))
    if len(parts) < 2 or any(p == "" for p in parts):
        return None
    return "L" + "/".join(parts[:-1]) + ";", parts[-1], sig


def _jni_sig_demangle(s: str) -> str | None:
    out, i = [], 0
    while i < len(s):
        ch = s[i]
        if ch == "_":
            nxt = s[i + 1] if i + 1 < len(s) else ""
            if nxt in "123":
                out.append({"1": "_", "2": ";", "3": "["}[nxt]); i += 2; continue
            if nxt == "0" and re.fullmatch(r"[0-9a-f]{4}", s[i + 2:i + 6] or ""):
                out.append(chr(int(s[i + 2:i + 6], 16))); i += 6; continue
            out.append("/"); i += 1; continue
        if not (ch.isalnum() and ch.isascii()):
            return None
        out.append(ch); i += 1
    return "(" + "".join(out) + ")"


_PRINTABLE_RUN = re.compile(rb"[\x20-\x7e]{4,}")
_JNI_SIG = re.compile(r"^\((?:\[*(?:[ZBCSIJFD]|L[A-Za-z0-9_$/]+;))*\)\[*(?:[ZBCSIJFDV]|L[A-Za-z0-9_$/]+;)$")
_JNI_CLASS = re.compile(r"^(?:[a-z][a-z0-9_]*/)+[A-Za-z_$][A-Za-z0-9_$]*$")


def jni_evidence(info: ElfInfo, data: bytes) -> dict:
    """Separate confirmed export evidence from string-only candidates.
      exported_java: Java_* exports, demangled (ELF_REFERENCE strength)
      has_jni_onload: JNI_OnLoad exported (dynamic registration is possible, nothing more)
      registernatives_candidates: class-name and JNI-signature strings (STRING_ONLY, never proof)"""
    exported = []
    for name in info.exports:
        if name.startswith("Java_"):
            dm = jni_demangle(name)
            exported.append((name, dm))
    strings = {m.group().decode() for m in _PRINTABLE_RUN.finditer(data)}
    classes = sorted(s for s in strings if _JNI_CLASS.match(s))
    sigs = sorted(s for s in strings if _JNI_SIG.match(s))
    return {
        "exported_java": exported,
        "has_jni_onload": "JNI_OnLoad" in info.exports,
        "registernatives_candidates": {"class_strings": classes, "signature_strings": sigs,
                                       "evidence_strength": "STRING_ONLY"},
    }


# ---- readelf oracle -------------------------------------------------------
def readelf_oracle(path: Path, readelf: str | None = None) -> dict:
    exe = readelf or shutil.which("readelf") or shutil.which("llvm-readelf")
    if not exe:
        raise ElfError("readelf oracle not available")
    d = subprocess.run([exe, "-d", "-W", str(path)], capture_output=True, text=True, timeout=120)
    s = subprocess.run([exe, "--dyn-syms", "-W", str(path)], capture_output=True, text=True, timeout=120)
    if d.returncode or s.returncode:
        raise ElfError(f"readelf failed on {path}")
    needed = tuple(re.findall(r"\(NEEDED\)\s+Shared library: \[([^\]]+)\]", d.stdout))
    so = re.findall(r"\(SONAME\)\s+Library soname: \[([^\]]+)\]", d.stdout)
    syms = []
    for line in s.stdout.split("\n"):  # LF only; see parse_dexdump()
        m = re.match(r"\s*\d+:\s+[0-9a-f]+\s+\S+\s+(\w+)\s+(\w+)\s+(\w+)\s+(\S+)\s*(\S*)", line)
        if m:
            typ, bind, vis, ndx, name = m.groups()
            syms.append((name.split("@")[0], ndx != "UND", bind, vis))
    return {"needed": needed, "soname": so[0] if so else None, "symbols": syms}
