//! C ABI for iOS (`modules/boxpilot-core/ios/BoxpilotBridge.h`).
//!
//! Strings are NUL-terminated UTF-8. Strings returned to the app are freed
//! with [`boxpilot_free`]; the string `start` returns is the app's `strdup`
//! and is freed here with `free`.

use std::ffi::{CStr, CString, c_char, c_void};

use crate::api::{self, Platform};

/// Starts (or reloads) the core. Returns NULL or an empty string on success,
/// else a `strdup`ed error.
pub type StartFn = unsafe extern "C" fn(config: *const c_char) -> *mut c_char;
pub type StopFn = unsafe extern "C" fn();
pub type EventFn = unsafe extern "C" fn(event: *const c_char);

unsafe extern "C" {
    fn free(p: *mut c_void);
}

struct AppleHost {
    start: StartFn,
    stop: StopFn,
    event: EventFn,
}

impl Platform for AppleHost {
    fn start_core(&self, config: String) -> String {
        let Ok(config) = CString::new(config) else { return "invalid configuration".into() };
        // SAFETY: the app's callback returns NULL or a string it allocated with strdup.
        unsafe {
            let error = (self.start)(config.as_ptr());
            if error.is_null() {
                return String::new();
            }
            let text = CStr::from_ptr(error).to_string_lossy().into_owned();
            free(error.cast());
            text
        }
    }

    fn stop_core(&self) {
        // SAFETY: a plain callback into the app.
        unsafe { (self.stop)() }
    }

    fn emit(&self, event: &str) {
        if let Ok(event) = CString::new(event) {
            // SAFETY: the app copies the string before returning.
            unsafe { (self.event)(event.as_ptr()) }
        }
    }
}

/// # Safety
/// `p` is NULL or a NUL-terminated string.
unsafe fn text(p: *const c_char) -> String {
    if p.is_null() { String::new() } else { unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned() }
}

fn c_string(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

/// Creates the engine (once). Returns `"true"` when it was already running,
/// `"false"` when it was created, else `"error: …"`. Free with [`boxpilot_free`].
///
/// # Safety
/// `root` and `core_version` are NUL-terminated strings; the callbacks stay
/// valid for the life of the process.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn boxpilot_init(
    root: *const c_char,
    core_version: *const c_char,
    vpn_ready: bool,
    start: StartFn,
    stop: StopFn,
    event: EventFn,
) -> *mut c_char {
    let (root, core_version) = unsafe { (text(root), text(core_version)) };
    let host = AppleHost { start, stop, event };
    c_string(match api::init(&root, &core_version, vpn_ready, Box::new(host)) {
        Ok(existing) => existing.to_string(),
        Err(e) => format!("error: {e:#}"),
    })
}

/// See [`api::invoke`]. Free the answer with [`boxpilot_free`].
///
/// # Safety
/// `method` and `args` are NUL-terminated strings.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn boxpilot_invoke(method: *const c_char, args: *const c_char) -> *mut c_char {
    let (method, args) = unsafe { (text(method), text(args)) };
    c_string(api::invoke(&method, &args))
}

/// # Safety
/// `p` is NULL or a string this library returned.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn boxpilot_free(p: *mut c_char) {
    if !p.is_null() {
        drop(unsafe { CString::from_raw(p) });
    }
}
