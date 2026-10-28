package io.github.billblueinnit.boxpilot

import android.net.DnsResolver
import android.os.CancellationSignal
import android.system.ErrnoException
import io.nekohasekai.libbox.ExchangeContext
import io.nekohasekai.libbox.LocalDNSTransport
import java.net.InetAddress
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors

/**
 * The "local" DNS server of the config: the system resolver of the default
 * (non-VPN) network, so direct lookups never loop back into the tunnel.
 */
object LocalResolver : LocalDNSTransport {
    private val executor = Executors.newCachedThreadPool()

    override fun raw() = true

    override fun exchange(ctx: ExchangeContext, message: ByteArray) {
        val network = NetworkMonitor.defaultNetwork ?: error("no default network")
        val done = CountDownLatch(1)
        val signal = CancellationSignal()
        ctx.onCancel {
            signal.cancel()
            done.countDown()
        }
        DnsResolver.getInstance().rawQuery(
            network, message, DnsResolver.FLAG_NO_RETRY, executor, signal,
            object : DnsResolver.Callback<ByteArray> {
                override fun onAnswer(answer: ByteArray, rcode: Int) {
                    if (rcode == 0) ctx.rawSuccess(answer) else ctx.errorCode(rcode)
                    done.countDown()
                }

                override fun onError(error: DnsResolver.DnsException) {
                    (error.cause as? ErrnoException)?.let { ctx.errnoCode(it.errno) } ?: ctx.errorCode(2)
                    done.countDown()
                }
            },
        )
        done.await()
    }

    override fun lookup(ctx: ExchangeContext, network: String, domain: String) {
        val net = NetworkMonitor.defaultNetwork ?: error("no default network")
        val done = CountDownLatch(1)
        val signal = CancellationSignal()
        ctx.onCancel {
            signal.cancel()
            done.countDown()
        }
        val callback = object : DnsResolver.Callback<List<InetAddress>> {
            override fun onAnswer(answer: List<InetAddress>, rcode: Int) {
                if (rcode == 0) {
                    ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
                } else {
                    ctx.errorCode(rcode)
                }
                done.countDown()
            }

            override fun onError(error: DnsResolver.DnsException) {
                (error.cause as? ErrnoException)?.let { ctx.errnoCode(it.errno) } ?: ctx.errorCode(2)
                done.countDown()
            }
        }
        val type = when {
            network.endsWith("4") -> DnsResolver.TYPE_A
            network.endsWith("6") -> DnsResolver.TYPE_AAAA
            else -> null
        }
        val resolver = DnsResolver.getInstance()
        if (type != null) {
            resolver.query(net, domain, type, DnsResolver.FLAG_NO_RETRY, executor, signal, callback)
        } else {
            resolver.query(net, domain, DnsResolver.FLAG_NO_RETRY, executor, signal, callback)
        }
        done.await()
    }
}
