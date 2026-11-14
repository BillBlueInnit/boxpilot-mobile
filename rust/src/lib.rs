//! The phone app's bridge to `boxpilot_core::Engine`.
//!
//! The engine is the same one the desktop app runs. The app talks to it through
//! one entry point, [`api::invoke`]: a method name and JSON arguments in, JSON
//! out. Engine events go the other way as JSON through [`api::Platform::emit`].
//! Nothing is generated, so following a new core version means adding a match
//! arm here and a typed wrapper in `src/core/engine.ts`.
//!
//! The platform glue is thin: JNI on Android ([`android`]), a C ABI on iOS
//! ([`ffi`]).

pub mod api;

#[cfg(target_os = "android")]
mod android;
#[cfg(not(target_os = "android"))]
mod ffi;
