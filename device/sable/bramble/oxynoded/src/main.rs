//! SableOS core daemon.
//!
//! B1 validates native Rust compilation and packaging for the
//! Pixel 4a 5G bramble platform.

use std::env;
use std::thread;
use std::time::Duration;

const VERSION: &str = "SableOS oxynoded B1";

fn main() {
    println!("[SableOS] {} starting", VERSION);

    if env::args().any(|arg| arg == "--probe") {
        println!("[SableOS] Rust userspace probe successful");
        println!("[SableOS] version={}", VERSION);
        return;
    }

    println!("[SableOS] entering idle daemon loop");

    loop {
        thread::sleep(Duration::from_secs(60));
    }
}
