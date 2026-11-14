import Foundation
import NetworkExtension

/// Starts, reloads and stops the PacketTunnel extension, where sing-box runs.
/// The engine reads logs through the core's Clash API, so the app itself does
/// not link libbox.
///
/// Only `prepare` (the user tapping Connect) creates the VPN configuration, which
/// is what brings up iOS's permission prompt; `start` never does.
final class TunnelManager {
    static let shared = TunnelManager()
    static let tunnelBundleId = "io.github.billblueinnit.boxpilot.PacketTunnel"

    /// Reloads stop and start the core back to back; the tunnel stays up in between.
    private static let stopGrace: TimeInterval = 1.5

    /// The tunnel stopped without the engine asking (Settings, another VPN).
    var onStopped: ((String) -> Void)?

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var pendingStop: DispatchWorkItem?
    private var stopRequested = false

    /// Whether the VPN configuration exists, i.e. the user allowed it before.
    @MainActor
    func isReady() async -> Bool {
        (try? await loadManager()) != nil
    }

    /// Whether a tunnel is up (it can outlive the app).
    @MainActor
    func isConnected() async -> Bool {
        let status = (try? await loadManager())?.connection.status
        return status == .connected || status == .reasserting
    }

    @MainActor
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
    func prepare() async -> Bool {
        do {
            let existing = try await loadManager()
            let manager = existing ?? NETunnelProviderManager()
            let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
            proto.providerBundleIdentifier = Self.tunnelBundleId
            proto.serverAddress = "BoxPilot"
            manager.protocolConfiguration = proto
            manager.localizedDescription = "BoxPilot"
            if existing == nil || !manager.isEnabled {
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
    func start(_ config: String) async -> String {
        pendingStop?.cancel()
        pendingStop = nil
        stopRequested = false
        guard let manager = try? await loadManager() else {
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
                return ""
            case .disconnected, .invalid:
                // The extension failed to start; iOS keeps the reason.
                if let error = try? await lastError(connection) { return error }
                return "the VPN did not start"
            default:
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
        return "the VPN did not start in time"
    }

    private func lastError(_ connection: NEVPNConnection) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            connection.fetchLastDisconnectError { error in
                continuation.resume(returning: error?.localizedDescription)
            }
        }
    }

    /// A stop the engine asks for waits briefly, because a reload is a stop followed by a start.
    @MainActor
    func stop() {
        pendingStop?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingStop = nil
            self.stopRequested = true
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
            if manager.connection.status == .disconnected {
                if !self.stopRequested && self.pendingStop == nil {
                    // Turned off in Settings, by another VPN, or the extension ended.
                    self.onStopped?("the VPN was turned off")
                }
                self.stopRequested = false
            }
        }
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
