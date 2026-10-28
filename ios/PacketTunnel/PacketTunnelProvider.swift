import Foundation
import Libbox
import Network
import NetworkExtension

/// Runs libbox as the device VPN. The app's engine decides what runs and hands
/// over the generated configuration; this extension only hosts the core.
///
/// App messages: `{"reload": "<config>"}` reloads in place, keeping the tunnel up.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var commandServer: LibboxCommandServer?
    private lazy var platform = TunnelPlatform(self)

    override func startTunnel(options: [String: NSObject]?) async throws {
        let paths = SharedPaths()
        let config: String
        if let content = options?["configContent"] as? String {
            config = content
            try? content.write(to: paths.lastConfig, atomically: true, encoding: .utf8)
        } else if let saved = try? String(contentsOf: paths.lastConfig, encoding: .utf8) {
            // Started by the system (Settings, on-demand): reuse the last configuration.
            config = saved
        } else {
            throw TunnelError("missing configuration")
        }

        let setup = LibboxSetupOptions()
        setup.basePath = paths.base.path
        setup.workingPath = paths.working.path
        setup.tempPath = paths.temp.path
        setup.logMaxLines = 3000
        setup.crashReportSource = "PacketTunnel"
        setup.oomKillerEnabled = true
        var error: NSError?
        LibboxSetup(setup, &error)
        if let error { throw TunnelError("setup: \(error.localizedDescription)") }

        guard let server = LibboxNewCommandServer(platform, platform, &error) else {
            throw TunnelError("command server: \(error?.localizedDescription ?? "unknown")")
        }
        try server.start()
        commandServer = server
        try startService(config)
    }

    private func startService(_ config: String) throws {
        guard let server = commandServer else { throw TunnelError("not started") }
        do {
            try server.startOrReloadService(config, options: LibboxOverrideOptions())
        } catch {
            throw TunnelError("start service: \(error.localizedDescription)")
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        try? commandServer?.closeService()
        commandServer?.close()
        commandServer = nil
        platform.reset()
    }

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        guard let message = try? JSONSerialization.jsonObject(with: messageData) as? [String: String],
              let config = message["reload"]
        else { return Data("unknown message".utf8) }
        do {
            try startService(config)
            try? config.write(to: SharedPaths().lastConfig, atomically: true, encoding: .utf8)
            return Data()
        } catch {
            return Data(error.localizedDescription.utf8)
        }
    }

    override func sleep() async {
        commandServer?.pause()
    }

    override func wake() {
        commandServer?.wake()
    }
}

struct TunnelError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// The App Group container both the app and the extension use.
struct SharedPaths {
    static let group = "group.io.github.billblueinnit.boxpilot"

    let base: URL
    var working: URL { base.appendingPathComponent("core", isDirectory: true) }
    var temp: URL { base.appendingPathComponent("tmp", isDirectory: true) }
    var lastConfig: URL { base.appendingPathComponent("tunnel-config.json") }

    init() {
        base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group)
            ?? FileManager.default.temporaryDirectory
        for dir in [working, temp] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Platform interface

final class TunnelPlatform: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    private unowned let tunnel: PacketTunnelProvider
    private var monitor: NWPathMonitor?
    private var settings: NEPacketTunnelNetworkSettings?

    init(_ tunnel: PacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func reset() {
        monitor?.cancel()
        monitor = nil
        settings = nil
    }

    // MARK: Tunnel

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options, let ret0_ else { throw TunnelError("missing tun options") }
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())

            var dns: NEDNSSettings?
            if options.getDNSMode()?.value != LibboxDNSModeDisabled {
                let servers = collect(try options.getDNSServerAddress())
                if !servers.isEmpty { dns = NEDNSSettings(servers: servers) }
            }

            var v4Addresses: [String] = [], v4Masks: [String] = []
            forEach(options.getInet4Address()) {
                v4Addresses.append($0.address())
                v4Masks.append($0.mask())
            }
            let v4 = NEIPv4Settings(addresses: v4Addresses, subnetMasks: v4Masks)
            var v4Routes: [NEIPv4Route] = []
            forEach(options.getInet4RouteAddress()) {
                v4Routes.append(NEIPv4Route(destinationAddress: $0.address(), subnetMask: $0.mask()))
            }
            if v4Routes.isEmpty { v4Routes.append(.default()) }
            var v4Excluded: [NEIPv4Route] = []
            forEach(options.getInet4RouteExcludeAddress()) {
                v4Excluded.append(NEIPv4Route(destinationAddress: $0.address(), subnetMask: $0.mask()))
            }
            v4.includedRoutes = v4Routes
            v4.excludedRoutes = v4Excluded
            settings.ipv4Settings = v4

            var v6Addresses: [String] = [], v6Prefixes: [NSNumber] = []
            forEach(options.getInet6Address()) {
                v6Addresses.append($0.address())
                v6Prefixes.append(NSNumber(value: $0.prefix()))
            }
            if !v6Addresses.isEmpty {
                let v6 = NEIPv6Settings(addresses: v6Addresses, networkPrefixLengths: v6Prefixes)
                var v6Routes: [NEIPv6Route] = []
                forEach(options.getInet6RouteAddress()) {
                    v6Routes.append(NEIPv6Route(destinationAddress: $0.address(), networkPrefixLength: NSNumber(value: $0.prefix())))
                }
                if v6Routes.isEmpty { v6Routes.append(.default()) }
                var v6Excluded: [NEIPv6Route] = []
                forEach(options.getInet6RouteExcludeAddress()) {
                    v6Excluded.append(NEIPv6Route(destinationAddress: $0.address(), networkPrefixLength: NSNumber(value: $0.prefix())))
                }
                v6.includedRoutes = v6Routes
                v6.excludedRoutes = v6Excluded
                settings.ipv6Settings = v6
            }
            settings.dnsSettings = dns
        }

        if options.isHTTPProxyEnabled() {
            let proxy = NEProxySettings()
            let server = NEProxyServer(address: options.getHTTPProxyServer(), port: Int(options.getHTTPProxyServerPort()))
            proxy.httpServer = server
            proxy.httpsServer = server
            proxy.httpEnabled = true
            proxy.httpsEnabled = true
            let bypass = collect(options.getHTTPProxyBypassDomain())
            if !bypass.isEmpty { proxy.exceptionList = bypass }
            let match = collect(options.getHTTPProxyMatchDomain())
            if !match.isEmpty { proxy.matchDomains = match }
            settings.proxySettings = proxy
        }

        self.settings = settings
        let done = DispatchSemaphore(value: 0)
        var applyError: Error?
        tunnel.setTunnelNetworkSettings(settings) { error in
            applyError = error
            done.signal()
        }
        done.wait()
        if let applyError { throw applyError }

        if let fd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = fd
            return
        }
        let fd = LibboxGetTunnelFileDescriptor()
        if fd == -1 { throw TunnelError("missing tunnel file descriptor") }
        ret0_.pointee = fd
    }

    func usePlatformAutoDetectInterfaceControl() -> Bool { false }

    func autoDetectInterfaceControl(_: Int32) throws {}

    func findConnectionOwner(_: Int32, sourceAddress _: String?, sourcePort _: Int32, destinationAddress _: String?, destinationPort _: Int32) throws -> LibboxConnectionOwner {
        throw TunnelError("not supported")
    }

    // MARK: Network monitoring

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        let first = DispatchSemaphore(value: 0)
        var reported = false
        monitor.pathUpdateHandler = { path in
            Self.report(path, to: listener)
            if !reported {
                reported = true
                first.signal()
            }
        }
        monitor.start(queue: DispatchQueue.global())
        first.wait()
    }

    private static func report(_ path: NWPath, to listener: LibboxInterfaceUpdateListenerProtocol) {
        guard path.status != .unsatisfied, let interface = path.availableInterfaces.first else {
            listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
            return
        }
        listener.updateDefaultInterface(interface.name, interfaceIndex: Int32(interface.index), isExpensive: path.isExpensive, isConstrained: path.isConstrained)
    }

    func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
        monitor?.cancel()
        monitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        guard let monitor, monitor.currentPath.status != .unsatisfied else { return InterfaceList([]) }
        let interfaces = monitor.currentPath.availableInterfaces.map { it -> LibboxNetworkInterface in
            let interface = LibboxNetworkInterface()
            interface.name = it.name
            interface.index = Int32(it.index)
            switch it.type {
            case .wifi: interface.type = LibboxInterfaceTypeWIFI
            case .cellular: interface.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: interface.type = LibboxInterfaceTypeEthernet
            default: interface.type = LibboxInterfaceTypeOther
            }
            return interface
        }
        return InterfaceList(interfaces)
    }

    func underNetworkExtension() -> Bool { true }

    func includeAllNetworks() -> Bool { false }

    func clearDNSCache() {
        guard let settings else { return }
        tunnel.reasserting = true
        tunnel.setTunnelNetworkSettings(nil) { _ in }
        tunnel.setTunnelNetworkSettings(settings) { _ in }
        tunnel.reasserting = false
    }

    func readWIFIState() -> LibboxWIFIState? { nil }

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }

    // MARK: Unused platform features

    func send(_: LibboxNotification?) throws {}

    func cancelNotification(_: String?, typeID _: Int32) throws {}

    func startNeighborMonitor(_: LibboxNeighborUpdateListenerProtocol?) throws {}

    func closeNeighborMonitor(_: LibboxNeighborUpdateListenerProtocol?) throws {}

    func registerMyInterface(_: String?) {}

    func usePlatformShell() -> Bool { false }

    func checkPlatformShell() throws { throw TunnelError("not supported") }

    func openShellSession(_: LibboxPlatformUser?, command _: String?, environ _: (any LibboxStringIteratorProtocol)?, term _: String?, rows _: Int32, cols _: Int32) throws -> any LibboxShellSessionProtocol {
        throw TunnelError("not supported")
    }

    func lookupUser(_: String?) throws -> LibboxPlatformUser { throw TunnelError("not supported") }

    func lookupSFTPServer(_ error: NSErrorPointer) -> String {
        error?.pointee = TunnelError("not supported") as NSError
        return ""
    }

    func readSystemSSHHostKey(_ error: NSErrorPointer) -> String {
        error?.pointee = TunnelError("not supported") as NSError
        return ""
    }

    func tailscaleHostname() -> String { "BoxPilot" }

    func usePlatformBridge() -> Bool { false }

    func createBridge(_: LibboxBridgeOptions?) throws -> any LibboxBridgeSessionProtocol {
        throw TunnelError("not supported")
    }

    // MARK: Command server

    func serviceStop() throws {
        tunnel.cancelTunnelWithError(nil)
    }

    func serviceReload() throws {}

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus { LibboxSystemProxyStatus() }

    func setSystemProxyEnabled(_: Bool) throws {}

    func triggerNativeCrash() throws {}

    func writeDebugMessage(_ message: String?) {
        NSLog("BoxPilot: %@", message ?? "")
    }

    func connectSSHAgent(_: UnsafeMutablePointer<Int32>?) throws { throw TunnelError("not supported") }

    // MARK: Helpers

    private func collect(_ iterator: LibboxStringIteratorProtocol?) -> [String] {
        var out: [String] = []
        while let iterator, iterator.hasNext() { out.append(iterator.next()) }
        return out
    }

    private func forEach(_ iterator: LibboxRoutePrefixIteratorProtocol?, _ body: (LibboxRoutePrefix) -> Void) {
        while let iterator, iterator.hasNext() {
            if let prefix = iterator.next() { body(prefix) }
        }
    }
}

private final class InterfaceList: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: IndexingIterator<[LibboxNetworkInterface]>
    private var upcoming: LibboxNetworkInterface?

    init(_ items: [LibboxNetworkInterface]) {
        iterator = items.makeIterator()
    }

    func hasNext() -> Bool {
        upcoming = iterator.next()
        return upcoming != nil
    }

    func next() -> LibboxNetworkInterface? { upcoming }
}
