//! JNI glue for `io.github.billblueinnit.boxpilot.core.Native`.
//!
//! The Kotlin side passes one `Host` object at start-up; the engine calls it to
//! start and stop libbox and to deliver events. It is a process-wide object,
//! not tied to an activity, so it stays valid when the UI is gone.

use jni::objects::{GlobalRef, JClass, JObject, JString, JValue};
use jni::sys::{jboolean, jstring};
use jni::{JNIEnv, JavaVM};

use crate::api::{self, Platform};

struct AndroidHost {
    vm: JavaVM,
    host: GlobalRef,
}

impl AndroidHost {
    /// Calls a `Host` method that takes at most one string, from any thread.
    fn call(&self, name: &str, sig: &str, text: Option<&str>) -> Option<String> {
        let mut env = self.vm.attach_current_thread().ok()?;
        let arg = match text {
            Some(t) => Some(env.new_string(t).ok()?),
            None => None,
        };
        let args: Vec<JValue> = arg.iter().map(|s| JValue::Object(s)).collect();
        let result = env.call_method(&self.host, name, sig, &args);
        if env.exception_check().unwrap_or(false) {
            let _ = env.exception_describe();
            let _ = env.exception_clear();
            return Some(format!("{name} failed in the app"));
        }
        let value = result.ok()?;
        if !sig.ends_with("Ljava/lang/String;") {
            return None;
        }
        let object = value.l().ok()?;
        let text: String = env.get_string(&JString::from(object)).ok()?.into();
        Some(text)
    }
}

impl Platform for AndroidHost {
    fn start_core(&self, config: String) -> String {
        self.call("startCore", "(Ljava/lang/String;)Ljava/lang/String;", Some(&config))
            .unwrap_or_else(|| "the VPN service did not answer".into())
    }

    fn stop_core(&self) {
        self.call("stopCore", "()V", None);
    }

    fn emit(&self, event: &str) {
        self.call("onEvent", "(Ljava/lang/String;)V", Some(event));
    }
}

fn text(env: &mut JNIEnv, s: &JString) -> String {
    env.get_string(s).map(Into::into).unwrap_or_default()
}

fn java_string(env: &mut JNIEnv, s: &str) -> jstring {
    env.new_string(s).map(|s| s.into_raw()).unwrap_or(std::ptr::null_mut())
}

/// `Native.init(root, coreVersion, vpnReady, host)`: `"true"` when the engine
/// was already running, `"false"` when it was created, else `"error: …"`.
#[unsafe(no_mangle)]
pub extern "system" fn Java_io_github_billblueinnit_boxpilot_core_Native_init<'l>(
    mut env: JNIEnv<'l>,
    _class: JClass<'l>,
    root: JString<'l>,
    core_version: JString<'l>,
    vpn_ready: jboolean,
    host: JObject<'l>,
) -> jstring {
    let root = text(&mut env, &root);
    let core_version = text(&mut env, &core_version);
    let platform = env
        .get_java_vm()
        .and_then(|vm| env.new_global_ref(host).map(|host| AndroidHost { vm, host }));
    let answer = match platform {
        Ok(platform) => match api::init(&root, &core_version, vpn_ready != 0, Box::new(platform)) {
            Ok(existing) => existing.to_string(),
            Err(e) => format!("error: {e:#}"),
        },
        Err(e) => format!("error: {e}"),
    };
    java_string(&mut env, &answer)
}

/// `Native.invoke(method, args)`: see [`api::invoke`].
#[unsafe(no_mangle)]
pub extern "system" fn Java_io_github_billblueinnit_boxpilot_core_Native_invoke<'l>(
    mut env: JNIEnv<'l>,
    _class: JClass<'l>,
    method: JString<'l>,
    args: JString<'l>,
) -> jstring {
    let method = text(&mut env, &method);
    let args = text(&mut env, &args);
    let answer = api::invoke(&method, &args);
    java_string(&mut env, &answer)
}

/// `Native.isRunning()`, for the tile.
#[unsafe(no_mangle)]
pub extern "system" fn Java_io_github_billblueinnit_boxpilot_core_Native_isRunning<'l>(
    _env: JNIEnv<'l>,
    _class: JClass<'l>,
) -> jboolean {
    api::is_running() as jboolean
}
