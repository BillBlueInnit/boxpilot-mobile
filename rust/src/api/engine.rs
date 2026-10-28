//! The Flutter app's view of `boxpilot_core::Engine`.
//!
//! The engine is the same one the desktop app runs: it owns the state, the
//! scheduler and the Clash API client. The only difference is where sing-box
//! runs. Here the platform hosts libbox in its VPN service, and the engine
//! reaches it through Dart callbacks ([`DartHost`]).
//!
//! The engine lives for the whole process. A new Dart isolate (the activity was
//! recreated) calls [`init`] again and gets the running engine with fresh
//! callbacks and a fresh event sink.

use std::sync::{Arc, Mutex, OnceLock, RwLock};

use anyhow::{Context, Result, anyhow};
use boxpilot_core::clash_api::{Connection, ConnectionsSnapshot};
use boxpilot_core::config::CoreVersion;
use boxpilot_core::engine::{CoreHost, CoreStatus, Engine, Event, NoticeKind, ResetScope};
use boxpilot_core::model::{ProxyMode, Settings, Subscription};
use boxpilot_core::rules::RuleProvider;
use boxpilot_core::store::Paths;
use flutter_rust_bridge::DartFnFuture;
use futures_util::FutureExt;
use futures_util::future::BoxFuture;
use serde_json::Value;

use crate::frb_generated::StreamSink;

type StartFn = dyn Fn(String) -> DartFnFuture<String> + Send + Sync;
type StopFn = dyn Fn() -> DartFnFuture<()> + Send + Sync;

struct Callbacks {
    start: Box<StartFn>,
    stop: Box<StopFn>,
}

static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
static ENGINE: OnceLock<Arc<Engine>> = OnceLock::new();
static CALLBACKS: RwLock<Option<Arc<Callbacks>>> = RwLock::new(None);
static SINK: Mutex<Option<StreamSink<UiEvent>>> = Mutex::new(None);
static CORE_VERSION: OnceLock<CoreVersion> = OnceLock::new();

fn rt() -> &'static tokio::runtime::Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .thread_name("boxpilot")
            .build()
            .expect("tokio runtime")
    })
}

fn engine() -> Result<&'static Arc<Engine>> {
    ENGINE.get().ok_or_else(|| anyhow!("engine not initialised"))
}

fn callbacks() -> Option<Arc<Callbacks>> {
    CALLBACKS.read().unwrap().clone()
}

/// Starts and stops libbox through the Dart side.
struct DartHost;

impl CoreHost for DartHost {
    fn version(&self) -> CoreVersion {
        *CORE_VERSION.get().unwrap_or(&CoreVersion { major: 1, minor: 14, patch: 0 })
    }

    fn start(&self, config: String) -> BoxFuture<'static, Result<()>> {
        async move {
            let cb = callbacks().ok_or_else(|| anyhow!("the app is not attached"))?;
            // The platform answers with an empty string on success, else the error.
            let error = (cb.start)(config).await;
            if error.is_empty() { Ok(()) } else { Err(anyhow!(error)) }
        }
        .boxed()
    }

    fn stop(&self) -> BoxFuture<'static, ()> {
        async move {
            if let Some(cb) = callbacks() {
                (cb.stop)().await;
            }
        }
        .boxed()
    }
}

// ------------------------------------------------------------------ setup

/// Creates the engine (once per process) and attaches this isolate to it.
/// `root` is the data folder; `core_version` the embedded libbox version.
/// Returns `true` when an engine was already running (the UI came back).
pub fn init(
    root: String,
    core_version: String,
    start_core: impl Fn(String) -> DartFnFuture<String> + Send + Sync + 'static,
    stop_core: impl Fn() -> DartFnFuture<()> + Send + Sync + 'static,
) -> Result<bool> {
    *CALLBACKS.write().unwrap() = Some(Arc::new(Callbacks {
        start: Box::new(start_core),
        stop: Box::new(stop_core),
    }));
    if ENGINE.get().is_some() {
        return Ok(true);
    }
    init_logging();
    let version = CoreVersion::parse(&core_version).unwrap_or(CoreVersion { major: 1, minor: 14, patch: 0 });
    let _ = CORE_VERSION.set(version);
    let paths = Paths::at(root.into());
    paths.ensure()?;
    let (engine, mut rx) = Engine::with_host(rt().handle().clone(), paths, Arc::new(DartHost))?;
    let _ = ENGINE.set(engine.clone());
    rt().spawn(async move {
        while let Some(event) = rx.recv().await {
            if let Some(sink) = SINK.lock().unwrap().as_ref() {
                let _ = sink.add(UiEvent::from(event));
            }
        }
    });
    engine.startup();
    Ok(false)
}

/// Engine events for this isolate. Replaces an earlier isolate's stream.
pub fn events(sink: StreamSink<UiEvent>) {
    *SINK.lock().unwrap() = Some(sink);
}

fn init_logging() {
    #[cfg(target_os = "android")]
    android_logger::init_once(android_logger::Config::default().with_tag("BoxPilot").with_max_level(log::LevelFilter::Info));
    #[cfg(target_os = "ios")]
    let _ = oslog::OsLogger::new("io.github.billblueinnit.boxpilot").level_filter(log::LevelFilter::Info).init();
}

// ------------------------------------------------------------------ events

pub enum UiEvent {
    Status,
    Log,
    Traffic { up: i64, down: i64 },
    Subscriptions,
    Settings,
    CoreInfo,
    Proxies,
    Delays,
    RuleProviders,
    Notice { kind: NoticeLevel, key: String, args: Vec<String> },
}

pub enum NoticeLevel {
    Info,
    Success,
    Warning,
    Error,
}

impl From<Event> for UiEvent {
    fn from(e: Event) -> Self {
        match e {
            Event::Status => UiEvent::Status,
            Event::Log => UiEvent::Log,
            Event::Traffic(t) => UiEvent::Traffic { up: t.up as i64, down: t.down as i64 },
            Event::Subscriptions => UiEvent::Subscriptions,
            Event::Settings => UiEvent::Settings,
            Event::CoreInfo | Event::CoreDownload | Event::Update => UiEvent::CoreInfo,
            Event::Proxies => UiEvent::Proxies,
            Event::Delays => UiEvent::Delays,
            Event::RuleProviders => UiEvent::RuleProviders,
            Event::Notice(kind, msg) => UiEvent::Notice {
                kind: match kind {
                    NoticeKind::Info => NoticeLevel::Info,
                    NoticeKind::Success => NoticeLevel::Success,
                    NoticeKind::Warning => NoticeLevel::Warning,
                    NoticeKind::Error => NoticeLevel::Error,
                },
                key: msg.key.to_string(),
                args: msg.args,
            },
        }
    }
}

// ------------------------------------------------------------------ core

pub enum CoreState {
    Stopped,
    Starting,
    Running,
    Stopping,
    Failed(String),
}

#[flutter_rust_bridge::frb(sync)]
pub fn status() -> CoreState {
    match ENGINE.get().map(|e| e.status()).unwrap_or(CoreStatus::Stopped) {
        CoreStatus::Stopped => CoreState::Stopped,
        CoreStatus::Starting => CoreState::Starting,
        CoreStatus::Running => CoreState::Running,
        CoreStatus::Stopping => CoreState::Stopping,
        CoreStatus::Failed(m) => CoreState::Failed(m),
    }
}

pub async fn start() -> Result<()> {
    engine()?.start_async().await
}

#[flutter_rust_bridge::frb(sync)]
pub fn stop() -> Result<()> {
    engine()?.stop();
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn restart() -> Result<()> {
    engine()?.restart();
    Ok(())
}

/// The platform's core stopped on its own (VPN revoked, service killed).
#[flutter_rust_bridge::frb(sync)]
pub fn core_exited(reason: String) {
    if let Some(e) = ENGINE.get() {
        e.core_exited(reason);
    }
}

/// Log lines written by libbox.
#[flutter_rust_bridge::frb(sync)]
pub fn push_core_logs(lines: Vec<String>) {
    if let Some(e) = ENGINE.get() {
        for line in lines {
            e.push_core_log(&line);
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn core_version() -> String {
    ENGINE
        .get()
        .and_then(|e| e.core_version())
        .map(|v| v.to_string())
        .unwrap_or_default()
}

/// The configuration that would run now, pretty-printed.
#[flutter_rust_bridge::frb(sync)]
pub fn preview_config() -> Result<String> {
    Ok(serde_json::to_string_pretty(&engine()?.preview_config())?)
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_mode(mode: String) -> Result<()> {
    let mode = ProxyMode::parse(&mode).context("unknown mode")?;
    engine()?.set_mode(mode);
    Ok(())
}

pub struct TrafficSample {
    pub up: i64,
    pub down: i64,
}

#[flutter_rust_bridge::frb(sync)]
pub fn traffic() -> TrafficSample {
    let t = ENGINE.get().map(|e| e.traffic()).unwrap_or_default();
    TrafficSample { up: t.up as i64, down: t.down as i64 }
}

// ------------------------------------------------------------------ settings

/// Settings as JSON (the same file format as desktop).
#[flutter_rust_bridge::frb(sync)]
pub fn settings_json() -> Result<String> {
    Ok(serde_json::to_string(&engine()?.settings())?)
}

/// Merges `patch` (a JSON object of changed fields) into the settings.
#[flutter_rust_bridge::frb(sync)]
pub fn update_settings(patch: String) -> Result<()> {
    let patch: Value = serde_json::from_str(&patch)?;
    let mut merged = serde_json::to_value(engine()?.settings())?;
    if let (Some(base), Some(changes)) = (merged.as_object_mut(), patch.as_object()) {
        for (k, v) in changes {
            base.insert(k.clone(), v.clone());
        }
    }
    let new: Settings = serde_json::from_value(merged).context("invalid settings")?;
    engine()?.update_settings(move |s| *s = new);
    Ok(())
}

pub struct ResetParts {
    pub settings: bool,
    pub subscriptions: bool,
    pub rule_sets: bool,
    pub caches: bool,
}

/// Deletes the chosen data. The core is stopped; the app should restart.
pub fn reset(parts: ResetParts) -> Result<()> {
    engine()?.reset_blocking(ResetScope {
        settings: parts.settings,
        subscriptions: parts.subscriptions,
        rule_sets: parts.rule_sets,
        caches: parts.caches,
    });
    Ok(())
}

// ------------------------------------------------------------- subscriptions

#[flutter_rust_bridge::frb(sync)]
pub fn subscriptions_json() -> Result<String> {
    Ok(serde_json::to_string(&engine()?.subscriptions())?)
}

#[flutter_rust_bridge::frb(sync)]
pub fn updating_subscriptions() -> Vec<String> {
    ENGINE
        .get()
        .map(|e| e.subscriptions().into_iter().filter(|s| e.is_updating(&s.id)).map(|s| s.id).collect())
        .unwrap_or_default()
}

/// Adds a subscription from JSON. With `content` it is a local one (pasted text).
pub async fn add_subscription(json: String, content: Option<String>) -> Result<String> {
    let sub: Subscription = serde_json::from_str(&json)?;
    let e = engine()?.clone();
    tokio_blocking(move || e.add_subscription(sub, content)).await
}

/// Saves an edited subscription (same id). `content` replaces a local one's text.
pub async fn save_subscription(json: String, content: Option<String>) -> Result<()> {
    let sub: Subscription = serde_json::from_str(&json)?;
    let e = engine()?.clone();
    tokio_blocking(move || e.save_subscription(sub, content)).await
}

#[flutter_rust_bridge::frb(sync)]
pub fn remove_subscriptions(ids: Vec<String>) -> Result<()> {
    engine()?.remove_subscriptions(&ids);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_subscriptions_enabled(ids: Vec<String>, enabled: bool) -> Result<()> {
    engine()?.set_subscriptions_enabled(&ids, enabled);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_subscriptions(ids: Vec<String>) -> Result<()> {
    engine()?.update_subscriptions(&ids);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_all_subscriptions() -> Result<()> {
    engine()?.update_all();
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn move_subscription(id: String, delta: i32) -> Result<()> {
    engine()?.move_subscription(&id, delta as isize);
    Ok(())
}

pub struct NodeInfo {
    pub name: String,
    pub protocol: String,
    pub server: String,
    pub port: u16,
}

#[flutter_rust_bridge::frb(sync)]
pub fn nodes(subscription_id: String) -> Vec<NodeInfo> {
    ENGINE
        .get()
        .map(|e| {
            e.nodes(&subscription_id)
                .into_iter()
                .map(|n| NodeInfo { name: n.name, protocol: n.protocol, server: n.server, port: n.port })
                .collect()
        })
        .unwrap_or_default()
}

#[flutter_rust_bridge::frb(sync)]
pub fn total_nodes() -> u32 {
    ENGINE.get().map(|e| e.total_nodes() as u32).unwrap_or(0)
}

// ------------------------------------------------------------------ proxies

pub struct Member {
    pub name: String,
    pub protocol: String,
    pub is_group: bool,
    /// Clash API latency: `None` untested, `Some(-1)` failed, else ms.
    pub delay: Option<i32>,
    /// Real-connection latency from the speed test, same encoding.
    pub real_delay: Option<i32>,
    pub testing: bool,
    /// Download speed in bytes per second, when measured.
    pub speed: Option<i64>,
    pub speed_testing: bool,
    /// ISO country code.
    pub country: Option<String>,
}

pub struct Group {
    pub name: String,
    /// `Selector` or `URLTest`.
    pub kind: String,
    pub now: String,
    pub selectable: bool,
    pub members: Vec<Member>,
}

fn encode_delay(d: Option<Option<u32>>) -> Option<i32> {
    d.map(|d| d.map(|ms| ms.min(i32::MAX as u32) as i32).unwrap_or(-1))
}

#[flutter_rust_bridge::frb(sync)]
pub fn groups() -> Vec<Group> {
    let Some(e) = ENGINE.get() else { return Vec::new() };
    e.groups()
        .into_iter()
        .map(|g| Group {
            selectable: g.selectable(),
            members: g
                .members
                .iter()
                .map(|m| {
                    let speed = e.speed(&m.name);
                    Member {
                        delay: encode_delay(e.delay(&m.name)),
                        real_delay: encode_delay(e.real_delay(&m.name)),
                        testing: e.is_testing(&m.name) || e.is_real_testing(&m.name),
                        speed: speed.and_then(|s| s.bytes_per_sec).map(|b| b as i64),
                        speed_testing: e.is_speed_testing(&m.name),
                        country: e.country(&m.name).map(|c| c.code),
                        name: m.name.clone(),
                        protocol: m.protocol.clone(),
                        is_group: m.is_group,
                    }
                })
                .collect(),
            name: g.name,
            kind: g.kind,
            now: g.now,
        })
        .collect()
}

#[flutter_rust_bridge::frb(sync)]
pub fn select_proxy(group: String, name: String) -> Result<()> {
    engine()?.select_proxy(&group, &name);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn test_delays(names: Vec<String>) -> Result<()> {
    engine()?.test_delays(names);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn test_real_latency(names: Vec<String>) -> Result<()> {
    engine()?.test_real_latency(names);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn speed_test(names: Vec<String>) -> Result<()> {
    engine()?.speed_test(names);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn refresh_proxies() -> Result<()> {
    engine()?.refresh_proxies();
    Ok(())
}

pub struct CountryCount {
    pub code: String,
    pub nodes: u32,
}

#[flutter_rust_bridge::frb(sync)]
pub fn country_counts() -> Vec<CountryCount> {
    ENGINE
        .get()
        .map(|e| {
            e.country_counts()
                .into_iter()
                .map(|(code, n)| CountryCount { code, nodes: n as u32 })
                .collect()
        })
        .unwrap_or_default()
}

// ------------------------------------------------------------------ rules

#[flutter_rust_bridge::frb(sync)]
pub fn rule_providers_json() -> Result<String> {
    Ok(serde_json::to_string(&engine()?.rule_providers())?)
}

/// Adds or saves a rule-set from JSON; returns its id. It is fetched right away.
#[flutter_rust_bridge::frb(sync)]
pub fn save_rule_provider(json: String) -> Result<String> {
    let p: RuleProvider = serde_json::from_str(&json)?;
    Ok(engine()?.save_rule_provider(p))
}

#[flutter_rust_bridge::frb(sync)]
pub fn remove_rule_providers(ids: Vec<String>) -> Result<()> {
    engine()?.remove_rule_providers(&ids);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_rule_providers_enabled(ids: Vec<String>, enabled: bool) -> Result<()> {
    engine()?.set_rule_providers_enabled(&ids, enabled);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_rule_providers(ids: Vec<String>) -> Result<()> {
    engine()?.update_rule_providers(&ids);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn move_rule_provider(id: String, delta: i32) -> Result<()> {
    engine()?.move_rule_provider(&id, delta as isize);
    Ok(())
}

/// Imports every `ruleset=` of a subconverter `.ini` (URL or text). Returns how many.
pub async fn import_acl_ini(source: String) -> Result<u32> {
    Ok(engine()?.import_acl_ini(&source).await? as u32)
}

// ------------------------------------------------------------------ logs

pub struct LogEntry {
    /// Local time of day in seconds.
    pub time: u32,
    /// 0 trace … 4 error.
    pub level: u8,
    pub message: String,
}

/// Buffered log lines; `skip` drops the first ones the UI already has.
#[flutter_rust_bridge::frb(sync)]
pub fn logs(skip: u32) -> Vec<LogEntry> {
    ENGINE
        .get()
        .map(|e| {
            e.logs()
                .into_iter()
                .skip(skip as usize)
                .map(|l| LogEntry { time: l.time, level: l.level as u8, message: l.message.to_string() })
                .collect()
        })
        .unwrap_or_default()
}

#[flutter_rust_bridge::frb(sync)]
pub fn clear_logs() {
    if let Some(e) = ENGINE.get() {
        e.clear_logs();
    }
}

// ------------------------------------------------------------- connections

pub struct ConnectionInfo {
    pub id: String,
    pub network: String,
    pub target: String,
    pub process: String,
    pub outbound: String,
    pub chains: Vec<String>,
    pub rule: String,
    pub upload: i64,
    pub download: i64,
    /// RFC 3339 start time.
    pub start: String,
}

pub struct Connections {
    pub upload_total: i64,
    pub download_total: i64,
    pub memory: i64,
    pub items: Vec<ConnectionInfo>,
}

fn connection_info(c: &Connection) -> ConnectionInfo {
    ConnectionInfo {
        id: c.id.clone(),
        network: c.metadata.network.clone(),
        target: c.target(),
        process: c.process().to_string(),
        outbound: c.outbound().to_string(),
        chains: c.chains.clone(),
        rule: if c.rule_payload.is_empty() { c.rule.clone() } else { format!("{} ({})", c.rule, c.rule_payload) },
        upload: c.upload as i64,
        download: c.download as i64,
        start: c.start.clone(),
    }
}

pub async fn connections() -> Result<Connections> {
    let snap: ConnectionsSnapshot = engine()?.api().connections().await?;
    Ok(Connections {
        upload_total: snap.upload_total as i64,
        download_total: snap.download_total as i64,
        memory: snap.memory as i64,
        items: snap.connections.unwrap_or_default().iter().map(connection_info).collect(),
    })
}

pub async fn close_connection(id: String) -> Result<()> {
    engine()?.api().close_connection(&id).await
}

pub async fn close_all_connections() -> Result<()> {
    engine()?.api().close_all_connections().await
}

// ------------------------------------------------------------------ helpers

async fn tokio_blocking<T: Send + 'static>(f: impl FnOnce() -> Result<T> + Send + 'static) -> Result<T> {
    rt().spawn_blocking(f).await?
}
