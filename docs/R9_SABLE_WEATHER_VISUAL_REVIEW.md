# R9 Sable Weather visual-first design

Status: **visual review only / production Weather app not yet created**

## Existing Rust lineage

The Android Weather design is intentionally derived from the existing Rust
implementation in:

`aimindseye/ESP32-S3-Touch-LCD-1.85C-Assistant`

Reviewed source baseline:

`c247b208f2a64921cc5b99b516c8a09234a76f50`

Relevant Rust source:

- `firmware/assistant-rs/src/app/weather.rs`
- `firmware/assistant-rs/src/app/providers.rs`
- `firmware/assistant-rs/src/screens/weather.rs`
- `firmware/assistant-rs/src/weather_action_router.rs`

The accepted embedded implementation already defines:

- provider states: `LOCAL`, `FETCHING`, `LIVE`, `STALE`, `FAILED`;
- Fahrenheit/Celsius units;
- configured weather locations and time zones;
- current temperature + WMO-style weather-code mapping;
- hourly forecast slots;
- Open-Meteo response parsing;
- explicit previous/next location behavior;
- last-known-good cache serialization;
- truthful stale/failure behavior.

The Android product should preserve these concepts rather than replacing them
with a separate weather model.

## Android architecture after visual approval

Sable Weather will use a Rust-core / Android-shell boundary.

Planned Rust core:

- `weather-core` crate;
- provider status state machine;
- weather location model;
- units and condition mapping;
- Open-Meteo request model;
- response parsing;
- cache serialization/deserialization;
- normalized current/hourly/daily domain models.

Planned Android/Kotlin responsibilities:

- HTTPS transport;
- Android approximate-location permission;
- manual city search and saved places;
- background scheduling;
- notifications and severe-weather alert presentation;
- app widgets;
- local provider surface consumed by Sable Start;
- Compose UI and Sable appearance integration.

The current embedded provider URL uses plain HTTP. Android Sable Weather must
use HTTPS and must not expose a cleartext provider path.

## Privacy contract

Manual city selection is the default and requires no location permission.

Approximate device location is optional.

Precise location is not required by the Weather design and is not requested by
default.

Forecasts are cached locally. Sable Start consumes a local Weather snapshot;
Launcher does not perform its own weather network request.

No account, advertising SDK, analytics SDK, or ambient location history is
part of the design.

## Visual direction

The phone UI extends the embedded product rather than copying its 390x390
geometry.

Preserved ideas:

- temperature remains visually dominant;
- location and freshness are explicit;
- hourly progression remains a first-class surface;
- cached/stale state is visible rather than silently hidden;
- saved-location switching remains first-class.

Phone-specific expansion:

- current conditions with feels-like/high/low;
- rain, humidity, and wind metrics;
- dedicated hourly precipitation timeline;
- seven-day forecast;
- saved-locations view;
- first-run privacy/location choice;
- explicit offline/cached state;
- Sable light/dark/accent integration.

The design avoids rounded-card dashboards. Sections are typography-first,
separated by whitespace and hairlines, following the Sable/Metro-derived
language used by Launcher, Phone, and Contacts.

## Visual-review module

Non-product module:

`apps/r8/android/weather-visual-review`

Application ID:

`org.sableos.weather.visualreview`

The review APK uses fixture data only. It has no INTERNET permission, no
location permission, no provider calls, and no product inclusion.

Required automatic capture set:

- `00-weather-current-light`
- `01-weather-hourly-light`
- `02-weather-daily-light`
- `03-weather-locations-light`
- `04-weather-privacy-light`
- `05-weather-stale-light`
- `06-weather-current-dark`
- `07-weather-daily-dark`

After visual approval, the next Weather deliverable is the reusable Rust core
plus Android app shell. Phone/Contacts platform implementation resumes only
after the Mac visual-design phase is closed.
