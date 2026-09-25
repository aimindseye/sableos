#!/usr/bin/env python3
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / "product/keyboard-first/titan2.device-profile.json"
VALIDATOR = ROOT / "build/validate_kf1_device_profile.py"

spec = importlib.util.spec_from_file_location("kf1_validator", VALIDATOR)
assert spec and spec.loader
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


def load_profile():
    return json.loads(PROFILE.read_text(encoding="utf-8"))


def by_id(items, wanted):
    return next(item for item in items if item["id"] == wanted)


def test_titan2_profile_valid():
    profile = load_profile()
    assert validator.validate(profile) == []


def test_titan2_evidence_contract():
    profile = load_profile()

    assert profile["device_class"] == "titan2"
    assert profile["interaction_profile"] == "KEYBOARD_FIRST"
    assert profile["support_level"] == "N0_GSI_USERSPACE_LAB"
    assert profile["evidence"]["state"] == "PHYSICALLY_VERIFIED"

    primary = by_id(profile["displays"], "primary-square")
    assert (primary["native_width_px"], primary["native_height_px"]) == (1440, 1440)

    rear = by_id(profile["displays"], "rear-subscreen")
    assert (rear["native_width_px"], rear["native_height_px"]) == (410, 502)
    assert rear["android_display_id_policy"] == "DISCOVER"
    assert "android_display_id" not in rear
    assert rear["touch_association"] == "DYNAMIC_ASSOCIATION"

    keyboard = by_id(profile["input_surfaces"], "titan-keyboard")
    assert keyboard["linux_name"] == "TitanKey"
    assert keyboard["module"] == "aw9523_key"
    assert "PHYSICAL_KEY_MATRIX" in keyboard["capabilities"]

    touch = by_id(profile["input_surfaces"], "keyboard-touch-surface")
    assert touch["linux_name"] == "touchPad"
    assert touch["surface_type"] == "ABSOLUTE_TOUCH_SURFACE"
    assert touch["normalization"] == "RAW_ABS_MT"
    assert "ABSOLUTE_TOUCH" in touch["capabilities"]

    func1 = by_id(profile["input_surfaces"], "func1")
    func2 = by_id(profile["input_surfaces"], "func2")
    assert func1["scan_code"] == 249
    assert func2["scan_code"] == 250
    assert func2["module"] == "gpio_key"

    ff = by_id(profile["input_surfaces"], "fingerprint-gesture-helper")
    assert ff["linux_name"] == "ff_key"
    assert ff["ownership"] == "OPTIONAL_DEVICE_CAPABILITY"

    light = by_id(profile["indicators"], "keyboard-backlight")
    assert light["api_min"] == 0
    assert light["api_max"] == 100
    assert light["effective_min_nonzero"] == 8
    assert light["effective_max"] == 99

    compat = by_id(profile["vendor_compatibility"], "agui-synthetic-key-404")
    assert compat["stock_value"] == 404
    assert compat["sable_exposure"] == "DO_NOT_EXPOSE_AS_COMMON_SEMANTIC"


def test_dynamic_display_id_cannot_be_hardcoded():
    profile = load_profile()
    rear = by_id(profile["displays"], "rear-subscreen")
    rear["android_display_id"] = 2
    errors = validator.validate(profile)
    assert any("must not hard-code android_display_id" in e for e in errors)


def test_raw_vendor_keycode_cannot_be_semantic_default():
    profile = load_profile()
    func1 = by_id(profile["input_surfaces"], "func1")
    func1["semantic_default"] = "KEYCODE_404"
    errors = validator.validate(profile)
    assert any("must be a Sable semantic" in e for e in errors)


if __name__ == "__main__":
    tests = [
        test_titan2_profile_valid,
        test_titan2_evidence_contract,
        test_dynamic_display_id_cannot_be_hardcoded,
        test_raw_vendor_keycode_cannot_be_semantic_default,
    ]
    for fn in tests:
        fn()
        print(f"PASS {fn.__name__}")
    print("KF1_DEVICE_PROFILE_TESTS=PASS")
