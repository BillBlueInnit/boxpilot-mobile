import Flutter
import Foundation
import Libbox
import NetworkExtension

/// The Dart side's handle on the embedded core, the iOS counterpart of Android's
/// `CoreChannel`. sing-box runs in the PacketTunnel extension; this class starts,
/// reloads and stops it, and forwards its logs.
///
/// Methods (`boxpilot/core`): `info`, `prepare`, `start(config)`, `stop`.
/// Events (`boxpilot/core/events`): `{type: logs, lines}`, `{type: stopped, reason}`.
final class CoreHost: NSObject, FlutterStreamHandler {
    static let tunnelBundleId = "io.github.billblueinnit.boxpilot.PacketTunnel"

    /// Reloads stop and start the core back to back; the tunnel stays up in between.
    private static let stopGrace: TimeInterval = 1.5

    private var events: FlutterEventSink?
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var pendingStop: DispatchWorkItem?
    private var stopRequested = false
    private var logClient: LibboxCommandClient?
    private lazy var logHandler = LogHandler(self)

    init(messenger: FlutterBinaryMessenger) {
        super.init()
        let methods = FlutterMethodChannel(name: "boxpilot/core", binaryMessenger: messenger)
        methods.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
        FlutterEventChannel(name: "boxpilot/core/events", binaryMessenger: messenger).setStreamHandler(self)
        setupLibbox()
        Task { _ = try? await loadManager() }
    }

    // MARK: Channel

    func onListen(withArguments _: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        events = eventSink
        return nil
    }

    func onCancel(withArguments _: Any?) -> FlutterError? {
        events = nil
        return nil
    }

    private func emit(_ event: [String: Any]) {
        DispatchQueue.main.async { self.events?(event) }
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        Task { @MainActor in
            switch call.method {
            case "info":
                let paths = AppPaths()
                result([
                    "coreVersion": LibboxVersion(),
                    "dataDir": paths.data.path,
                    "running": manager?.connection.status == .connected,
                ])
            case "prepare":
                result(await prepare())
            case "start":
                let config = (call.arguments as? [String: Any])?["config"] as? String ?? ""
                result(await start(config))
            case "stop":
                stop()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: VPN configuration

    private func loadManager() async throws -> NETunnelProviderManager? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let found = managers.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Self.tunnelBundleId
        }
        if let found {
            manager = found
            observe(found)
        }
        return found
    }

    /// Creates the VPN configuration if needed; iOS asks the user to allow it.
    @MainActor
    private func prepare() async -> Bool {
        do {
            let manager = try await loadManager() ?? NETunnelProviderManager()
            let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
            proto.providerBundleIdentifier = Self.tunnelBundleId
            proto.serverAddress = "BoxPilot"
            manager.protocolConfiguration = proto
            manager.localizedDescription = "BoxPilot"
            if !manager.isEnabled || manager.protocolConfiguration == nil || self.manager == nil {
                manager.isEnabled = true
                try await manager.saveToPreferences()
                try await manager.loadFromPreferences()
            }
            self.manager = manager
            observe(manager)
            return true
        } catch {
            NSLog("BoxPilot: VPN configuration: %@", error.localizedDescription)
            return false
        }
    }

    // MARK: Start / stop

    /// Starts the tunnel, or reloads it in place. Returns "" or the error.
    @MainActor
    private func start(_ config: String) async -> String {
        pendingStop?.cancel()
        pendingStop = nil
        stopRequested = false
        var found = (try? await loadManager()) ?? nil
        if found == nil, await prepare() {
            found = self.manager
        }
        guard let manager = found else {
            return "VPN permission is required"
        }
        if !manager.isEnabled {
            manager.isEnabled = true
            try? await manager.saveToPreferences()
        }
        let connection = manager.connection
        if connection.status == .connected || connection.status == .reasserting,
           let session = connection as? NETunnelProviderSession
        {
            return await reload(session, config)
        }
        do {
            try connection.startVPNTunnel(options: ["configContent": config as NSString])
        } catch {
            return error.localizedDescription
        }
        return await waitForConnection(connection)
    }

    private func reload(_ session: NETunnelProviderSession, _ config: String) async -> String {
        guard let message = try? JSONSerialization.data(withJSONObject: ["reload": config]) else {
            return "could not encode the configuration"
        }
        return await withCheckedContinuation { continuation in
            do {
                try session.sendProviderMessage(message) { reply in
                    continuation.resume(returning: reply.flatMap { String(data: $0, encoding: .utf8) } ?? "")
                }
            } catch {
                continuation.resume(returning: error.localizedDescription)
            }
        }
    }

    private func waitForConnection(_ connection: NEVPNConnection) async -> String {
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            switch connection.status {
            case .connected:
                connectLogs()
                return ""
            case .disconnected, .invalid:
                // The extension failed to start; iOS 16 keeps the reason.
                if #available(iOS 16.0, *) {
                    if let error = try? await lastError(connection) { return error }
                }
                return "the VPN did not start"
            default:
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
        return "the VPN did not start in time"
    }

    @available(iOS 16.0, *)
    private func lastError(_ connection: NEVPNConnection) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            connection.fetchLastDisconnectError { error in
                continuation.resume(returning: error?.localizedDescription)
            }
        }
    }

    /// A stop the engine asks for waits briefly, because a reload is a stop followed by a start.
    @MainActor
    private func stop() {
        pendingStop?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.stopRequested = true
            self.disconnectLogs()
            self.manager?.connection.stopVPNTunnel()
        }
        pendingStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.stopGrace, execute: work)
    }

    private func observe(_ manager: NETunnelProviderManager) {
        if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: manager.connection, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            switch manager.connection.status {
            case .connected:
                self.connectLogs()
            case .disconnected:
                self.disconnectLogs()
                if !self.stopRequested && self.pendingStop == nil {
                    // Turned off in Settings, by another VPN, or the extension ended.
                    self.emit(["type": "stopped", "reason": "the VPN was turned off"])
                }
                self.stopRequested = false
            default:
                break
            }
        }
    }

    // MARK: Logs

    private func setupLibbox() {
        let paths = AppPaths()
        let options = LibboxSetupOptions()
        options.basePath = paths.group.path
        options.workingPath = paths.group.appendingPathComponent("core", isDirectory: true).path
        options.tempPath = FileManager.default.temporaryDirectory.path
        options.crashReportSource = "Application"
        var error: NSError?
        LibboxSetup(options, &error)
    }

    private func connectLogs() {
        guard logClient == nil else { return }
        let options = LibboxCommandClientOptions()
        options.addCommand(LibboxCommandLog)
        guard let client = LibboxNewCommandClient(logHandler, options) else { return }
        logClient = client
        DispatchQueue.global().async {
            for _ in 0 ..< 10 {
                if (try? client.connect()) != nil { return }
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
    }

    private func disconnectLogs() {
        try? logClient?.disconnect()
        logClient = nil
    }

    fileprivate func forward(_ lines: [String]) {
        if !lines.isEmpty { emit(["type": "logs", "lines": lines]) }
    }
}

/// The App Group container the app shares with the extension.
struct AppPaths {
    static let group = "group.io.github.billblueinnit.boxpilot"

    let group: URL

    /// The engine's data folder: settings, subscriptions and rule-sets, readable by the extension.
    var data: URL { group.appendingPathComponent("BoxPilot", isDirectory: true) }

    init() {
        group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
    }
}

private final class LogHandler: NSObject, LibboxCommandClientHandlerProtocol {
    private weak var host: CoreHost?

    init(_ host: CoreHost) {
        self.host = host
    }

    func writeLogs(_ messageList: (any LibboxLogIteratorProtocol)?) {
        guard let messageList else { return }
        var lines: [String] = []
        while messageList.hasNext() {
            guard let entry = messageList.next() else { break }
            lines.append("\(Self.level(entry.level)) \(entry.message)")
        }
        host?.forward(lines)
    }

    private static func level(_ value: Int32) -> String {
        switch value {
        case 0 ... 2: "ERROR"
        case 3: "WARN"
        case 4: "INFO"
        case 5: "DEBUG"
        default: "TRACE"
        }
    }

    func connected() {}
    func disconnected(_: String?) {}
    func setDefaultLogLevel(_: Int32) {}
    func clearLogs() {}
    func writeStatus(_: LibboxStatusMessage?) {}
    func writeGroups(_: (any LibboxOutboundGroupIteratorProtocol)?) {}
    func writeOutbounds(_: (any LibboxOutboundGroupItemIteratorProtocol)?) {}
    func initializeClashMode(_: (any LibboxStringIteratorProtocol)?, currentMode _: String?) {}
    func updateClashMode(_: String?) {}
    func write(_: LibboxConnectionEvents?) {}
}
