# Sable Mail — R8-G

Sable Mail is a bounded SableOS product adaptation of Thunderbird for Android.
SableOS does **not** reimplement IMAP, POP3, SMTP, MIME parsing, HTML sanitization,
mail storage, background synchronization or TLS/certificate handling from
scratch.

## Upstream pin

```text
repository  https://github.com/thunderbird/thunderbird-android.git
tag         THUNDERBIRD_23_0
commit      c733317d933c22bcd790a4790306f30ccf2026b8
license     Apache-2.0
```

The upstream commit is immutable qualification input. Apache-2.0 attribution
and notices remain required for distributed derivatives.

## Sable product identity

```text
label       Sable Mail
package     org.sableos.mail
```

The Sable patch keeps upstream protocol/security behavior unless a bounded
product-policy change is explicitly listed below.

## R8 policy changes

- Thunderbird/K-9 internal package namespaces are upstream implementation
  details and are not renamed wholesale.
- user-facing application/brand identity is Sable Mail;
- launcher and notification icons use Sable-owned artwork;
- the FOSS build uses the upstream no-op telemetry implementation;
- the FOSS funding implementation is replaced by the no-op funding module;
- Thunderbird migration/onboarding UI modules are replaced by their upstream no-op variants;
- Thunderbird Mail service/onboarding integration is removed from the Sable
  product app;
- inherited Thunderbird OAuth client IDs are removed from every build variant;
- generic IMAP/SMTP remains available;
- Gmail/Microsoft provider OAuth remains disabled until SableOS owns and
  qualifies its own OAuth client registrations and redirect URIs;
- Follow system / Light / Dark and Sable Blue / Green / Purple / Orange /
  Slate are read from the read-only SableStart appearance provider;
- upstream received-message remote network content remains blocked until the
  message-view flow explicitly enables it; this privacy behavior is a source
  qualification anchor and must not be weakened by Sable branding work.

The global appearance provider carries presentation state only. It does not
expose account, mail, contacts, device or security-sensitive data.

## Qualification

```bash
python3 apps/r8/mail/apply_sable_flavor.py /path/to/thunderbird-android
python3 apps/r8/mail/verify_sable_mail.py /path/to/thunderbird-android
```

Sable Mail uses two CI tiers:

1. **Product gate — `.github/workflows/r8-mail.yml`**
   - runs only when the Mail adaptation, Mail verifier, upstream pin, or Mail workflow changes;
   - does not rerun for unrelated SableStart or shared-design changes because those sources are not compiled into the Mail APK;
   - verifies the composed Sable Mail source policy;
   - runs `lintFossRelease` and `assembleFossRelease` in one Gradle invocation so shared configuration/compile work is reused;
   - proves the exact FOSS release runtime dependency policy;
   - verifies the APK identity/policy and records its SHA-256.
   Cross-app appearance/provider compatibility remains covered by the fast R8 final-UI closure static workflow.
2. **Manual upstream qualification — `.github/workflows/r8-mail-upstream.yml`**
   - runs only by explicit manual dispatch;
   - applies the Sable adaptation and source-policy verifier first;
   - runs Thunderbird's repository-wide `testsOnCi --parallel` suite, including
     upstream unit tests that may require Sable-specific expectation updates.

Unit tests are intentionally not a blocking ordinary PR gate while the
Thunderbird adaptation stabilizes. Run the manual upstream qualification after
changing the Thunderbird pin, adaptation-sensitive dependency wiring, or
upstream-derived test expectations.

A successful standalone build does not authorize Panther inclusion. The APK
must enter the source-bound R8 app bundle and pass the Panther product and
target-files gates.
