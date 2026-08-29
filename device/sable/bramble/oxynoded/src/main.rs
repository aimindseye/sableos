//! SableOS core daemon.
//!
//! B2 begins the Sable semantic-service and hardware-adapter
//! architecture while preserving the validated B1.1 security boundary.

#[allow(dead_code)]
mod power;

use power::{MockPowerBackend, PowerService, PowerSource, PowerState};

use std::env;
use std::process;
use std::thread;
use std::time::Duration;

const VERSION: &str = "SableOS oxynoded B2";

fn run_power_mock_probe() {
    let backend = MockPowerBackend::with_state(PowerState {
        battery_percent: 42,
        charging: true,
        source: PowerSource::Usb,
    });

    let service = PowerService::new(backend);

    match service.read_state() {
        Ok(state) => {
            println!("[SableOS] power.read_state mock successful");
            println!(
                "[SableOS] battery_percent={}",
                state.battery_percent
            );
            println!("[SableOS] charging={}", state.charging);
            println!("[SableOS] source={:?}", state.source);
        }
        Err(error) => {
            eprintln!(
                "[SableOS] power.read_state mock failed: {:?}",
                error
            );
            process::exit(2);
        }
    }
}

fn main() {
    println!("[SableOS] {} starting", VERSION);

    if env::args().any(|arg| arg == "--probe") {
        println!("[SableOS] Rust userspace probe successful");
        println!("[SableOS] version={}", VERSION);
        return;
    }

    if env::args().any(|arg| arg == "--power-mock-probe") {
        run_power_mock_probe();
        return;
    }

    println!("[SableOS] entering idle daemon loop");

    loop {
        thread::sleep(Duration::from_secs(60));
    }
}
