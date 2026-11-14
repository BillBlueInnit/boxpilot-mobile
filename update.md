# BoxPilot desktop → mobile update log

What changed in the desktop app ([BillBlueInnit/boxpilot](https://github.com/BillBlueInnit/boxpilot)),
newest first, so the mobile app can follow. Core changes (`crates/core`, the `boxpilot-core` crate)
arrive by moving the `boxpilot-core` rev in `rust/Cargo.toml`; UI items have to be ported by hand.

Each entry: **what** it is, **core** API to use, **mobile** notes.

---

## 1.0.4 — 2026-11-05

Desktop commit: `d041479` (tag `v1.0.4`, on GitHub). The core changed: moving
the `boxpilot-core` rev brings the ACL import fix and `CustomRule.list`. Read item 2 under New
features before moving it, because custom rules are saved differently now.

### New features

1. **Read and copy full log lines.** Log rows are one line high and long ones were cut off (the
   reason of a failed connection sat past the edge). Clicking a row now shows the whole line,
   wrapped, under the list, with **Copy** (time, level and message) and a close button; clicking
   the row again hides it. Mobile: make log rows expandable or long-press to copy — the cut-off
   part is usually the error.
2. **Custom rules live in `CustomRule.list`** in the data folder, one `TYPE,VALUE,TARGET` per line,
   not only in the settings. Older settings text moves to the file by itself on first start.
   Core: `Paths::custom_rules_file()`, `Engine::custom_rules_file()` (creates it, for opening in an
   editor), `Engine::set_custom_rules(text)`, `Engine::add_custom_rule(rule)`.
   `Settings::custom_rules` is now a copy of the file for building the config.
   Mobile: **save through `set_custom_rules`, never `update_settings(|s| s.custom_rules = ...)`.**
   The file wins at start-up, so a change made only in the settings is lost on the next launch. The
   loop that applies outside edits every 2 s runs only on desktop (`host.is_none()`); mobile has no
   outside editor and needs none.
3. **Right-click a connection to add a rule.** The menu offers Always go direct / Always use the
   proxy / Always block, each for the host, its whole site, the app, or the address when there is no
   host. It also has Copy address and Close connection. Core: `rules::base_domain(host)`
   (`www.bbc.co.uk` -> `bbc.co.uk`) and `Engine::add_custom_rule` (a rule for the same type and value
   is replaced in place; returns false if it is already there). The core reloads to apply a rule, so
   open connections drop. Mobile: same menu on long-press.
4. **Connections columns resize.** Drag the edge between titles, double-click it to fit the longest
   value, and scroll sideways when they outgrow the page. Widths are saved in
   `Settings::conn_columns` (empty means defaults). Mobile: phone screens probably want a detail view
   for each connection instead; the field can stay unused.

### Bug fixes

1. **Ghost window buttons (Windows, translucent window).** The Mica / Acrylic frame was extended
   over the whole window with margins of -1. A frame that includes the top edge gets DWM's own
   caption buttons drawn into it, and they showed through the translucent title bar behind
   BoxPilot's, as doubled minimize / maximize / close glyphs. The frame is now extended up from the
   bottom edge only: same backdrop pixel for pixel, no native buttons. Minimize, maximize and
   restore glyphs are also drawn on whole device pixels (Windows and Linux), so they stay sharp at
   125 % / 150 % scale. (Desktop only.)
2. **Dark outline around a light window (Windows).** Windows colours the 1 px window border after
   the *system* theme, so a light BoxPilot on a dark system had a dark frame. The border now takes
   the app theme (Fluent surface stroke: `#C1C1C1` light, `#424242` dark), unless the user shows
   the accent colour on window borders. Acrylic has no border at all: DWM can only draw it in one
   solid colour, and Acrylic shows whatever is behind the window, so the line stood out. On macOS
   the window's appearance now follows the app theme
   (frame, traffic lights, vibrancy); "System" hands it back to macOS. (Desktop only; on mobile the
   status bar and system UI should likewise follow the app theme, not only the system's.)
3. **ACL4SSR import sent "direct" groups to the proxy.** A group's first member decides the default,
   and it can be another group: ACL4SSR's Bilibili group starts with `[]🎯 全球直连`, which starts with
   `[]DIRECT`. Only a literal DIRECT was understood, so Bilibili went through a foreign node.
   `rules::parse_acl_ini` now follows the chain (a cycle falls back to proxy). Mobile: comes with the
   core. Rule-sets already imported keep their target, because a re-import skips sources it knows.

---

## 1.0.3 — 2026-10-31

Desktop commit: `a8fcda5` (tag `v1.0.3`, on GitHub). Linux-focused; nothing here needs porting, but
the core's process and permission code changed, so expect it when moving the `boxpilot-core` rev.

### New features

1. **Linux packages:** `.deb`, `.rpm` and an Arch pacman repository in the release. (Desktop only.)

### Bug fixes

1. **Linux TUN without a polkit agent** (niri, sway, Hyprland): passwordless sudo is tried after
   pkexec, then BoxPilot asks for the password itself. File capabilities are read from the xattr,
   and the core gets SIGTERM before SIGKILL so a TUN core can remove its routes. (Desktop only.)
2. **Linux window frame:** tiling compositors frame windows themselves, so BoxPilot draws no border
   of its own there; blur now also works on niri; the window no longer redraws without end when
   idle. (Desktop only.)

---

## 1.0.2 — 2026-10-29

Desktop commit: `a81ad50` (tag `v1.0.2`, on GitHub). To take it, set `rev = "a81ad50"` (or
`tag = "v1.0.2"`) for `boxpilot-core`. Checked on real machines by
the new live test (`crates/core/examples/platform_live.rs`, `.github/workflows/live.yml`): system
proxy, TUN, and TUN with the DNS server on the LAN, on macOS (arm64 and x64), Windows and Linux.

### Bug fixes

1. **macOS TUN didn't work behind a home router.** The router hands itself out as DNS; its subnet
   route is more specific than TUN's, so DNS skipped the core (poisoned or blocked answers in
   China). While TUN runs, every network service's DNS now points at the TUN peer `172.19.0.2`
   (`config::TUN_DNS`); the previous settings are saved to `run/dns.saved` first and restored on
   stop, failure, or the next start after a crash. The core's own system-resolver lookups
   (`local` DNS servers) go to the network's DNS meanwhile
   (`config::use_upstream_for_local_dns`). Core: `Engine` does it by itself on macOS
   (`sys::dns_settings` / `sys::set_dns_settings`). Routing the DNS server's address into TUN was
   tried and dropped: it breaks when the DNS server is also the gateway.
   Mobile: the VPN must hand the system a DNS server inside the tunnel — iOS
   `NEPacketTunnelNetworkSettings.dnsSettings = NEDNSSettings(servers: ["172.19.0.2"])` with
   `matchDomains = [""]`; Android `VpnService.Builder.addDnsServer("172.19.0.2")`. Check it with
   the DNS server on the LAN (most home Wi-Fi), not only with a public one.
2. **macOS system proxy didn't take on some Macs.** When the setting doesn't take after
   `networksetup`, BoxPilot now asks for the administrator password once and applies it as root,
   whatever networksetup reported; the result is checked with `scutil --proxy`. (Desktop only.)
3. **Linux TUN: "pkexec: Cannot run program setcap".** `setcap` / `getcap` live in `/usr/sbin`,
   which isn't on a user's PATH on Debian, and may not be installed (`libcap2-bin`). They're now run
   by absolute path; without `setcap` the core becomes setuid root instead. (Desktop only.)
4. **Linux system proxy ignored by Firefox-based browsers on KDE.** Only KDE's `kioslaverc` was
   set; Firefox reads GNOME's settings on every desktop. Both are set now, and KIO is told to
   reload. (Desktop only.)
5. **KDE drew its own title bar over BoxPilot's.** The window now asks for client-side decorations
   on Linux (GNOME already got them). (Desktop only.)

---

## 1.0.1 — 2026-10-29

Desktop commit: `6c59c72` (tag `v1.0.1`, on GitHub). To take it, set `rev = "6c59c72"` (or
`tag = "v1.0.1"`) for `boxpilot-core`; the fix itself is in the desktop app crate, not the core.

### Bug fixes

1. **Crash when opening a rule-set file in the text editor (Windows).** The editor was launched
   with `ShellExecuteExW` on the UI thread. The shell pumps window messages while it works (COM
   waits, the editor taking focus), so the window was re-entered in the middle of the click and the
   app aborted (`0xc0000409`). Shell calls now run on a thread of their own with a single-threaded
   COM apartment (`platform::shell_thread`), and the editor launch waits there (`SEE_MASK_NOASYNC`).
   The same applies to "Restart as administrator" (the UAC prompt) and to macOS / Linux, where the
   editor lookup and launch no longer block the UI.
   Mobile: never call into the OS share sheet, file pickers or intents in a way that blocks or
   re-enters the UI thread's event handling; hop to the platform's main-thread API asynchronously.
2. **Panics are written to the log** (`boxpilot.log`) before the process ends, with the thread
   name, so crashes reported by users leave a reason behind.

---

## 1.0.0 — 2026-10-29

Desktop commit: `750fc186` (tag `v1.0.0`, on GitHub), on top of `d661e1f` = 0.2.2, the rev mobile
pins now. To take the core changes, set `rev = "750fc186"` (or `tag = "v1.0.0"`) for `boxpilot-core`.

### New features

1. **Share links (export nodes)**
   - Any node, from a subscription or added locally, can be copied as a share link: ss (SIP002;
     2022 ciphers keep plain credentials), vmess (v2 base64 JSON), vless, trojan, hysteria2,
     hysteria, tuic, anytls, socks5, http(s), wireguard, ssh. Other types return an error.
   - Core: `boxpilot_core::convert::{share_link(&Node), share_links(&[Node]) -> (String, Vec<String> skipped), outbound_share_link(name, &Value)}`,
     `Engine::share_link_for(tag)` (from the running config's outbound tag).
   - Desktop UI: share icon on node cards (Proxies, shown on hover), "Copy node links" on every
     subscription card, per-row share in Local nodes.
   - Mobile: a "Share" / "Copy link" action on a node (long-press menu) and on a subscription; a QR
     code of the link would suit mobile well.

2. **Local nodes (add single nodes)**
   - Nodes can be added one by one from links (any format `parse_subscription` reads: share links,
     base64, Clash, sing-box). They live in a reserved subscription, id `local-nodes`, name
     `Local nodes`, shown in the UI translated (中: 本地节点 / 繁: 本機節點 / RU: Локальные узлы). It is
     always the last group and appears as its own group on the Proxies page.
   - Core: `model::{LOCAL_NODES_ID, LOCAL_NODES_NAME}`, `Subscription::is_local_nodes()`,
     `Engine::add_local_nodes(text) -> (added, skipped)`, `Engine::remove_local_node(index)`,
     `Engine::local_group() -> Option<Subscription>`, `Engine::nodes(LOCAL_NODES_ID)`.
     **Breaking:** `Engine::subscriptions()` no longer includes the Local nodes group — use
     `local_group()` for it. The group is removed with its last node; enable/disable it with
     `set_subscription_enabled(LOCAL_NODES_ID, …)`.
   - Desktop UI: Subscriptions → Add (menu: Add subscription / Add node), Paste detects node links
     and opens Add node, a "Local nodes" card with rows (protocol, name, server:port, share, delete).
   - Mobile: "Add node" next to "Add subscription"; also scan a QR code / paste from clipboard.

3. **Rule-set node groups**
   - A rule-set (target not reject) can get a node group of its own: a selector named after the
     rule-set with members Proxy, subscription groups, all nodes, direct; it starts on the rule-set's
     target. The group is picked by hand ("Manual") or by Auto's four modes (Quickest / Steady /
     Ordered / Bandwidth) with an optional region — the same picker as Auto, through the Clash API,
     no core restart. With a group on, the rule-set's target pill reads "Custom".
   - Core: `RuleProvider { own_group: bool, pick: Option<AutoStrategy>, region: String }` (serde
     defaults, old files load), `RuleProvider::can_own_group()`, `BuiltConfig::provider_groups:
     Vec<(provider_id, group_tag)>`, `Engine::set_rule_provider_group(id, on)` (config change →
     reload), `Engine::set_rule_group_pick(id, pick, region)` (live), `Engine::rule_group(tag) ->
     Option<RuleProvider>` (is this Proxies group a rule-set group?). Groups with a pick report kind
     `URLTest` in `groups()` like Auto (not selectable by hand).
   - Mobile: a switch per rule-set ("Own node group"), and on the group's page the same
     mode + region pickers as Auto plus "Manual".

4. **Edit a rule-set file**
   - Desktop opens the rule-set's text file in the system editor and applies each save.
   - Core: `Engine::rule_provider_text_file(id) -> Option<(PathBuf, is_local_source)>` (None for
     `.srs`/not downloaded), `Engine::watch_rule_provider_edits(id, path, is_local_source)` (polls
     the file; a local source is re-imported, a stored copy is re-validated, sing-box reloads local
     rule-set files by itself).
   - Mobile: no system editor — an in-app text editor that writes the file would do; then call
     `update_rule_provider(id)` for a local source.

5. **ACL4SSR import starts switched off; Enable all / Disable all**
   - `Engine::import_acl_ini` now adds every rule-set with `enabled: false` (still downloaded, so
     rule counts show). `Engine::set_rule_providers_enabled(ids, true)` downloads any never-fetched
     ones first.
   - Mobile: "Enable all" / "Disable all" on the rule-set list.

6. **macOS app bundle** (desktop only) — releases ship `BoxPilot.app` in a `.dmg`; the updater
   re-signs the bundle ad hoc after replacing the binary.

### Bug fixes

1. **Search hints didn't follow a language switch** (Proxies, Connections, Logs, Settings core-path
   field). Placeholders were set once at creation. Mobile: check every text field hint is re-read
   from the current language when it changes.
2. **TUN failed on Apple systems: "bad tun name: BoxPilot"** — Apple only accepts `utunN`. The
   generated config now leaves `interface_name` out on macOS **and iOS** (`cfg!(any(target_os =
   "macos", target_os = "ios"))`), so sing-box picks a free utun. Mobile/iOS gets this with the core
   bump if it uses the generated TUN inbound.
3. **macOS system proxy didn't take effect** — it stopped at the first network service that
   errored, and `networksetup` reports errors on stdout with exit 0. Now every service is tried,
   states are switched on explicitly, an empty bypass list is "Empty", permission refusals are
   retried once with an administrator prompt, and the result is verified with `scutil --proxy`.
   (Desktop only.)
4. **macOS translucent window unreadable over light windows** — macOS's blur has no tint; the
   window now keeps a tint of the theme base colour with a 78 % floor (Linux/KDE too). Mobile: if
   you use blur materials, keep a tint under text.
5. UI strings that said "Windows" (system proxy, launch at login) are now platform-neutral.
