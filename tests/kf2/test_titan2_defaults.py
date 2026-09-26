#!/usr/bin/env python3
from __future__ import annotations

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

profile = json.loads(PROFILE.read_text(encoding="utf-8"))
policy = json.loads(POLICY.read_text(encoding="utf-8"))


def pkey(surface_id):
    return next(item for item in policy["programmable_keys"] if item["surface_id"] == surface_id)


def test_policy_still_valid():
    assert validator.validate(profile, policy) == []


def test_ordinary_keys_do_not_wake_primary():
    wake = policy["wake_policy"]
    assert wake["decision_state"] == "DECIDED"
    assert wake["ordinary_keyboard_primary_wake"] == "DISABLED"
    assert wake["lockscreen_security_first"] is True


def test_func1_is_command_key_with_locked_action_suppressed():
    item = pkey("func1")
    assert item["assignment_state"] == "ASSIGNED"
    assert item["semantic_action"] == "OPEN_SEARCH_COMMAND"
    assert item["lock_policy"] == "UNLOCKED_ONLY"
    assert item["wake_policy"] == "REQUEST_PRIMARY"
    assert item["user_configurable"] is True


def test_func2_is_attention_key_with_redaction():
    item = pkey("func2")
    assert item["assignment_state"] == "ASSIGNED"
    assert item["semantic_action"] == "OPEN_NOTIFICATIONS"
    assert item["lock_policy"] == "ALLOW_LOCKED_REDACTED"
    assert item["wake_policy"] == "REQUEST_PRIMARY"
    assert item["user_configurable"] is True


def test_touch_surface_defaults_to_pointer_and_is_selectable():
    touch = policy["keyboard_touch_policy"]
    assert touch["decision_state"] == "DECIDED"
    assert touch["default_mode"] == "POINTER"
    assert touch["user_selectable"] is True
    assert set(touch["allowed_modes"]) == {"POINTER", "GESTURE", "HYBRID", "RAW_APP"}


def test_backlight_defaults_are_bounded_and_non_notification():
    light = policy["keyboard_backlight_policy"]
    assert light["decision_state"] == "DECIDED"
    assert light["default_brightness_percent"] == 50
    assert light["timeout_policy"] == "FIXED_TIMEOUT"
    assert light["activity_timeout_seconds"] == 20
    assert light["wake_on_key"] == "ENABLED"
    assert light["notification_attention"] == "DISABLED"
    assert light["user_configurable"] is True
    assert light["ui_owns_sysfs"] is False


def test_navigation_mode_disabled_for_v1():
    nav = policy["navigation_mode"]
    assert nav["default_state"] == "OFF"
    assert nav["activation_state"] == "DISABLED"
    assert nav["activation"] is None
    assert nav["user_configurable"] is False


def test_reserved_global_chords_remain_empty():
    assert policy["reserved_global_chords"] == []


if __name__ == "__main__":
    tests = [
        test_policy_still_valid,
        test_ordinary_keys_do_not_wake_primary,
        test_func1_is_command_key_with_locked_action_suppressed,
        test_func2_is_attention_key_with_redaction,
        test_touch_surface_defaults_to_pointer_and_is_selectable,
        test_backlight_defaults_are_bounded_and_non_notification,
        test_navigation_mode_disabled_for_v1,
        test_reserved_global_chords_remain_empty,
    ]
    for fn in tests:
        fn()
        print(f"PASS {fn.__name__}")
    print("KF2_D1_TITAN2_DEFAULTS_TESTS=PASS")
