#!/usr/bin/env python3
"""Validate SableOS KF2 keyboard policy against a KF1 device profile."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROUTING_ORDER = [
    "SECURITY_LOCKSCREEN",
    "RESERVED_SABLE_CHORD",
    "IME_TEXT_COMPOSITION",
    "APPLICATION_SHORTCUT",
    "HOME_TYPE_TO_COMMAND",
    "SABLE_NAVIGATION_MODE",
    "NORMAL_APPLICATION_EVENT",
]
LOCK_POLICIES = {
    "ALLOW_LOCKED",
    "ALLOW_LOCKED_REDACTED",
    "AUTH_REQUIRED",
    "UNLOCKED_ONLY",
    "DISABLED",
}
FORBIDDEN_POLICY_FIELDS = {"scan_code", "key_code", "linux_name", "driver", "module"}
ID_RE = re.compile(r"^[A-Z0-9_]+$")


def require(condition: bool, errors: list[str], message: str) -> None:
    if not condition:
        errors.append(message)


def by_id(items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {item["id"]: item for item in items if isinstance(item, dict) and isinstance(item.get("id"), str)}


def find_forbidden_fields(value: Any, path: str = "$") -> list[str]:
    errors: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in FORBIDDEN_POLICY_FIELDS:
                errors.append(f"{path}.{key}: raw hardware field is forbidden in KF2 policy")
            errors.extend(find_forbidden_fields(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for idx, child in enumerate(value):
            errors.extend(find_forbidden_fields(child, f"{path}[{idx}]"))
    elif isinstance(value, str) and value.startswith("KEYCODE_"):
        errors.append(f"{path}: raw Android keycode is forbidden in KF2 policy: {value}")
    return errors


def validate(profile: dict[str, Any], policy: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    require(policy.get("schema_version") == 1, errors, "policy schema_version must be 1")
    require(policy.get("device_profile_id") == profile.get("profile_id"), errors,
            "policy device_profile_id must match KF1 profile_id")
    require(policy.get("device_class") == profile.get("device_class"), errors,
            "policy device_class must match KF1 device_class")
    require(policy.get("interaction_profile") == "KEYBOARD_FIRST", errors,
            "KF2 policy interaction_profile must be KEYBOARD_FIRST")
    require(profile.get("interaction_profile") == "KEYBOARD_FIRST", errors,
            "KF1 profile must be KEYBOARD_FIRST for this KF2 policy")

    require(policy.get("routing_order") == ROUTING_ORDER, errors,
            "routing_order must exactly match ADR-0010 seven-stage precedence")

    text = policy.get("text_routing")
    require(isinstance(text, dict), errors, "text_routing must be an object")
    if isinstance(text, dict):
        require(text.get("editable_text_owner") == "IME_TEXT_COMPOSITION", errors,
                "editable text must route to IME_TEXT_COMPOSITION")
        require(text.get("physical_soft_ime_default") == "HIDDEN", errors,
                "physical-keyboard default must keep full soft IME hidden")
        require(text.get("home_printable_key") == "START_COMMAND", errors,
                "HOME printable key must start command/search")
        require(text.get("home_first_key_preserved") is True, errors,
                "HOME first printable key must be preserved")
        require(text.get("conventional_app_shortcuts") == "PRESERVE", errors,
                "conventional app shortcuts must be preserved")
        require(text.get("alt_text_role") == "TEXT_COMPOSITION_FIRST", errors,
                "Alt must remain text-composition-first by default")
        require(text.get("sym_text_role") == "TEXT_COMPOSITION_FIRST", errors,
                "SYM must remain text-composition-first by default")

    actions = policy.get("semantic_actions")
    require(isinstance(actions, list), errors, "semantic_actions must be a list")
    action_map: dict[str, dict[str, Any]] = {}
    if isinstance(actions, list):
        for idx, action in enumerate(actions):
            if not isinstance(action, dict):
                errors.append(f"semantic_actions[{idx}] must be an object")
                continue
            aid = action.get("id")
            require(isinstance(aid, str) and bool(ID_RE.fullmatch(aid)), errors,
                    f"semantic_actions[{idx}].id invalid")
            if isinstance(aid, str):
                require(aid not in action_map, errors, f"duplicate semantic action: {aid}")
                action_map[aid] = action
            require(action.get("lock_policy") in LOCK_POLICIES, errors,
                    f"semantic_actions[{idx}].lock_policy invalid")

    chords = policy.get("reserved_global_chords")
    require(isinstance(chords, list), errors, "reserved_global_chords must be a list")
    if isinstance(chords, list):
        seen: set[str] = set()
        for idx, chord in enumerate(chords):
            if not isinstance(chord, dict):
                errors.append(f"reserved_global_chords[{idx}] must be an object")
                continue
            cid = chord.get("id")
            require(isinstance(cid, str) and bool(ID_RE.fullmatch(cid)), errors,
                    f"reserved_global_chords[{idx}].id invalid")
            if isinstance(cid, str):
                require(cid not in seen, errors, f"duplicate reserved chord: {cid}")
                seen.add(cid)
            keys = chord.get("keys")
            require(isinstance(keys, list) and len(keys) >= 2, errors,
                    f"reserved_global_chords[{idx}] must contain at least two keys")
            action_id = chord.get("semantic_action")
            require(action_id in action_map, errors,
                    f"reserved_global_chords[{idx}] references unknown semantic action {action_id!r}")

    surfaces = by_id(profile.get("input_surfaces", []))
    pkeys = policy.get("programmable_keys")
    require(isinstance(pkeys, list), errors, "programmable_keys must be a list")
    if isinstance(pkeys, list):
        seen_surfaces: set[str] = set()
        for idx, item in enumerate(pkeys):
            if not isinstance(item, dict):
                errors.append(f"programmable_keys[{idx}] must be an object")
                continue
            sid = item.get("surface_id")
            require(isinstance(sid, str) and sid in surfaces, errors,
                    f"programmable_keys[{idx}] references unknown KF1 surface {sid!r}")
            if isinstance(sid, str):
                require(sid not in seen_surfaces, errors, f"duplicate programmable surface: {sid}")
                seen_surfaces.add(sid)
                if sid in surfaces:
                    require(surfaces[sid].get("surface_type") == "PROGRAMMABLE_KEY", errors,
                            f"surface {sid} is not PROGRAMMABLE_KEY in KF1 profile")
            state = item.get("assignment_state")
            action_id = item.get("semantic_action")
            if state == "UNDECIDED":
                require(action_id is None, errors,
                        f"programmable key {sid} UNDECIDED must not assign a semantic action")
                require(item.get("lock_policy") == "DISABLED", errors,
                        f"programmable key {sid} UNDECIDED must use lock_policy=DISABLED")
            elif state == "DISABLED":
                require(action_id is None, errors,
                        f"programmable key {sid} DISABLED must not assign a semantic action")
            elif state == "ASSIGNED":
                require(action_id in action_map, errors,
                        f"programmable key {sid} ASSIGNED references unknown action {action_id!r}")
                require(isinstance(item.get("user_configurable"), bool), errors,
                        f"programmable key {sid} ASSIGNED requires explicit user_configurable boolean")
            else:
                errors.append(f"programmable key {sid} has invalid assignment_state {state!r}")

    touch = policy.get("keyboard_touch_policy")
    require(isinstance(touch, dict), errors, "keyboard_touch_policy must be an object")
    if isinstance(touch, dict):
        sid = touch.get("raw_surface_id")
        require(sid in surfaces, errors,
                f"keyboard_touch_policy references unknown KF1 surface {sid!r}")
        if sid in surfaces:
            require(surfaces[sid].get("surface_type") == "ABSOLUTE_TOUCH_SURFACE", errors,
                    "keyboard_touch_policy raw_surface_id must reference ABSOLUTE_TOUCH_SURFACE")
        allowed = touch.get("allowed_modes")
        default = touch.get("default_mode")
        if touch.get("decision_state") == "DECIDED":
            require(default != "UNDECIDED", errors,
                    "decided keyboard_touch_policy requires a concrete default_mode")
            require(isinstance(allowed, list) and default in allowed, errors,
                    "keyboard_touch_policy default_mode must be present in allowed_modes")
        require(isinstance(touch.get("user_selectable"), bool), errors,
                "keyboard_touch_policy requires explicit user_selectable boolean")

    indicators = by_id(profile.get("indicators", []))
    light = policy.get("keyboard_backlight_policy")
    require(isinstance(light, dict), errors, "keyboard_backlight_policy must be an object")
    if isinstance(light, dict):
        iid = light.get("indicator_id")
        require(iid in indicators, errors,
                f"keyboard_backlight_policy references unknown KF1 indicator {iid!r}")
        if iid in indicators:
            require(indicators[iid].get("indicator_type") == "KEYBOARD_BACKLIGHT", errors,
                    "keyboard_backlight_policy must reference a KEYBOARD_BACKLIGHT indicator")
        require(light.get("ui_owns_sysfs") is False, errors,
                "KF2 UI must not directly own keyboard-light sysfs")
        if light.get("decision_state") == "DECIDED":
            require(light.get("timeout_policy") != "UNDECIDED", errors,
                    "decided keyboard_backlight_policy requires timeout_policy")
            require(light.get("wake_on_key") != "UNDECIDED", errors,
                    "decided keyboard_backlight_policy requires wake_on_key")
            require(light.get("notification_attention") != "UNDECIDED", errors,
                    "decided keyboard_backlight_policy requires notification_attention")
            brightness = light.get("default_brightness_percent")
            timeout = light.get("activity_timeout_seconds")
            require(isinstance(brightness, int) and 0 <= brightness <= 100, errors,
                    "keyboard backlight default_brightness_percent must be 0..100")
            require(isinstance(timeout, int) and 0 <= timeout <= 600, errors,
                    "keyboard backlight activity_timeout_seconds must be 0..600")
        require(isinstance(light.get("user_configurable"), bool), errors,
                "keyboard_backlight_policy requires explicit user_configurable boolean")

    wake = policy.get("wake_policy")
    require(isinstance(wake, dict), errors, "wake_policy must be an object")
    if isinstance(wake, dict):
        require(wake.get("lockscreen_security_first") is True, errors,
                "lockscreen security must remain first in wake/input routing")
        if wake.get("decision_state") == "DECIDED":
            require(wake.get("ordinary_keyboard_primary_wake") != "UNDECIDED", errors,
                    "decided wake_policy requires ordinary_keyboard_primary_wake")

    nav = policy.get("navigation_mode")
    require(isinstance(nav, dict), errors, "navigation_mode must be an object")
    if isinstance(nav, dict):
        require(isinstance(nav.get("user_configurable"), bool), errors,
                "navigation_mode requires explicit user_configurable boolean")
        if nav.get("activation_state") == "DISABLED":
            require(nav.get("activation") is None, errors,
                    "disabled navigation mode must not define an activation")

    delegated = policy.get("delegated_decisions")
    require(isinstance(delegated, list), errors, "delegated_decisions must be a list")
    if isinstance(delegated, list):
        ids = {d.get("id") for d in delegated if isinstance(d, dict)}
        require("REAR_SUBSCREEN_PRODUCT_ROLE" in ids, errors,
                "rear SubScreen product role must be explicitly delegated outside KF2")

    errors.extend(find_forbidden_fields(policy))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--policy", required=True, type=Path)
    args = parser.parse_args()

    try:
        profile = json.loads(args.profile.read_text(encoding="utf-8"))
        policy = json.loads(args.policy.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"KF2_KEYBOARD_POLICY=FAIL error={exc}")
        return 1

    errors = validate(profile, policy)
    if errors:
        print(f"KF2_KEYBOARD_POLICY=FAIL errors={len(errors)}")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "KF2_KEYBOARD_POLICY=PASS "
        f"policy_id={policy['policy_id']} "
        f"device={policy['device_class']} "
        f"profile={policy['device_profile_id']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
