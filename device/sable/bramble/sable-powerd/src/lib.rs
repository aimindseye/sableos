//! B2.3 bramble power-state mapper for sable-powerd.
//!
//! This module is deliberately host-testable. It defines the narrow
//! bramble sysfs mapping, a reader abstraction, and the private semantic
//! protocol shape. It does not create sockets, start a daemon, or change
//! SELinux policy.

use sable_power::{PowerSource, PowerState};

use std::fs;

pub const BATTERY_CAPACITY: &str =
    "/sys/class/power_supply/battery/capacity";
pub const BATTERY_STATUS: &str =
    "/sys/class/power_supply/battery/status";
pub const DC_ONLINE: &str =
    "/sys/class/power_supply/dc/online";
pub const PC_PORT_ONLINE: &str =
    "/sys/class/power_supply/pc_port/online";
pub const USB_ONLINE: &str =
    "/sys/class/power_supply/usb/online";

pub const REQUEST_POWER_READ_STATE: &str = "POWER_READ_STATE";

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MapError {
    ReadFailure(&'static str),
    InvalidCapacity(String),
    InvalidOnline(&'static str, String),
    InvalidStatus(String),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Request {
    PowerReadState,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProtocolError {
    InvalidRequest,
}

pub trait TextReader {
    fn read_text(&self, path: &'static str) -> Result<String, MapError>;
}

pub struct FsReader;

impl TextReader for FsReader {
    fn read_text(&self, path: &'static str) -> Result<String, MapError> {
        fs::read_to_string(path)
            .map_err(|_| MapError::ReadFailure(path))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RawPowerSnapshot {
    pub capacity: String,
    pub status: String,
    pub dc_online: String,
    pub pc_port_online: String,
    pub usb_online: String,
}

fn trimmed(value: &str) -> &str {
    value.trim()
}

fn parse_capacity(value: &str) -> Result<u8, MapError> {
    let text = trimmed(value);

    let parsed = text
        .parse::<u16>()
        .map_err(|_| MapError::InvalidCapacity(text.to_string()))?;

    if parsed > 100 {
        return Err(MapError::InvalidCapacity(text.to_string()));
    }

    Ok(parsed as u8)
}

fn parse_online(
    field: &'static str,
    value: &str,
) -> Result<bool, MapError> {
    match trimmed(value) {
        "0" => Ok(false),
        "1" => Ok(true),
        other => Err(MapError::InvalidOnline(
            field,
            other.to_string(),
        )),
    }
}

fn parse_charging(status: &str) -> Result<bool, MapError> {
    match trimmed(status) {
        "Charging" | "Full" => Ok(true),
        "Discharging" | "Not charging" | "Unknown" => Ok(false),
        other => Err(MapError::InvalidStatus(other.to_string())),
    }
}

pub fn map_snapshot(
    raw: &RawPowerSnapshot,
) -> Result<PowerState, MapError> {
    let battery_percent = parse_capacity(&raw.capacity)?;
    let charging = parse_charging(&raw.status)?;

    let wireless = parse_online(DC_ONLINE, &raw.dc_online)?;
    let pc_port = parse_online(PC_PORT_ONLINE, &raw.pc_port_online)?;
    let usb = parse_online(USB_ONLINE, &raw.usb_online)?;

    let source = if wireless {
        PowerSource::Wireless
    } else if pc_port || usb {
        PowerSource::Usb
    } else if charging {
        PowerSource::Unknown
    } else {
        PowerSource::Battery
    };

    Ok(PowerState {
        battery_percent,
        charging,
        source,
    })
}

pub fn read_state<R: TextReader>(
    reader: &R,
) -> Result<PowerState, MapError> {
    let raw = RawPowerSnapshot {
        capacity: reader.read_text(BATTERY_CAPACITY)?,
        status: reader.read_text(BATTERY_STATUS)?,
        dc_online: reader.read_text(DC_ONLINE)?,
        pc_port_online: reader.read_text(PC_PORT_ONLINE)?,
        usb_online: reader.read_text(USB_ONLINE)?,
    };

    map_snapshot(&raw)
}

pub fn parse_request(input: &str) -> Result<Request, ProtocolError> {
    match input.trim() {
        REQUEST_POWER_READ_STATE => Ok(Request::PowerReadState),
        _ => Err(ProtocolError::InvalidRequest),
    }
}

fn source_name(source: PowerSource) -> &'static str {
    match source {
        PowerSource::Battery => "Battery",
        PowerSource::Usb => "Usb",
        PowerSource::Ac => "Ac",
        PowerSource::Wireless => "Wireless",
        PowerSource::Unknown => "Unknown",
    }
}

pub fn encode_state(state: PowerState) -> String {
    format!(
        "OK battery_percent={} charging={} source={}\n",
        state.battery_percent,
        if state.charging { 1 } else { 0 },
        source_name(state.source),
    )
}

pub fn encode_error(code: &str) -> String {
    format!("ERR code={}\n", code)
}

#[cfg(test)]
mod tests {
    use super::*;

    use std::collections::BTreeMap;

    struct FakeReader {
        values: BTreeMap<&'static str, &'static str>,
    }

    impl FakeReader {
        fn complete(
            capacity: &'static str,
            status: &'static str,
            dc: &'static str,
            pc_port: &'static str,
            usb: &'static str,
        ) -> Self {
            let mut values = BTreeMap::new();

            values.insert(BATTERY_CAPACITY, capacity);
            values.insert(BATTERY_STATUS, status);
            values.insert(DC_ONLINE, dc);
            values.insert(PC_PORT_ONLINE, pc_port);
            values.insert(USB_ONLINE, usb);

            Self { values }
        }
    }

    impl TextReader for FakeReader {
        fn read_text(
            &self,
            path: &'static str,
        ) -> Result<String, MapError> {
            self.values
                .get(path)
                .map(|value| value.to_string())
                .ok_or(MapError::ReadFailure(path))
        }
    }

    #[test]
    fn observed_unplugged_maps_to_battery() {
        let raw = RawPowerSnapshot {
            capacity: "100\n".to_string(),
            status: "Discharging\n".to_string(),
            dc_online: "0\n".to_string(),
            pc_port_online: "0\n".to_string(),
            usb_online: "0\n".to_string(),
        };

        assert_eq!(
            map_snapshot(&raw),
            Ok(PowerState {
                battery_percent: 100,
                charging: false,
                source: PowerSource::Battery,
            })
        );
    }

    #[test]
    fn observed_thinkpad_usb_pd_maps_to_usb() {
        let raw = RawPowerSnapshot {
            capacity: "100\n".to_string(),
            status: "Full\n".to_string(),
            dc_online: "0\n".to_string(),
            pc_port_online: "0\n".to_string(),
            usb_online: "1\n".to_string(),
        };

        assert_eq!(
            map_snapshot(&raw),
            Ok(PowerState {
                battery_percent: 100,
                charging: true,
                source: PowerSource::Usb,
            })
        );
    }

    #[test]
    fn observed_pc_port_online_maps_to_usb() {
        let raw = RawPowerSnapshot {
            capacity: "80".to_string(),
            status: "Charging".to_string(),
            dc_online: "0".to_string(),
            pc_port_online: "1".to_string(),
            usb_online: "0".to_string(),
        };

        assert_eq!(
            map_snapshot(&raw).unwrap().source,
            PowerSource::Usb
        );
    }

    #[test]
    fn wireless_has_source_precedence() {
        let raw = RawPowerSnapshot {
            capacity: "75".to_string(),
            status: "Charging".to_string(),
            dc_online: "1".to_string(),
            pc_port_online: "1".to_string(),
            usb_online: "1".to_string(),
        };

        assert_eq!(
            map_snapshot(&raw).unwrap().source,
            PowerSource::Wireless
        );
    }

    #[test]
    fn charging_without_known_source_is_unknown() {
        let raw = RawPowerSnapshot {
            capacity: "50".to_string(),
            status: "Charging".to_string(),
            dc_online: "0".to_string(),
            pc_port_online: "0".to_string(),
            usb_online: "0".to_string(),
        };

        assert_eq!(
            map_snapshot(&raw).unwrap().source,
            PowerSource::Unknown
        );
    }

    #[test]
    fn full_counts_as_charging() {
        let raw = RawPowerSnapshot {
            capacity: "100".to_string(),
            status: "Full".to_string(),
            dc_online: "0".to_string(),
            pc_port_online: "0".to_string(),
            usb_online: "1".to_string(),
        };

        assert!(map_snapshot(&raw).unwrap().charging);
    }

    #[test]
    fn not_charging_is_false() {
        let raw = RawPowerSnapshot {
            capacity: "60".to_string(),
            status: "Not charging".to_string(),
            dc_online: "0".to_string(),
            pc_port_online: "0".to_string(),
            usb_online: "1".to_string(),
        };

        assert!(!map_snapshot(&raw).unwrap().charging);
    }

    #[test]
    fn invalid_capacity_over_100_is_rejected() {
        let raw = RawPowerSnapshot {
            capacity: "101".to_string(),
            status: "Charging".to_string(),
            dc_online: "0".to_string(),
            pc_port_online: "0".to_string(),
            usb_online: "1".to_string(),
        };

        assert_eq!(
            map_snapshot(&raw),
            Err(MapError::InvalidCapacity("101".to_string()))
        );
    }

    #[test]
    fn malformed_capacity_is_rejected() {
        let raw = RawPowerSnapshot {
            capacity: "abc".to_string(),
            status: "Charging".to_string(),
            dc_online: "0".to_string(),
            pc_port_online: "0".to_string(),
            usb_online: "1".to_string(),
        };

        assert_eq!(
            map_snapshot(&raw),
            Err(MapError::InvalidCapacity("abc".to_string()))
        );
    }

    #[test]
    fn malformed_online_is_rejected() {
        let raw = RawPowerSnapshot {
            capacity: "50".to_string(),
            status: "Charging".to_string(),
            dc_online: "maybe".to_string(),
            pc_port_online: "0".to_string(),
            usb_online: "1".to_string(),
        };

        assert_eq!(
            map_snapshot(&raw),
            Err(MapError::InvalidOnline(
                DC_ONLINE,
                "maybe".to_string(),
            ))
        );
    }

    #[test]
    fn malformed_status_is_rejected() {
        let raw = RawPowerSnapshot {
            capacity: "50".to_string(),
            status: "Broken".to_string(),
            dc_online: "0".to_string(),
            pc_port_online: "0".to_string(),
            usb_online: "1".to_string(),
        };

        assert_eq!(
            map_snapshot(&raw),
            Err(MapError::InvalidStatus("Broken".to_string()))
        );
    }

    #[test]
    fn reader_success_maps_state() {
        let reader = FakeReader::complete(
            "42\n",
            "Charging\n",
            "0\n",
            "0\n",
            "1\n",
        );

        assert_eq!(
            read_state(&reader),
            Ok(PowerState {
                battery_percent: 42,
                charging: true,
                source: PowerSource::Usb,
            })
        );
    }

    #[test]
    fn missing_reader_value_is_explicit_error() {
        let reader = FakeReader {
            values: BTreeMap::new(),
        };

        assert_eq!(
            read_state(&reader),
            Err(MapError::ReadFailure(BATTERY_CAPACITY))
        );
    }

    #[test]
    fn protocol_request_is_exact() {
        assert_eq!(
            parse_request("POWER_READ_STATE\n"),
            Ok(Request::PowerReadState)
        );

        assert_eq!(
            parse_request("POWER_WRITE_STATE\n"),
            Err(ProtocolError::InvalidRequest)
        );
    }

    #[test]
    fn protocol_state_encoding_is_stable() {
        let state = PowerState {
            battery_percent: 42,
            charging: true,
            source: PowerSource::Usb,
        };

        assert_eq!(
            encode_state(state),
            "OK battery_percent=42 charging=1 source=Usb\n"
        );
    }

    #[test]
    fn protocol_error_encoding_is_stable() {
        assert_eq!(
            encode_error("read_failed"),
            "ERR code=read_failed\n"
        );
    }
}
