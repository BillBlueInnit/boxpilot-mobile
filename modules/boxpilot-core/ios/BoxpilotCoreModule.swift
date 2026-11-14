import ExpoModulesCore
import Foundation

/// The JavaScript side's handle on the engine and the VPN (`modules/boxpilot-core/index.ts`).
///
/// `invoke(method, args)` is the engine (see `rust/src/api.rs`); the rest is what
/// only the platform knows. Engine events arrive as `onEvent`, `{json}`.
public class BoxpilotCoreModule: Module {
    public func definition() -> ModuleDefinition {
        Name("BoxpilotCore")

        Events("onEvent")

        OnCreate {
            EngineHost.shared.listener = { [weak self] json in
                self?.sendEvent("onEvent", ["json": json])
            }
        }

        OnDestroy {
            EngineHost.shared.listener = nil
        }

        // Creates the engine on the first call: it needs to know whether the
        // VPN configuration exists, which iOS only tells asynchronously.
        AsyncFunction("info") { (promise: Promise) in
            Task {
                let ready = await TunnelManager.shared.isReady()
                let connected = await TunnelManager.shared.isConnected()
                let paths = AppPaths()
                let version = Bundle.main.object(forInfoDictionaryKey: "BoxPilotCoreVersion") as? String ?? ""
                let error = EngineHost.shared.ensure(root: paths.data.path, coreVersion: version, vpnReady: ready)
                var info: [String: Any] = [
                    "coreVersion": version,
                    "dataDir": paths.data.path,
                    "vpnReady": ready,
                    "tunnelRunning": connected,
                    "perApp": false,
                ]
                if let error { info["error"] = error }
                if let problem = TunnelManager.problem() { info["vpnProblem"] = problem }
                promise.resolve(info)
            }
        }

        AsyncFunction("invoke") { (method: String, args: String, promise: Promise) in
            DispatchQueue.global(qos: .userInitiated).async {
                promise.resolve(EngineHost.invoke(method, args))
            }
        }

        // Creates the VPN configuration; iOS asks the user to allow it. Only
        // Connect calls this: a permission prompt needs the user's tap.
        AsyncFunction("prepare") { (promise: Promise) in
            Task {
                promise.resolve(await TunnelManager.shared.prepare())
            }
        }

        // iOS apps do not quit themselves; after a reset the user reopens the app.
        Function("exit") { () -> Void in }

        // Per-app proxy and wallpaper colours are Android's.
        Function("perApp") { () -> [String: Any] in
            ["mode": "all", "packages": [String]()]
        }

        Function("setPerApp") { (_: String, _: [String]) -> Void in }

        AsyncFunction("apps") { () -> [[String: String]] in
            []
        }

        AsyncFunction("appIcon") { (_: String) -> String? in
            nil
        }

        Function("palette") { () -> [String: String]? in
            nil
        }
    }
}

/// The engine for the app's process, and the callbacks it calls.
final class EngineHost {
    static let shared = EngineHost()

    /// Engine events for the UI, when one is attached.
    var listener: ((String) -> Void)?

    private var ready = false
    private let lock = NSLock()

    /// Creates the engine once. Returns an error text, or nil.
    func ensure(root: String, coreVersion: String, vpnReady: Bool) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if ready {
            _ = EngineHost.invoke("setVpnReady", vpnReady ? "{\"ready\":true}" : "{\"ready\":false}")
            return nil
        }
        TunnelManager.shared.onStopped = { reason in
            let args = (try? JSONSerialization.data(withJSONObject: ["reason": reason])).flatMap {
                String(data: $0, encoding: .utf8)
            } ?? "{}"
            DispatchQueue.global().async { _ = EngineHost.invoke("coreExited", args) }
        }
        guard let answer = boxpilot_init(root, coreVersion, vpnReady, startCore, stopCore, onEvent) else {
            return "the engine did not start"
        }
        defer { boxpilot_free(answer) }
        let text = String(cString: answer)
        if text.hasPrefix("error") { return text }
        ready = true
        return nil
    }

    static func invoke(_ method: String, _ args: String) -> String {
        guard let answer = boxpilot_invoke(method, args) else { return "{\"error\":\"no answer\"}" }
        defer { boxpilot_free(answer) }
        return String(cString: answer)
    }
}

// The engine calls these from its own threads, never the main one.

private final class Answer: @unchecked Sendable {
    var error = ""
}

private let startCore: @convention(c) (UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? = { config in
    let config = config.map { String(cString: $0) } ?? ""
    let done = DispatchSemaphore(value: 0)
    let answer = Answer()
    Task {
        answer.error = await TunnelManager.shared.start(config)
        done.signal()
    }
    done.wait()
    return answer.error.isEmpty ? nil : strdup(answer.error)
}

private let stopCore: @convention(c) () -> Void = {
    _ = Task { await TunnelManager.shared.stop() }
}

private let onEvent: @convention(c) (UnsafePointer<CChar>?) -> Void = { event in
    guard let event else { return }
    let json = String(cString: event)
    EngineHost.shared.listener?(json)
}
