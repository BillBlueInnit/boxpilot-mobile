//! Method dispatch over the engine, free of any platform code.
//!
//! The engine lives for the whole process. On Android that is longer than the
//! JavaScript runtime: the VPN service keeps the process alive after the UI is
//! closed, and the engine, its scheduler and the host callbacks keep working.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock};

use anyhow::{Context, Result, anyhow, bail};
use boxpilot_core::clash_api::Connection;
use boxpilot_core::config::CoreVersion;
use boxpilot_core::convert;
use boxpilot_core::engine::{CoreHost, CoreStatus, Engine, Event, NoticeKind, ResetScope};
use boxpilot_core::geo::Origin;
use boxpilot_core::model::{AutoStrategy, LOCAL_NODES_ID, ProxyMode, Settings, Subscription};
use boxpilot_core::rules::{
    self, CustomRuleKind, RuleMatchLayer, RuleProfile, RuleProvider, SERVICE_PRESETS, ServiceCategory,
};
use boxpilot_core::store::Paths;
use futures_util::FutureExt;
use futures_util::future::BoxFuture;
use serde::de::DeserializeOwned;
use serde_json::{Value, json};

/// What the platform does for the engine.
pub trait Platform: Send + Sync + 'static {
    /// Starts (or reloads) the embedded core with this configuration. Blocks
    /// until the platform accepted it. Returns an empty string, or the error.
    fn start_core(&self, config: String) -> String;
    fn stop_core(&self);
    /// An engine event as JSON, for the UI.
    fn emit(&self, event: &str);
}

static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
static ENGINE: OnceLock<Arc<Engine>> = OnceLock::new();
static PLATFORM: OnceLock<Box<dyn Platform>> = OnceLock::new();
static CORE_VERSION: OnceLock<CoreVersion> = OnceLock::new();
/// Whether the platform's VPN permission is granted.
static VPN_READY: AtomicBool = AtomicBool::new(false);

const FALLBACK_VERSION: CoreVersion = CoreVersion { major: 1, minor: 14, patch: 0 };

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

/// Starts and stops libbox through the platform.
struct Host;

impl CoreHost for Host {
    fn version(&self) -> CoreVersion {
        *CORE_VERSION.get().unwrap_or(&FALLBACK_VERSION)
    }

    fn start(&self, config: String) -> BoxFuture<'static, Result<()>> {
        async move {
            let platform = PLATFORM.get().ok_or_else(|| anyhow!("no platform"))?;
            let error = tokio::task::spawn_blocking(move || platform.start_core(config)).await?;
            if error.is_empty() { Ok(()) } else { Err(anyhow!(error)) }
        }
        .boxed()
    }

    fn stop(&self) -> BoxFuture<'static, ()> {
        async move {
            if let Some(platform) = PLATFORM.get() {
                let _ = tokio::task::spawn_blocking(move || platform.stop_core()).await;
            }
        }
        .boxed()
    }

    /// libbox is built without naive (it links a whole browser network stack);
    /// see scripts/build_libbox.sh.
    fn supports(&self, protocol: &str) -> bool {
        protocol != "naive"
    }

    fn can_autostart(&self) -> bool {
        VPN_READY.load(Ordering::Relaxed)
    }
}

/// Creates the engine, once per process. `root` is the data folder,
/// `core_version` the embedded libbox version, `vpn_ready` whether VPN
/// permission is already granted (only then does "connect on launch" connect:
/// a permission prompt needs the user's tap). Returns `true` when the engine
/// was already running (the UI came back to a live process).
pub fn init(root: &str, core_version: &str, vpn_ready: bool, platform: Box<dyn Platform>) -> Result<bool> {
    VPN_READY.store(vpn_ready, Ordering::Relaxed);
    if ENGINE.get().is_some() {
        return Ok(true);
    }
    init_logging();
    let _ = PLATFORM.set(platform);
    let _ = CORE_VERSION.set(CoreVersion::parse(core_version).unwrap_or(FALLBACK_VERSION));
    let paths = Paths::at(root.into());
    paths.ensure()?;
    let (engine, mut rx) = Engine::with_host(rt().handle().clone(), paths, Arc::new(Host))?;
    let _ = ENGINE.set(engine.clone());
    rt().spawn(async move {
        while let Some(event) = rx.recv().await {
            if let Some(platform) = PLATFORM.get() {
                platform.emit(&event_json(event).to_string());
            }
        }
    });
    engine.startup();
    Ok(false)
}

fn init_logging() {
    #[cfg(target_os = "android")]
    android_logger::init_once(
        android_logger::Config::default().with_tag("BoxPilot").with_max_level(log::LevelFilter::Info),
    );
    #[cfg(target_os = "ios")]
    let _ = oslog::OsLogger::new("io.github.billblueinnit.boxpilot").level_filter(log::LevelFilter::Info).init();
}

fn event_json(e: Event) -> Value {
    match e {
        Event::Status => json!({"type": "status"}),
        Event::Log => json!({"type": "log"}),
        Event::Traffic(t) => json!({"type": "traffic", "up": t.up, "down": t.down}),
        Event::Subscriptions => json!({"type": "subscriptions"}),
        Event::Settings => json!({"type": "settings"}),
        Event::CoreInfo | Event::CoreDownload | Event::Update => json!({"type": "coreInfo"}),
        Event::Proxies => json!({"type": "proxies"}),
        Event::Delays => json!({"type": "delays"}),
        Event::RuleProviders => json!({"type": "ruleProviders"}),
        Event::Notice(kind, msg) => json!({
            "type": "notice",
            "kind": match kind {
                NoticeKind::Info => "info",
                NoticeKind::Success => "success",
                NoticeKind::Warning => "warning",
                NoticeKind::Error => "error",
            },
            "key": msg.key,
            "args": msg.args,
        }),
    }
}

/// Calls `method` with JSON `args`. Returns `{"ok": value}` or `{"error": text}`.
/// Blocks the calling thread, so the platform calls it off its main thread.
pub fn invoke(method: &str, args: &str) -> String {
    let result = serde_json::from_str::<Value>(if args.is_empty() { "null" } else { args })
        .map_err(anyhow::Error::from)
        .and_then(|args| call(method, args));
    match result {
        Ok(value) => json!({ "ok": value }),
        Err(e) => json!({ "error": format!("{e:#}") }),
    }
    .to_string()
}

/// The platform's VPN permission changed (granted on Connect, revoked in Settings).
pub fn set_vpn_ready(ready: bool) {
    VPN_READY.store(ready, Ordering::Relaxed);
}

/// The status as the tile and the notification need it, without JSON.
pub fn is_running() -> bool {
    ENGINE.get().is_some_and(|e| e.status().is_running())
}

fn arg<T: DeserializeOwned>(args: &Value, name: &str) -> Result<T> {
    serde_json::from_value(args.get(name).cloned().unwrap_or(Value::Null))
        .with_context(|| format!("argument `{name}`"))
}

fn ids(args: &Value) -> Result<Vec<String>> {
    arg(args, "ids")
}

fn call(method: &str, a: Value) -> Result<Value> {
    let e = engine()?;
    Ok(match method {
        // ------------------------------------------------------------ core
        "status" => status(e),
        "start" => {
            rt().block_on(e.start_async())?;
            Value::Null
        }
        "stop" => {
            e.stop();
            Value::Null
        }
        "restart" => {
            e.restart();
            Value::Null
        }
        // The platform's core stopped on its own (VPN revoked, service killed).
        "coreExited" => {
            e.core_exited(arg::<String>(&a, "reason")?);
            Value::Null
        }
        "coreVersion" => json!(e.core_version().map(|v| v.to_string()).unwrap_or_default()),
        "previewConfig" => json!(serde_json::to_string_pretty(&e.preview_config())?),
        "setMode" => {
            let mode: String = arg(&a, "mode")?;
            e.set_mode(ProxyMode::parse(&mode).context("unknown mode")?);
            Value::Null
        }
        "traffic" => {
            let t = e.traffic();
            json!({"up": t.up, "down": t.down})
        }
        "setVpnReady" => {
            set_vpn_ready(arg(&a, "ready")?);
            Value::Null
        }

        // -------------------------------------------------------- settings
        "settings" => serde_json::to_value(e.settings())?,
        // Merges `patch` (changed fields) into the settings. Custom rules are
        // not settings: the file `CustomRule.list` is what counts.
        "updateSettings" => {
            let mut merged = serde_json::to_value(e.settings())?;
            let patch: Value = arg(&a, "patch")?;
            if let (Some(base), Some(changes)) = (merged.as_object_mut(), patch.as_object()) {
                for (k, v) in changes {
                    if k != "custom_rules" {
                        base.insert(k.clone(), v.clone());
                    }
                }
            }
            let new: Settings = serde_json::from_value(merged).context("invalid settings")?;
            e.update_settings(move |s| *s = new);
            Value::Null
        }
        // Deletes the chosen data. The core is stopped; the app should restart.
        "reset" => {
            e.reset_blocking(ResetScope {
                settings: arg(&a, "settings")?,
                subscriptions: arg(&a, "subscriptions")?,
                rule_sets: arg(&a, "rule_sets")?,
                caches: arg(&a, "caches")?,
            });
            Value::Null
        }

        // --------------------------------------------------- subscriptions
        "subscriptions" => {
            let items = e.subscriptions();
            let local = e.local_group();
            let updating: Vec<&str> = items
                .iter()
                .chain(local.iter())
                .filter(|s| e.is_updating(&s.id))
                .map(|s| s.id.as_str())
                .collect();
            json!({"items": items, "local": local, "updating": updating, "total_nodes": e.total_nodes()})
        }
        // With `content` it is a local one (pasted text). Returns the new id.
        "addSubscription" => {
            let sub: Subscription = arg(&a, "sub")?;
            json!(e.add_subscription(sub, arg(&a, "content")?)?)
        }
        "saveSubscription" => {
            let sub: Subscription = arg(&a, "sub")?;
            e.save_subscription(sub, arg(&a, "content")?)?;
            Value::Null
        }
        "removeSubscriptions" => {
            e.remove_subscriptions(&ids(&a)?);
            Value::Null
        }
        "setSubscriptionsEnabled" => {
            e.set_subscriptions_enabled(&ids(&a)?, arg(&a, "enabled")?);
            Value::Null
        }
        "updateSubscriptions" => {
            e.update_subscriptions(&ids(&a)?);
            Value::Null
        }
        "updateAllSubscriptions" => {
            e.update_all();
            Value::Null
        }
        "moveSubscription" => {
            e.move_subscription(&arg::<String>(&a, "id")?, arg::<i64>(&a, "delta")? as isize);
            Value::Null
        }
        "nodes" => {
            let id: String = arg(&a, "id")?;
            e.nodes(&id)
                .into_iter()
                .map(|n| json!({"name": n.name, "protocol": n.protocol, "server": n.server, "port": n.port}))
                .collect()
        }
        // Nodes added one by one, from anything a subscription can be.
        "addLocalNodes" => {
            let (added, skipped) = e.add_local_nodes(&arg::<String>(&a, "text")?)?;
            json!({"added": added, "skipped": skipped})
        }
        "removeLocalNode" => {
            e.remove_local_node(arg::<u64>(&a, "index")? as usize)?;
            Value::Null
        }
        // One node of a subscription (or of Local nodes) as a share link.
        "shareNode" => {
            let id: String = arg(&a, "id")?;
            let index = arg::<u64>(&a, "index")? as usize;
            let nodes = e.nodes(&id);
            let node = nodes.get(index).context("no such node")?;
            json!(convert::share_link(node).map_err(|m| anyhow!(m))?)
        }
        // Every node of a subscription, one link per line.
        "shareSubscription" => {
            let (text, skipped) = convert::share_links(&e.nodes(&arg::<String>(&a, "id")?));
            json!({"text": text, "skipped": skipped})
        }
        // A node of the running configuration, by its outbound tag.
        "shareLinkFor" => json!(e.share_link_for(&arg::<String>(&a, "tag")?)?),

        // --------------------------------------------------------- proxies
        "groups" => groups(e),
        "selectProxy" => {
            e.select_proxy(&arg::<String>(&a, "group")?, &arg::<String>(&a, "name")?);
            Value::Null
        }
        "testDelays" => {
            e.test_delays(arg(&a, "names")?);
            Value::Null
        }
        "testRealLatency" => {
            e.test_real_latency(arg(&a, "names")?);
            Value::Null
        }
        "speedTest" => {
            e.speed_test(arg(&a, "names")?);
            Value::Null
        }
        "cancelSpeedTest" => {
            e.cancel_speed_test();
            Value::Null
        }
        "refreshProxies" => {
            e.refresh_proxies();
            Value::Null
        }
        "countryCounts" => {
            e.country_counts().into_iter().map(|(code, nodes)| json!({"code": code, "nodes": nodes})).collect()
        }

        // ----------------------------------------------------------- rules
        "ruleProviders" => serde_json::to_value(e.rule_providers())?,
        // Adds or saves a rule-set; returns its id. It is fetched right away.
        "saveRuleProvider" => {
            let p: RuleProvider = arg(&a, "provider")?;
            json!(e.save_rule_provider(p))
        }
        "removeRuleProviders" => {
            e.remove_rule_providers(&ids(&a)?);
            Value::Null
        }
        "setRuleProvidersEnabled" => {
            e.set_rule_providers_enabled(&ids(&a)?, arg(&a, "enabled")?);
            Value::Null
        }
        "updateRuleProviders" => {
            e.update_rule_providers(&ids(&a)?);
            Value::Null
        }
        "moveRuleProvider" => {
            e.move_rule_provider(&arg::<String>(&a, "id")?, arg::<i64>(&a, "delta")? as isize);
            Value::Null
        }
        // Imports every `ruleset=` of a subconverter `.ini` (URL or text). Returns how many.
        "importAclIni" => json!(rt().block_on(e.import_acl_ini(&arg::<String>(&a, "source")?))?),
        // A node group of its own for a rule-set (a config change: the core reloads).
        "setRuleProviderGroup" => {
            e.set_rule_provider_group(&arg::<String>(&a, "id")?, arg(&a, "on")?);
            Value::Null
        }
        // Unified target + own_group update for a rule-set.
        "setRuleProviderTarget" => {
            e.set_rule_provider_target(
                &arg::<String>(&a, "id")?,
                arg::<String>(&a, "target")?,
                arg::<bool>(&a, "own_group")?,
            );
            Value::Null
        }
        // The Proxies group tag for a rule-set's own group, if active.
        "ruleGroupTagFor" => json!(e.rule_group_tag_for(&arg::<String>(&a, "id")?)),
        // Curated built-in service presets and whether each is currently added.
        "servicePresets" => SERVICE_PRESETS
            .iter()
            .map(|p| {
                json!({
                    "id": p.id,
                    "category": service_category_id(p.category),
                    "name": p.name,
                    "geosite": p.geosite,
                    "default_target": p.default_target,
                    "default_own_group": p.default_own_group,
                    "added": e.has_service_preset(p.id),
                })
            })
            .collect(),
        "addServicePreset" => json!(e.add_service_preset(&arg::<String>(&a, "id")?)),
        "removeServicePreset" => {
            e.remove_service_preset(&arg::<String>(&a, "id")?);
            Value::Null
        }
        // One-click routing profiles.
        "activeRuleProfile" => json!(e.active_rule_profile().map(rule_profile_id)),
        "applyRuleProfile" => {
            let id: String = arg(&a, "profile")?;
            let profile = parse_rule_profile(&id).context("unknown rule profile")?;
            e.apply_rule_profile(profile);
            Value::Null
        }
        // How that group picks its node: null for by hand, else an Auto mode. Live.
        "setRuleGroupPick" => {
            let pick: Option<AutoStrategy> = arg(&a, "pick")?;
            e.set_rule_group_pick(&arg::<String>(&a, "id")?, pick, &arg::<String>(&a, "region")?);
            Value::Null
        }
        // The rule-set's text for the in-app editor; null for binary rule-sets
        // and ones not downloaded yet.
        "ruleProviderText" => match e.rule_provider_text_file(&arg::<String>(&a, "id")?) {
            Some((path, local)) => json!({"text": std::fs::read_to_string(path)?, "local_source": local}),
            None => Value::Null,
        },
        // A local source is converted again; the core reloads a stored copy by itself.
        "saveRuleProviderText" => {
            let id: String = arg(&a, "id")?;
            let (path, local) = e.rule_provider_text_file(&id).context("this rule-set has no text file")?;
            std::fs::write(path, arg::<String>(&a, "text")?)?;
            if local {
                e.update_rule_provider(&id);
            }
            Value::Null
        }
        "customRules" => json!(e.settings().custom_rules),
        "setCustomRules" => {
            e.set_custom_rules(arg(&a, "text")?)?;
            Value::Null
        }
        "customRulesParsed" => e
            .custom_rules_parsed()
            .into_iter()
            .map(|r| {
                json!({
                    "line_index": r.line_index,
                    "kind": r.kind.map(CustomRuleKind::token),
                    "kind_raw": r.kind_raw,
                    "value": r.value,
                    "target": r.target,
                    "enabled": r.enabled,
                    "raw": r.raw,
                    "error": r.error,
                    "group": r.group,
                })
            })
            .collect(),
        "addStructuredCustomRule" => {
            let kind_str: String = arg(&a, "kind")?;
            let kind = CustomRuleKind::parse(&kind_str).context("unknown custom rule kind")?;
            let value: String = arg(&a, "value")?;
            let target: String = arg(&a, "target")?;
            json!(e.add_structured_custom_rule(kind, &value, &target)?)
        }
        "updateCustomRule" => {
            let line_index = arg::<u64>(&a, "line_index")? as usize;
            let kind_str: String = arg(&a, "kind")?;
            let kind = CustomRuleKind::parse(&kind_str).context("unknown custom rule kind")?;
            let value: String = arg(&a, "value")?;
            let target: String = arg(&a, "target")?;
            let enabled: bool = arg(&a, "enabled")?;
            e.update_custom_rule(line_index, kind, &value, &target, enabled)?;
            Value::Null
        }
        "setCustomRuleEnabled" => {
            let line_index = arg::<u64>(&a, "line_index")? as usize;
            e.set_custom_rule_enabled(line_index, arg(&a, "enabled")?)?;
            Value::Null
        }
        "removeCustomRule" => {
            let line_index = arg::<u64>(&a, "line_index")? as usize;
            e.remove_custom_rule(line_index)?;
            Value::Null
        }
        "moveCustomRule" => {
            let line_index = arg::<u64>(&a, "line_index")? as usize;
            e.move_custom_rule(line_index, arg::<i64>(&a, "delta")? as isize)?;
            Value::Null
        }
        // Named custom rule groups (with optional independent node groups on Proxies).
        "customRuleGroups" => serde_json::to_value(e.custom_rule_groups())?,
        "createCustomRuleGroup" => {
            let name: String = arg(&a, "name")?;
            let target: String = arg(&a, "target")?;
            let own_group: bool = arg(&a, "own_group")?;
            json!(e.create_custom_rule_group(name, target, own_group)?)
        }
        "renameCustomRuleGroup" => {
            e.rename_custom_rule_group(&arg::<String>(&a, "id")?, arg::<String>(&a, "name")?)?;
            Value::Null
        }
        "setCustomRuleGroupTarget" => {
            e.set_custom_rule_group_target(
                &arg::<String>(&a, "id")?,
                arg::<String>(&a, "target")?,
                arg::<bool>(&a, "own_group")?,
            );
            Value::Null
        }
        "setCustomRuleGroupEnabled" => {
            e.set_custom_rule_group_enabled(&arg::<String>(&a, "id")?, arg(&a, "enabled")?);
            Value::Null
        }
        "moveCustomRuleGroup" => {
            e.move_custom_rule_group(&arg::<String>(&a, "id")?, arg::<i64>(&a, "delta")? as isize);
            Value::Null
        }
        "removeCustomRuleGroup" => {
            e.remove_custom_rule_group(&arg::<String>(&a, "id")?);
            Value::Null
        }
        "customRuleGroupTagFor" => json!(e.custom_rule_group_tag_for(&arg::<String>(&a, "id")?)),
        "setCustomRuleGroupPick" => {
            let pick: Option<AutoStrategy> = arg(&a, "pick")?;
            e.set_custom_rule_group_pick(&arg::<String>(&a, "id")?, pick, &arg::<String>(&a, "region")?);
            Value::Null
        }
        "addStructuredCustomRuleInGroup" => {
            let kind_str: String = arg(&a, "kind")?;
            let kind = CustomRuleKind::parse(&kind_str).context("unknown custom rule kind")?;
            let value: String = arg(&a, "value")?;
            let target: String = arg(&a, "target")?;
            let group_id: Option<String> = arg(&a, "group_id")?;
            json!(e.add_structured_custom_rule_in_group(kind, &value, &target, group_id.as_deref())?)
        }
        "moveCustomRuleToGroup" => {
            let line_index = arg::<u64>(&a, "line_index")? as usize;
            let group_id: Option<String> = arg(&a, "group_id")?;
            e.move_custom_rule_to_group(line_index, group_id.as_deref())?;
            Value::Null
        }
        // Offline rule match simulator in exact routing priority order.
        "testRuleMatch" => match e.test_rule_match(&arg::<String>(&a, "query")?) {
            Some(res) => {
                let layer = match res.layer {
                    RuleMatchLayer::PrivateIp => json!({"kind": "private_ip"}),
                    RuleMatchLayer::CustomRule { line_index } => {
                        json!({"kind": "custom_rule", "line_index": line_index})
                    }
                    RuleMatchLayer::CustomGroup { id, name } => {
                        json!({"kind": "custom_group", "id": id, "name": name})
                    }
                    RuleMatchLayer::RuleSet { id, name } => json!({"kind": "rule_set", "id": id, "name": name}),
                    RuleMatchLayer::BuiltIn { name } => json!({"kind": "built_in", "name": name}),
                    RuleMatchLayer::Fallback => json!({"kind": "fallback"}),
                };
                json!({
                    "query": res.query,
                    "layer": layer,
                    "rule": res.rule,
                    "target": res.target,
                    "approximate": res.approximate,
                })
            }
            None => Value::Null,
        },
        // `TYPE,VALUE,TARGET`; replaces a rule for the same type and value.
        // False when it is already there. The core reloads to apply it.
        "addCustomRule" => json!(e.add_custom_rule(&arg::<String>(&a, "rule")?)?),
        // `www.bbc.co.uk` -> `bbc.co.uk`, for "the whole site" rules.
        "baseDomain" => json!(rules::base_domain(&arg::<String>(&a, "host")?)),

        // ------------------------------------------------------------ logs
        // Buffered log lines; `skip` drops the first ones the UI already has.
        "logs" => {
            let skip = arg::<Option<u64>>(&a, "skip")?.unwrap_or(0) as usize;
            e.logs()
                .into_iter()
                .skip(skip)
                .map(|l| json!({"time": l.time, "level": l.level as u8, "message": &*l.message}))
                .collect()
        }
        "clearLogs" => {
            e.clear_logs();
            Value::Null
        }

        // ----------------------------------------------------- connections
        "connections" => {
            let snap = rt().block_on(e.api().connections())?;
            json!({
                "upload_total": snap.upload_total,
                "download_total": snap.download_total,
                "memory": snap.memory,
                "items": snap.connections.unwrap_or_default().iter().map(connection).collect::<Vec<_>>(),
            })
        }
        "closeConnection" => {
            rt().block_on(e.api().close_connection(&arg::<String>(&a, "id")?))?;
            Value::Null
        }
        "closeAllConnections" => {
            rt().block_on(e.api().close_all_connections())?;
            Value::Null
        }

        _ => bail!("unknown method `{method}`"),
    })
}

fn status(e: &Engine) -> Value {
    match e.status() {
        CoreStatus::Stopped => json!({"state": "stopped"}),
        CoreStatus::Starting => json!({"state": "starting"}),
        CoreStatus::Running => json!({"state": "running"}),
        CoreStatus::Stopping => json!({"state": "stopping"}),
        CoreStatus::Failed(m) => json!({"state": "failed", "error": m}),
    }
}

/// Latency for the UI: null untested, -1 failed, else ms.
fn delay(d: Option<Option<u32>>) -> Value {
    match d {
        None => Value::Null,
        Some(None) => json!(-1),
        Some(Some(ms)) => json!(ms),
    }
}

fn groups(e: &Engine) -> Value {
    e.groups()
        .into_iter()
        .map(|g| {
            let members: Vec<Value> = g
                .members
                .iter()
                .map(|m| {
                    let country = e.country(&m.name);
                    // How the country is known: by name, server GeoIP, or measured exit.
                    let (origin, ip) = match country.as_ref().map(|c| &c.origin) {
                        Some(Origin::Name) => (Some("name"), None),
                        Some(Origin::Ip(ip)) => (Some("ip"), Some(ip.to_string())),
                        Some(Origin::Exit(ip)) => (Some("exit"), Some(ip.to_string())),
                        None => (None, None),
                    };
                    json!({
                        "name": m.name,
                        "protocol": m.protocol,
                        "is_group": m.is_group,
                        "delay": delay(e.delay(&m.name)),
                        "real_delay": delay(e.real_delay(&m.name)),
                        "testing": e.is_testing(&m.name) || e.is_real_testing(&m.name),
                        "speed": e.speed(&m.name).and_then(|s| s.bytes_per_sec),
                        "speed_testing": e.is_speed_testing(&m.name),
                        "country": country.map(|c| c.code),
                        "country_origin": origin,
                        "country_ip": ip,
                    })
                })
                .collect();
            // A rule-set's or custom rule group's own node group: its picker lives on the Proxies page.
            let rule = e
                .rule_group(&g.name)
                .map(|p| json!({"id": p.id, "pick": p.pick, "region": p.region, "source": "rule_set"}))
                .or_else(|| {
                    e.custom_rule_group_for_tag(&g.name)
                        .map(|c| json!({"id": c.id, "pick": c.pick, "region": c.region, "source": "custom_group"}))
                });
            json!({
                "name": g.name,
                "kind": g.kind,
                "now": g.now,
                "selectable": g.selectable(),
                "local_nodes": g.name == boxpilot_core::model::LOCAL_NODES_NAME,
                "rule_group": rule,
                "members": members,
            })
        })
        .collect()
}

fn connection(c: &Connection) -> Value {
    json!({
        "id": c.id,
        "network": c.metadata.network,
        "target": c.target(),
        "host": c.metadata.host,
        "destination_ip": c.metadata.destination_ip,
        "process": c.process(),
        "outbound": c.outbound(),
        "chains": c.chains,
        "rule": if c.rule_payload.is_empty() { c.rule.clone() } else { format!("{} ({})", c.rule, c.rule_payload) },
        "upload": c.upload,
        "download": c.download,
        "start": c.start,
    })
}

/// The id of the "Local nodes" group, for hosts that need it without JSON.
pub const LOCAL_NODES: &str = LOCAL_NODES_ID;

fn service_category_id(cat: ServiceCategory) -> &'static str {
    match cat {
        ServiceCategory::AiDev => "ai_dev",
        ServiceCategory::Streaming => "streaming",
        ServiceCategory::SocialGaming => "social_gaming",
        ServiceCategory::DomesticPlatforms => "domestic",
        ServiceCategory::General => "general",
    }
}

fn rule_profile_id(p: RuleProfile) -> &'static str {
    match p {
        RuleProfile::Daily => "daily",
        RuleProfile::MinimalBypassCn => "minimal",
        RuleProfile::StreamingGaming => "streaming",
        RuleProfile::DirectFirst => "direct_first",
    }
}

fn parse_rule_profile(s: &str) -> Option<RuleProfile> {
    match s {
        "daily" => Some(RuleProfile::Daily),
        "minimal" => Some(RuleProfile::MinimalBypassCn),
        "streaming" => Some(RuleProfile::StreamingGaming),
        "direct_first" => Some(RuleProfile::DirectFirst),
        _ => None,
    }
}
