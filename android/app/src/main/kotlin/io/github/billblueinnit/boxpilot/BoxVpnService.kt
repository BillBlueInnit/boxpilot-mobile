package io.github.billblueinnit.boxpilot

import android.app.Notification
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.Process
import android.provider.Settings
import android.service.quicksettings.TileService
import android.content.ComponentName
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import io.nekohasekai.libbox.BridgeOptions
import io.nekohasekai.libbox.BridgeSession
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NeighborUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.PlatformUser
import io.nekohasekai.libbox.ShellSession
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.net.InetSocketAddress

/**
 * Runs libbox as the device VPN. The engine (Rust, via Dart) decides what runs;
 * this service only hosts it: start or reload with a config, stop, and report
 * unexpected stops. The engine reads logs through the core's Clash API.
 */
class BoxVpnService : VpnService(), PlatformInterface, CommandServerHandler {
    companion object {
        private const val NOTIFICATION_ID = 1
        const val ACTION_DISCONNECT = "io.github.billblueinnit.boxpilot.DISCONNECT"

        /** Reloads stop and start the core back to back; the VPN stays up in between. */
        private const val STOP_GRACE_MS = 1500L

        @Volatile
        var instance: BoxVpnService? = null
            private set

        val running: Boolean
            get() = instance?.started == true
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val lock = Mutex()
    private var server: CommandServer? = null
    private var tun: ParcelFileDescriptor? = null
    private var pendingStop: Job? = null

    @Volatile
    private var started = false

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_DISCONNECT) {
            // Through the engine, so its state follows; directly if no UI is attached.
            if (!BoxPilotApp.instance.core.requestDisconnect()) {
                scope.launch { stopCore("stopped", immediately = true) }
            }
            return START_NOT_STICKY
        }
        showNotification(connected = false)
        val core = BoxPilotApp.instance.core
        val config = core.pendingConfig
        val answer = core.pendingStart
        core.pendingConfig = null
        core.pendingStart = null
        scope.launch {
            val error = if (config == null) "no configuration" else startCore(config)
            answer?.complete(error)
            if (error.isNotEmpty()) stopCore(error, immediately = true)
        }
        return START_NOT_STICKY
    }

    /** Starts the core, or reloads it in place when it already runs. */
    suspend fun startCore(config: String): String {
        pendingStop?.cancel()
        pendingStop = null
        return lock.withLock {
            try {
                NetworkMonitor.start()
                val server = server ?: CommandServer(this, this).also {
                    it.start()
                    server = it
                }
                server.startOrReloadService(config, OverrideOptions())
                started = true
                showNotification(connected = true)
                refreshTile()
                ""
            } catch (e: Exception) {
                e.message ?: e.javaClass.simpleName
            }
        }
    }

    /**
     * Stops the core. A stop the engine asks for waits briefly, because a reload
     * is a stop followed by a start; [immediately] skips that.
     */
    suspend fun stopCore(reason: String, immediately: Boolean = false) {
        pendingStop?.cancel()
        if (!immediately) {
            pendingStop = scope.launch {
                delay(STOP_GRACE_MS)
                lock.withLock { teardown() }
            }
            return
        }
        lock.withLock { teardown() }
    }

    private fun teardown() {
        if (instance !== this) return
        started = false
        runCatching { server?.closeService() }
        runCatching { server?.close() }
        server = null
        runCatching { tun?.close() }
        tun = null
        NetworkMonitor.stop()
        instance = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
        refreshTile()
    }

    override fun onRevoke() {
        // Another VPN took over, or the user turned it off in system settings.
        scope.launch {
            lock.withLock { teardown() }
            BoxPilotApp.instance.core.emitStopped(getString(R.string.vpn_revoked))
        }
    }

    override fun onDestroy() {
        if (instance === this) teardown()
        scope.cancel()
        super.onDestroy()
    }

    // ----------------------------------------------------------- notification

    private fun showNotification(connected: Boolean) {
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val disconnect = PendingIntent.getService(
            this, 1,
            Intent(this, BoxVpnService::class.java).setAction(ACTION_DISCONNECT),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notification: Notification = NotificationCompat.Builder(this, BoxPilotApp.CHANNEL_VPN)
            .setSmallIcon(R.drawable.ic_stat_boxpilot)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(getString(if (connected) R.string.status_connected else R.string.status_connecting))
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(0, getString(R.string.action_disconnect), disconnect)
            .build()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    }

    private fun refreshTile() {
        TileService.requestListeningState(this, ComponentName(this, BoxTileService::class.java))
    }

    // ------------------------------------------------------- command server

    override fun serviceStop() {
        scope.launch {
            lock.withLock { teardown() }
            BoxPilotApp.instance.core.emitStopped("stopped by the core")
        }
    }

    override fun serviceReload() {
        // The engine owns the configuration and reloads it itself.
    }

    override fun getSystemProxyStatus(): SystemProxyStatus = SystemProxyStatus()

    override fun setSystemProxyEnabled(isEnabled: Boolean) {}

    override fun triggerNativeCrash() {}

    override fun writeDebugMessage(message: String?) {
        android.util.Log.d("BoxPilot", message ?: "")
    }

    override fun connectSSHAgent(): Int = error("not supported")

    // ------------------------------------------------------------ platform

    override fun localDNSTransport(): LocalDNSTransport = LocalResolver

    override fun usePlatformAutoDetectInterfaceControl() = true

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun openTun(options: TunOptions): Int {
        if (prepare(this) != null) error("missing VPN permission")
        val builder = Builder()
            .setSession(getString(R.string.app_name))
            .setMtu(options.mtu)
            .setMetered(false)

        val inet4 = options.inet4Address
        while (inet4.hasNext()) inet4.next().let { builder.addAddress(it.address(), it.prefix()) }
        val inet6 = options.inet6Address
        while (inet6.hasNext()) inet6.next().let { builder.addAddress(it.address(), it.prefix()) }

        if (options.autoRoute) {
            if (options.dnsMode.value != Libbox.DNSModeDisabled) {
                val dns = options.dnsServerAddress
                while (dns.hasNext()) builder.addDnsServer(dns.next())
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                addRoutes(builder, options.inet4RouteAddress, options.inet4Address.hasNext(), "0.0.0.0")
                addRoutes(builder, options.inet6RouteAddress, options.inet6Address.hasNext(), "::")
                val ex4 = options.inet4RouteExcludeAddress
                while (ex4.hasNext()) builder.excludeRoute(ex4.next().toIpPrefix())
                val ex6 = options.inet6RouteExcludeAddress
                while (ex6.hasNext()) builder.excludeRoute(ex6.next().toIpPrefix())
            } else {
                val r4 = options.inet4RouteRange
                while (r4.hasNext()) r4.next().let { builder.addRoute(it.address(), it.prefix()) }
                val r6 = options.inet6RouteRange
                while (r6.hasNext()) r6.next().let { builder.addRoute(it.address(), it.prefix()) }
            }
            val include = options.includePackage
            while (include.hasNext()) runCatching { builder.addAllowedApplication(include.next()) }
            val exclude = options.excludePackage
            while (exclude.hasNext()) runCatching { builder.addDisallowedApplication(exclude.next()) }
        }

        if (options.isHTTPProxyEnabled) {
            builder.setHttpProxy(
                ProxyInfo.buildDirectProxy(
                    options.httpProxyServer,
                    options.httpProxyServerPort,
                    options.httpProxyBypassDomain.toList(),
                ),
            )
        }

        val pfd = builder.establish() ?: error("the VPN was not allowed or was revoked")
        // A reload opens a new interface; the old one goes once the new one is up.
        val old = tun
        tun = pfd
        runCatching { old?.close() }
        return pfd.fd
    }

    private fun addRoutes(
        builder: Builder,
        routes: io.nekohasekai.libbox.RoutePrefixIterator,
        hasAddress: Boolean,
        any: String,
    ) {
        if (routes.hasNext()) {
            while (routes.hasNext()) builder.addRoute(routes.next().toIpPrefix())
        } else if (hasAddress) {
            builder.addRoute(any, 0)
        }
    }

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): ConnectionOwner {
        val uid = BoxPilotApp.connectivity.getConnectionOwnerUid(
            ipProtocol,
            InetSocketAddress(sourceAddress, sourcePort),
            InetSocketAddress(destinationAddress, destinationPort),
        )
        if (uid == Process.INVALID_UID) error("connection owner not found")
        val packages = packageManager.getPackagesForUid(uid)?.toList().orEmpty()
        return ConnectionOwner().also {
            it.userId = uid
            it.userName = packages.firstOrNull() ?: ""
            it.setAndroidPackageNames(packages.toStringIterator())
        }
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        NetworkMonitor.setListener(listener)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        NetworkMonitor.setListener(null)
    }

    override fun getInterfaces(): NetworkInterfaceIterator = NetworkMonitor.interfaces()

    override fun underNetworkExtension() = false

    override fun includeAllNetworks() = false

    override fun readWIFIState(): WIFIState? = null

    override fun clearDNSCache() {}

    override fun sendNotification(notification: io.nekohasekai.libbox.Notification) {}

    override fun cancelNotification(identifier: String?, typeID: Int) {}

    override fun startNeighborMonitor(listener: NeighborUpdateListener?) {}

    override fun closeNeighborMonitor(listener: NeighborUpdateListener?) {}

    override fun registerMyInterface(name: String?) {}

    override fun usePlatformShell() = false

    override fun checkPlatformShell() = error("not supported")

    override fun openShellSession(
        user: PlatformUser?,
        command: String?,
        environ: StringIterator?,
        term: String?,
        rows: Int,
        cols: Int,
    ): ShellSession = error("not supported")

    override fun lookupUser(username: String?): PlatformUser = error("not supported")

    override fun lookupSFTPServer(): String = error("not supported")

    override fun readSystemSSHHostKey(): String = error("not supported")

    override fun tailscaleHostname(): String =
        Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)?.takeIf { it.isNotBlank() }
            ?: "${Build.MANUFACTURER} ${Build.MODEL}"

    override fun usePlatformBridge() = false

    override fun createBridge(options: BridgeOptions?): BridgeSession = error("not supported")
}

fun io.nekohasekai.libbox.RoutePrefix.toIpPrefix() =
    android.net.IpPrefix(java.net.InetAddress.getByName(address()), prefix())

fun StringIterator.toList(): List<String> = buildList { while (hasNext()) add(next()) }

fun List<String>.toStringIterator(): StringIterator = object : StringIterator {
    private val it = iterator()
    override fun len() = size
    override fun hasNext() = it.hasNext()
    override fun next() = it.next()
}
