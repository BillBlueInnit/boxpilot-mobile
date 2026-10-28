package io.github.billblueinnit.boxpilot

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.system.OsConstants
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.NetworkInterfaceIterator
import java.net.Inet6Address
import java.net.InterfaceAddress
import java.net.NetworkInterface
import io.nekohasekai.libbox.NetworkInterface as BoxInterface

/**
 * Follows the device's default (non-VPN) network, which sing-box binds its
 * outbound sockets to, and lists the physical interfaces for it.
 */
object NetworkMonitor {
    @Volatile
    var defaultNetwork: Network? = null
        private set

    private var listener: InterfaceUpdateListener? = null
    private var registered = false
    private val thread by lazy { HandlerThread("network-monitor").apply { start() } }
    private val handler by lazy { Handler(thread.looper) }

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = changed(network)

        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
            if (network == defaultNetwork) changed(network)
        }

        override fun onLinkPropertiesChanged(network: Network, link: LinkProperties) {
            if (network == defaultNetwork) changed(network)
        }

        override fun onLost(network: Network) {
            if (network == defaultNetwork) changed(null)
        }
    }

    @Synchronized
    fun start() {
        if (registered) return
        val cm = BoxPilotApp.connectivity
        defaultNetwork = cm.activeNetwork
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            cm.registerBestMatchingNetworkCallback(request, callback, handler)
        } else {
            cm.requestNetwork(request, callback, handler)
        }
        registered = true
    }

    @Synchronized
    fun stop() {
        if (!registered) return
        runCatching { BoxPilotApp.connectivity.unregisterNetworkCallback(callback) }
        registered = false
        defaultNetwork = null
    }

    fun setListener(l: InterfaceUpdateListener?) {
        listener = l
        report(defaultNetwork)
    }

    private fun changed(network: Network?) {
        defaultNetwork = network
        report(network)
    }

    private fun report(network: Network?) {
        val l = listener ?: return
        if (network == null) {
            l.updateDefaultInterface("", -1, false, false)
            return
        }
        // Link properties can lag behind the callback for a moment.
        repeat(10) {
            val name = BoxPilotApp.connectivity.getLinkProperties(network)?.interfaceName
            val index = name?.let { runCatching { NetworkInterface.getByName(it)?.index }.getOrNull() }
            if (name != null && index != null) {
                val caps = BoxPilotApp.connectivity.getNetworkCapabilities(network)
                val expensive = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false
                l.updateDefaultInterface(name, index, expensive, false)
                return
            }
            Thread.sleep(100)
        }
    }

    fun interfaces(): NetworkInterfaceIterator {
        val cm = BoxPilotApp.connectivity
        val system = NetworkInterface.getNetworkInterfaces()?.toList().orEmpty()
        val result = mutableListOf<BoxInterface>()
        @Suppress("DEPRECATION")
        for (network in cm.allNetworks) {
            val link = cm.getLinkProperties(network) ?: continue
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
            val nif = system.find { it.name == link.interfaceName } ?: continue
            result += BoxInterface().apply {
                name = link.interfaceName
                index = nif.index
                runCatching { mtu = nif.mtu }
                type = when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
                addresses = nif.interfaceAddresses.map { it.toPrefix() }.toStringIterator()
                dnsServer = link.dnsServers.mapNotNull { it.hostAddress }.toStringIterator()
                gateway = link.routes
                    .filter { it.destination.prefixLength == 0 }
                    .mapNotNull { it.gateway }
                    .filterNot { it.isAnyLocalAddress }
                    .mapNotNull { it.hostAddress }
                    .toStringIterator()
                var f = 0
                if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                    f = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                }
                if (nif.isLoopback) f = f or OsConstants.IFF_LOOPBACK
                if (nif.isPointToPoint) f = f or OsConstants.IFF_POINTOPOINT
                if (nif.supportsMulticast()) f = f or OsConstants.IFF_MULTICAST
                flags = f
                metered = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            }
        }
        val it = result.iterator()
        return object : NetworkInterfaceIterator {
            override fun hasNext() = it.hasNext()
            override fun next(): BoxInterface = it.next()
        }
    }

    private fun InterfaceAddress.toPrefix(): String = if (address is Inet6Address) {
        "${Inet6Address.getByAddress(address.address).hostAddress}/$networkPrefixLength"
    } else {
        "${address.hostAddress}/$networkPrefixLength"
    }
}
