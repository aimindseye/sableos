# ADR 0006: Multilingual local-first voice

Status: **Accepted**

## Context

SableOS is intended to support heterogeneous devices and users without reducing Android's mature internationalization capability. Indian-language support, especially Hindi, must be treated as a first-class product requirement rather than deferred translation work.

SableOS also plans a local-first on-device agent, Hub interaction model, search/command surface and future AOD/voice interaction. These features require speech recognition and synthesis but must not make SableOS dependent on proprietary Google speech services or silently send user audio to remote providers.

## Decision

SableOS will:

1. preserve the locale/font/IME/text-rendering capability available in the selected Android/AOSP baseline unless an explicit reviewed exception exists;
2. treat Hindi as a first-class acceptance language;
3. preserve other Indian-language locales supported by the selected Android baseline;
4. require Sable-owned UI to be localizable from first implementation;
5. require renderer qualification to include Indic text shaping/input, not only Latin-script rendering;
6. provide a Sable voice capability for STT and TTS using Android-compatible interfaces;
7. make local/on-device speech processing the default wherever a validated local model exists;
8. require English and Hindi local STT/TTS for the first production-capable Sable voice release;
9. expand additional Indian-language voice packs based on explicit validated capability rather than unsupported marketing claims;
10. prohibit silent remote fallback when a local speech model is unavailable;
11. keep microphone/audio/transcript handling under the Sable privacy baseline;
12. route agent voice commands through narrow typed Sable/Android capabilities rather than root/shell authority.

## Android preservation boundary

The policy does not replace Android's localization, IME, accessibility, TTS or speech-recognition framework contracts unnecessarily.

Sable may provide/select implementations behind those contracts, but third-party Android applications must continue to interact through normal Android APIs.

## Voice privacy

The baseline is explicit voice invocation / push-to-talk.

An always-listening wake word is optional and requires separate local wake-word, battery, privacy, lock-screen and false-activation validation.

Remote speech/model providers, if offered, are optional user-configured capabilities. They must not become a hidden dependency for Sable voice.

## Build integration

The current Panther bring-up is not restarted or invalidated by this ADR.

Until Sable-owned user-facing surfaces enter the product image, build gates preserve the selected AOSP language/font/IME substrate and prevent accidental locale stripping.

When Sable Hub/Search/Agent/shell voice support is integrated, builds must add the language/voice capability matrix and release markers defined by `../LANGUAGE_AND_VOICE_POLICY.md`.

Voice engines/models entering production become pinned release inputs covered by security, privacy, license and supply-chain review.

## Consequences

Positive:

- Indian-language users remain first-class SableOS users;
- Sable does not regress mature Android locale/input capability;
- voice works without mandatory Google/proprietary cloud speech services;
- the Hub, agent and search can share one privacy-preserving voice layer;
- language does not create parallel privilege architectures.

Costs:

- Sable UI and renderer testing must include Indic scripts from the start;
- offline speech models add image/storage/runtime resource cost;
- voice quality must be validated per language rather than assumed;
- model/toolchain licensing and update provenance become release concerns.

## Normative implementation

See `../LANGUAGE_AND_VOICE_POLICY.md`, `../INTERACTION_PROFILES.md`, `../ARCHITECTURE.md`, and `../SECURITY_PRIVACY_ASSURANCE_STANDARD.md`.