//! SableOS semantic power-state API.
//!
//! This module deliberately contains no device-specific paths,
//! Android properties, HAL identifiers, or privileged operations.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PowerSource {
    Battery,
    Usb,
    Ac,
    Wireless,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PowerState {
    pub battery_percent: u8,
    pub charging: bool,
    pub source: PowerSource,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PowerError {
    BackendUnavailable,
    InvalidBatteryPercent(u8),
}

pub trait PowerBackend {
    fn read_state(&self) -> Result<PowerState, PowerError>;
}

pub struct PowerService<B>
where
    B: PowerBackend,
{
    backend: B,
}

impl<B> PowerService<B>
where
    B: PowerBackend,
{
    pub fn new(backend: B) -> Self {
        Self { backend }
    }

    pub fn read_state(&self) -> Result<PowerState, PowerError> {
        let state = self.backend.read_state()?;

        if state.battery_percent > 100 {
            return Err(PowerError::InvalidBatteryPercent(
                state.battery_percent,
            ));
        }

        Ok(state)
    }
}

#[derive(Debug, Clone, Copy)]
pub struct MockPowerBackend {
    result: Result<PowerState, PowerError>,
}

impl MockPowerBackend {
    pub fn with_state(state: PowerState) -> Self {
        Self { result: Ok(state) }
    }

    pub fn unavailable() -> Self {
        Self {
            result: Err(PowerError::BackendUnavailable),
        }
    }
}

impl PowerBackend for MockPowerBackend {
    fn read_state(&self) -> Result<PowerState, PowerError> {
        self.result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn read(state: PowerState) -> Result<PowerState, PowerError> {
        PowerService::new(
            MockPowerBackend::with_state(state),
        )
        .read_state()
    }

    #[test]
    fn battery_state() {
        let state = PowerState {
            battery_percent: 73,
            charging: false,
            source: PowerSource::Battery,
        };

        assert_eq!(read(state), Ok(state));
    }

    #[test]
    fn usb_charging_state() {
        let state = PowerState {
            battery_percent: 42,
            charging: true,
            source: PowerSource::Usb,
        };

        assert_eq!(read(state), Ok(state));
    }

    #[test]
    fn ac_charging_state() {
        let state = PowerState {
            battery_percent: 51,
            charging: true,
            source: PowerSource::Ac,
        };

        assert_eq!(read(state), Ok(state));
    }

    #[test]
    fn wireless_charging_state() {
        let state = PowerState {
            battery_percent: 64,
            charging: true,
            source: PowerSource::Wireless,
        };

        assert_eq!(read(state), Ok(state));
    }

    #[test]
    fn unknown_source_state() {
        let state = PowerState {
            battery_percent: 35,
            charging: true,
            source: PowerSource::Unknown,
        };

        assert_eq!(read(state), Ok(state));
    }

    #[test]
    fn low_battery_is_valid() {
        let state = PowerState {
            battery_percent: 1,
            charging: false,
            source: PowerSource::Battery,
        };

        assert_eq!(read(state), Ok(state));
    }

    #[test]
    fn full_battery_is_valid() {
        let state = PowerState {
            battery_percent: 100,
            charging: false,
            source: PowerSource::Battery,
        };

        assert_eq!(read(state), Ok(state));
    }

    #[test]
    fn invalid_battery_percent_is_rejected() {
        let state = PowerState {
            battery_percent: 101,
            charging: false,
            source: PowerSource::Battery,
        };

        assert_eq!(
            read(state),
            Err(PowerError::InvalidBatteryPercent(101))
        );
    }

    #[test]
    fn backend_failure_is_propagated() {
        let service =
            PowerService::new(MockPowerBackend::unavailable());

        assert_eq!(
            service.read_state(),
            Err(PowerError::BackendUnavailable)
        );
    }
}
