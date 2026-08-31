# Carrier compatibility target

SableOS aims for broad carrier interoperability on the Pixel 4a 5G G025E (`bramble`) while preserving the supported Google/Qualcomm radio, IMS, and vendor stack.

## Baselines

### Current Sable system baseline

The current Sable architecture/regression substrate is Android 14 on bramble. New S1 service/UI/application work and the planned Android 15 portability experiment are evaluated against this current baseline.

### Historical physical carrier baseline

The July 2022 build `SQ3A.220705.003.A1` remains an important historical B0/B1 physical carrier-capability record because voice, SMS/MMS, packet data, IMS/VoLTE and 5G/NR behavior were exercised on real hardware there. It is not the current Sable system baseline.

Factory handset observed before unlock:

- build: `SQ1A.220105.002`
- bootloader: `b5-0.4-7758094`
- baseband: `g7250-00161-211008-B-7807492`

Frozen B0 contains newer firmware components:

- bootloader: `b5-0.4-8351080`
- baseband: `g7250-00202-220422-B-8489468`

This is an upgrade direction, not a downgrade. Firmware should still be updated deliberately and validated rather than blindly flashed as part of a whole-device package.

Carrier qualification on the current Android 14 Sable baseline must revalidate the relevant working services rather than assuming that historical B0/B1 evidence automatically transfers across framework, telephony or vendor-integration changes.

## Hardware capability boundary

Google lists model G025E with:

- LTE: B1/2/3/4/5/7/8/12/13/14/17/18/19/20/25/26/28/29/30/32/38/39/40/41/42/46/48/66/71
- 5G Sub-6: n1/2/5/12/25/28/41/66/71/78
- eSIM support

The G025E does not provide every band used by every operator. In particular, it is not a Verizon mmWave model and its published 5G band list does not include n77 or n70. SableOS cannot add unsupported RF bands in software.

Therefore the compatibility goal is:

> Voice, SMS, packet data, emergency calling, IMS/VoLTE, and roaming should work on standards-compatible carriers whose required bands and provisioning are supported by the G025E hardware and retained vendor stack.

## Architecture rules for carrier portability

1. Keep the Google/Qualcomm radio firmware and vendor Radio HAL stack intact.
2. Keep Qualcomm IMS/telephony vendor components intact until carrier qualification is complete.
3. Keep Android CarrierConfig and APN selection behavior; do not hard-code one carrier or APN.
4. Select behavior from SIM/eSIM identity, MCC/MNC, carrier configuration, and modem capabilities.
5. Do not replace the vendor radio protocol with a custom Rust modem implementation.
6. `oxynoded` or a future Sable telephony broker may observe/request through narrow Android interfaces later, but must not bypass the supported radio/IMS stack.
7. Treat emergency calling, IMS registration, VoLTE, and roaming as release blockers.
8. A Sable-native Rust shell/renderer must not require changes to the ordinary Android telephony/application semantics used by third-party APKs.

## Qualification matrix

### United States

Test at least one direct or MVNO profile on each major network family:

- Verizon network
- T-Mobile network
- AT&T network
- Boost/Dish as best-effort according to the network actually selected for the subscription and the G025E hardware bands

For each profile validate:

- SIM/eSIM detection
- automatic APN selection
- LTE registration
- available 5G registration
- mobile data
- outbound/inbound SMS
- MMS
- outbound/inbound voice
- IMS registration
- VoLTE
- Wi-Fi calling if provisioned
- emergency calling test procedure appropriate to the test environment
- handoff/reconnect after airplane mode
- reboot persistence

### International

Qualification should include representative SIM/eSIM profiles from multiple regions rather than claiming literal universal carrier support. Prioritize:

- Europe/UK
- Canada
- Latin America
- Japan/Korea
- India/South Asia
- Australia/New Zealand

Test LTE first, then 5G where the local operator uses a band supported by G025E. Also test roaming on at least one US subscription outside its home network when practical.

## Current test SIM

The current test SIM reports operator name `Infimobile`. Infimobile offers service on Verizon or T-Mobile networks, so the display name alone does not identify the underlying network. Capture the numeric operator before using the result as a Verizon- or T-Mobile-family qualification record.

Useful non-secret diagnostics:

```bash
adb shell getprop gsm.sim.operator.numeric
adb shell getprop gsm.operator.numeric
adb shell getprop gsm.network.type
adb shell dumpsys telephony.registry
```

Do not commit IMSI, ICCID, IMEI, phone number, or device serial values to the repository.

## Android-version portability

The Android 15 bramble experiment occurs after S1.8 and before S1.9. It must treat telephony/carrier behavior as a measured parity gate rather than assuming that a booting Android 15 userspace implies carrier compatibility with frozen bramble vendor/firmware components.

A regression discovered there is classified by framework/telephony/vendor boundary before any compatibility shim or security relaxation is considered.

## Release rule

A single working SIM is a smoke test, not carrier certification. Carrier support should be tracked as a matrix of tested network families, services, Android substrate versions and regions, with explicit known limitations derived from G025E hardware bands, carrier provisioning and the retained vendor/firmware security lifecycle.
