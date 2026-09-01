# SableOS Language and Voice Policy

Status: **normative product / interaction / privacy policy**.

SableOS preserves Android's mature internationalization, locale, text-rendering and input infrastructure while making multilingual voice a first-class Sable capability.

The product goal is that Indian-language users do not receive a reduced or secondary SableOS experience. Hindi is a first-class acceptance language, and Indian-language support already available in the selected Android/AOSP baseline must not be removed merely to simplify the shell, reduce image size or focus development on English.

## Core rule

> Preserve Android language capability; make Sable-owned experiences multilingual by design; provide voice locally by default wherever a validated local model is available.

SableOS must not create an English-only semantic core with translated screens bolted on later.

The same Sable concepts remain valid regardless of language:

```text
person
conversation
notification
reply
action
search
setting
permission
contact
call
reminder
agent request
```

Language changes text, speech and presentation. It must not create separate privilege or service architectures.

## AOSP language-preservation rule

For every selected Android baseline, SableOS must inventory the platform locale/resource set and preserve supported language infrastructure unless an explicit reviewed exception exists.

This includes, as applicable:

- Android resource locale handling;
- ICU/Unicode locale behavior;
- date, time, number and plural formatting;
- font fallback and script coverage;
- shaping/rendering for Indic and other complex scripts;
- standard Android IME APIs and input-method compatibility;
- per-app language support where provided by the Android baseline;
- accessibility and TextToSpeech framework compatibility;
- standard Android SpeechRecognizer / RecognitionService integration points.

A product-size optimization must not silently delete Indian-language locales, fonts, shaping data or input capability which the selected Android baseline otherwise supports.

## Indian-language baseline

The authoritative set is the Indian-language locale set present in the selected Android/AOSP baseline, not a permanently hard-coded Sable list.

Hindi is the initial mandatory first-class acceptance language:

```text
SABLEOS_LANGUAGE_HINDI=FIRST_CLASS
```

Other Indian languages/locales present in the selected Android baseline must remain available and must not regress because of Sable-owned shell/application changes.

Examples commonly relevant to validation include, without defining an exhaustive list:

- Hindi / Devanagari;
- Bengali;
- Gujarati;
- Kannada;
- Malayalam;
- Marathi;
- Punjabi;
- Tamil;
- Telugu;
- Assamese;
- Odia;
- Urdu where present in the baseline.

The actual build-time validation matrix must be generated from the selected Android baseline plus explicit Sable product requirements so that new Android locale support can be inherited automatically rather than waiting for a Sable policy rewrite.

## Sable-owned UI localization

New Sable user-facing components must be localizable from their first implementation.

Rules:

1. no user-visible hard-coded English strings in production Sable UI;
2. semantic action identifiers remain language-neutral internally;
3. layout must tolerate text expansion and different word boundaries;
4. date/number/plural presentation must use locale-aware platform behavior;
5. Indic shaping/font fallback must be tested in the actual selected renderer;
6. search must use Unicode-aware normalization and must not assume ASCII/Latin names;
7. contact/conversation identity must preserve original-script names;
8. Hub, Search, Settings, Security/Privacy and Agent surfaces must share the same localization infrastructure;
9. untranslated Sable strings must be discoverable by build/test tooling rather than silently falling back without evidence.

English may remain a development fallback, but production localization coverage must be explicit.

## Input policy

SableOS preserves standard Android input-method compatibility rather than creating a Sable-only keyboard protocol.

The product must support:

- third-party Android IMEs through normal Android APIs;
- AOSP/selected default IME behavior retained by the product;
- physical-keyboard input under the keyboard-first profile;
- Indic Unicode text entry and editing;
- composition/dead-key/IME flows required by complex scripts;
- voice dictation through the Sable/Android voice interface when enabled.

For a production Sable default keyboard, Indian-language layouts/transliteration should be validated explicitly. If the selected AOSP default does not provide adequate input for a required language, Sable may ship or select an additional input method, but it must remain behind Android's normal IME security boundary.

## Voice is a base Sable capability

SableOS should ship a voice capability out of the box for:

- dictation;
- Sable Search;
- Hub reply/actions;
- accessibility-compatible text-to-speech usage;
- the on-device Sable agent;
- future hands-free/AOD interactions where explicitly enabled.

Voice has two separate capabilities:

```text
STT = speech-to-text / recognition
TTS = text-to-speech / synthesis
```

They must be tracked independently per language because model quality and availability differ.

## Local-first voice rule

The default Sable voice path is:

```text
microphone
   -> local speech recognition when supported
   -> text / semantic request
   -> Sable/Android typed capability
   -> local text-to-speech when supported
```

A voice interaction must not silently upload audio because the local model lacks a language or because the device is offline.

If a cloud speech/model provider is ever supported:

- it is optional;
- it requires explicit user configuration/consent;
- the UI must show that audio/text may leave the device;
- provider use must be distinguishable from Sable's local voice path;
- disabling cloud processing must leave local-supported languages functional;
- a local-model failure must not silently fall through to a remote provider.

## Initial voice language requirements

For the first production-capable Sable voice release:

```text
English STT/TTS = REQUIRED
Hindi STT/TTS   = REQUIRED
```

for an on-device/local configuration that has passed the Sable quality, privacy, memory, latency and battery gates.

Additional Indian-language STT/TTS packs should be enabled as soon as validated local models meet those gates. Their absence must be reported as capability state rather than hidden.

Canonical per-language state:

```text
LANGUAGE_UI=SUPPORTED|PARTIAL|UNSUPPORTED|NOT_TESTED
STT_LOCAL=SUPPORTED|UNSUPPORTED|NOT_TESTED
TTS_LOCAL=SUPPORTED|UNSUPPORTED|NOT_TESTED
STT_REMOTE_OPTIONAL=YES|NO
TTS_REMOTE_OPTIONAL=YES|NO
VALIDATED=PASS|FAIL|NOT_RUN
```

Sable should aim to expand local voice toward the full practical Indian-language set supported by the Android product, but must not claim voice parity without model/runtime evidence.

## Voice privacy and microphone policy

Voice is a sensitive data path.

Default requirements:

```text
SABLEOS_VOICE_LOCAL_FIRST=YES
SABLEOS_VOICE_CLOUD_REQUIRED=NO
SABLEOS_VOICE_AUDIO_RETENTION_DEFAULT=NONE
SABLEOS_VOICE_TRANSCRIPT_UPLOAD_DEFAULT=NO
SABLEOS_VOICE_BACKGROUND_MIC_DEFAULT=NO
```

Rules:

- microphone access uses Android's normal permission/privacy-indicator model;
- recorded audio is not retained after recognition by default;
- transcripts are not persisted merely because recognition occurred;
- agent memory stores only information required by its explicit memory policy, not raw microphone streams;
- logs must not contain raw audio or unnecessary transcripts;
- diagnostic capture involving speech is user-initiated and clearly identified;
- ordinary applications do not receive a privileged path to Sable voice history.

## Wake word / always-listening policy

Push-to-talk / explicit voice invocation is the baseline capability.

An always-listening wake word is a separate optional feature and must not be required for Sable voice.

If implemented, it requires independent validation for:

- local wake-word detection;
- microphone indicator/privacy semantics;
- battery impact;
- false activation rate;
- lock-screen authorization boundaries;
- no remote streaming while waiting for a wake word;
- clear user disablement.

AOD voice affordances may invoke the same voice service, but the AOD surface itself must not acquire unrestricted microphone or agent authority.

## Sable agent integration

The on-device Sable agent consumes voice through the same narrow speech interface as other Sable surfaces.

Preferred architecture:

```text
mic
 -> Sable speech recognition
 -> text / language metadata
 -> Sable agent
 -> typed semantic action request
 -> narrow Sable/Android capability service
 -> result
 -> Sable speech synthesis
```

Rejected by default:

```text
voice -> agent -> root shell
voice -> agent -> arbitrary privileged command
voice -> agent -> unrestricted filesystem / other-app private data
```

Language recognition does not widen agent authority.

## Hub integration

The Sable Hub should support multilingual notification text without re-encoding or translating it unnecessarily.

Voice interaction should eventually allow actions such as:

```text
"इस संदेश का जवाब दो"
"Reply that I will call later"
"आज की unread messages दिखाओ"
```

only when the underlying Hub/notification action is authorized.

Recognition language and message language may differ; Sable must not silently translate private message content to a remote service.

## Search and contacts

Search must support Unicode/Indic names and text as first-class data.

Where practical, local search may support language-aware matching/transliteration, but transliteration is an additional search aid rather than a replacement for original-script identity.

A contact named in Devanagari, Tamil, Bengali or another script remains stored/displayed in its original form.

## Renderer and font validation

Any Sable renderer candidate must prove:

- Unicode text shaping;
- Devanagari rendering;
- representative Indic complex-script shaping;
- mixed-script text;
- cursor/selection behavior;
- IME composition;
- text input with touch and physical keyboard profiles;
- font fallback without missing-glyph boxes;
- accessibility text exposure.

A renderer which works only for Latin text does not qualify for production SableOS.

## Build and release evidence

Language/voice capability should eventually be represented by a generated matrix and bounded release markers.

Base markers:

```text
SABLEOS_LANGUAGE_BASELINE=PASS|FAIL|NOT_RUN
SABLEOS_AOSP_LOCALE_REGRESSION_COUNT=<integer|UNKNOWN>
SABLEOS_HINDI_UI_VALIDATION=PASS|FAIL|NOT_RUN
SABLEOS_INDIC_FONT_SHAPING=PASS|FAIL|NOT_RUN
SABLEOS_INDIC_INPUT_VALIDATION=PASS|FAIL|NOT_RUN
SABLEOS_LANGUAGE_MATRIX_SHA256=

SABLEOS_VOICE_ENGINE_PRESENT=PASS|FAIL|NOT_RUN
SABLEOS_VOICE_LOCAL_FIRST=YES|NO|UNKNOWN
SABLEOS_VOICE_CLOUD_REQUIRED=NO|YES|UNKNOWN
SABLEOS_VOICE_AUDIO_RETENTION_DEFAULT=NONE|BOUNDED|UNKNOWN
SABLEOS_HINDI_STT_LOCAL=PASS|FAIL|NOT_RUN
SABLEOS_HINDI_TTS_LOCAL=PASS|FAIL|NOT_RUN
SABLEOS_VOICE_LANGUAGE_MATRIX_SHA256=
```

Production claims must distinguish UI language support from voice-model support.

## Build integration timing

This policy does not require changing or restarting the active Panther product build.

During current Android bring-up, the requirement is to **preserve the selected AOSP language/font/IME substrate** and avoid introducing Sable-specific language regressions.

The full language/voice release gate becomes active when Sable-owned user-facing shell/Hub/Search/Agent components enter the product image. Voice model/engine selection must then be pinned, reproducible and covered by supply-chain/security/privacy review before production inclusion.

## Product principle

SableOS should feel native to a Hindi-speaking or other Indian-language user rather than merely capable of displaying their script.

This supports the broader product principle:

> Applications provide capabilities; Sable organizes people, attention and actions.

Those people, conversations, actions and voice interactions are multilingual by default.