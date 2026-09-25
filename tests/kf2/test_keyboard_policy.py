#!/usr/bin/env python3
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / "product/keyboard-first/titan2.device-profile.json"
POLICY = ROOT / "product/keyboard-first/titan2.keyboard-policy.json"
VALIDATOR = ROOT / "build/validate_kf2_keyboard_policy.py"

spec = importlib.util.spec_from_file_location("kf2_validator", VALIDATOR)
assert spec and spec.loader
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


def load_profile():
    return json.loads(PROFILE.read_text(encoding="utf-8"))


def load_policy():
    return json.loads(POLICY.read_text(encoding="utf-8"))


def pkey(policy, surface_id):
    return next(item for item in policy["programmable_keys"] if item["surface_id"] == surface_id)


def action(policy, action_id):
    return next(item for item in policy["semantic_actions"] if item["id"] == action_id)


def test_titan2_policy_valid():
    assert validator.validate(load_profile(), load_policy()) == []


def test_routing_precedence_is_exact():
    policy = load_policy()
    assert policy["routing_order"] == validator.ROUTING_ORDER


def test_text_and_app_shortcuts_are_preserved():
    policy = load_policy()
    text = policy["text_routing"]
    assert text["editable_text_owner"] == "IME_TEXT_COMPOSITION"
    assert text["physical_soft_ime_default"] == "HIDDEN"
    assert text["home_printable_key"] == "START_COMMAND"
    assert text["home_first_key_preserved"] is True
    assert text["conventional_app_shortcuts"] == "PRESERVE"
    assert text["alt_text_role"] == "TEXT_COMPOSITION_FIRST"
    assert text["sym_text_role"] == "TEXT_COMPOSITION_FIRST"
    assert policy["reserved_global_chords"] == []


def test_programmable_keys_reference_kf1_surfaces_not_scan_codes():
    policy = load_policy()
    assert pkey(policy, "func1")["assignment_state"] == "UNDECIDED"
    assert pkey(policy, "func2")["assignment_state"] == "UNDECIDED"
    serialized = json.dumps(policy)
    assert '"scan_code"' not in serialized
    assert "KEYCODE_404" not in serialized
    assert '"stock_value": 404' not in serialized


def test_lockscreen_policy_precedes_home_and_commands():
    policy = load_policy()
    assert policy["routing_order"][0] == "SECURITY_LOCKSCREEN"
    assert action(policy, "OPEN_HOME")["lock_policy"] == "UNLOCKED_ONLY"
    assert action(policy, "OPEN_SEARCH_COMMAND")["lock_policy"] == "UNLOCKED_ONLY"
    assert action(policy, "OPEN_NOTIFICATIONS")["lock_policy"] == "ALLOW_LOCKED_REDACTED"
    assert policy["wake_policy"]["lockscreen_security_first"] is True


def test_touch_surface_stays_raw_fact_until_policy_decision():
    policy = load_policy()
    touch = policy["keyboard_touch_policy"]
    assert touch["raw_surface_id"] == "keyboard-touch-surface"
    assert touch["decision_state"] == "UNDECIDED"
    assert touch["default_mode"] == "UNDECIDED"
    assert set(touch["allowed_modes"]) == {"POINTER", "GESTURE", "HYBRID", "RAW_APP"}


def test_keyboard_light_ui_never_owns_sysfs():
    policy = load_policy()
    light = policy["keyboard_backlight_policy"]
    assert light["indicator_id"] == "keyboard-backlight"
    assert light["ui_owns_sysfs"] is False


def test_rear_display_product_role_is_delegated():
    policy = load_policy()
    delegated = {item["id"]: item for item in policy["delegated_decisions"]}
    assert delegated["REAR_SUBSCREEN_PRODUCT_ROLE"]["owner"] == "SECONDARY_DISPLAY_PRODUCT_POLICY"


def test_validator_rejects_raw_scan_code_in_policy():
    profile = load_profile()
    policy = load_policy()
    policy["programmable_keys"][0]["scan_code"] = 249
    errors = validator.validate(profile, policy)
    assert any("raw hardware field is forbidden" in error for error in errors)


def test_validator_rejects_unknown_programmable_surface():
    profile = load_profile()
    policy = load_policy()
    policy["programmable_keys"][0]["surface_id"] = "imaginary-key"
    errors = validator.validate(profile, policy)
    assert any("unknown KF1 surface" in error for error in errors)


if __name__ == "__main__":
    tests = [
        test_titan2_policy_valid,
        test_routing_precedence_is_exact,
        test_text_and_app_shortcuts_are_preserved,
        test_programmable_keys_reference_kf1_surfaces_not_scan_codes,
        test_lockscreen_policy_precedes_home_and_commands,
        test_touch_surface_stays_raw_fact_until_policy_decision,
        test_keyboard_light_ui_never_owns_sysfs,
        test_rear_display_product_role_is_delegated,
        test_validator_rejects_raw_scan_code_in_policy,
        test_validator_rejects_unknown_programmable_surface,
    ]
    for fn in tests:
        fn()
        print(f"PASS {fn.__name__}")
    print("KF2_KEYBOARD_POLICY_TESTS=PASS")
