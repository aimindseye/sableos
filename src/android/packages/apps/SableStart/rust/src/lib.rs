//! Native JNI bridge for SableStart.

use std::ffi::c_void;

struct LauncherState {
    #[allow(dead_code)]
    generation: u64,
}

/// Creates the native SableStart launcher state and returns its opaque handle.
#[no_mangle]
pub extern "C" fn
Java_org_sableos_start_bridge_SableStartNative_nativeCreate(
    _env: *mut c_void,
    _object: *mut c_void,
) -> i64 {
    let state = Box::new(
        LauncherState {
            generation: 0,
        },
    );

    Box::into_raw(state) as i64
}

/// Destroys a native launcher state previously returned by `nativeCreate`.
#[no_mangle]
pub extern "C" fn
Java_org_sableos_start_bridge_SableStartNative_nativeDestroy(
    _env: *mut c_void,
    _object: *mut c_void,
    handle: i64,
) {
    if handle == 0 {
        return;
    }

    // SAFETY: `handle` was created by `Box::into_raw` in `nativeCreate` and is consumed exactly once here.
    unsafe {
        drop(
            Box::from_raw(
                handle as *mut LauncherState,
            )
        );
    }
}
