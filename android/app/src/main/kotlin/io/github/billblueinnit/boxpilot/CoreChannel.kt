package io.github.billblueinnit.boxpilot

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.Libbox
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * The Dart side's handle on the embedded core.
 *
 * Methods (`boxpilot/core`): `info`, `prepare`, `start(config)`, `stop`.
 * Events (`boxpilot/core/events`): `{type: logs, lines}`, `{type: stopped, reason}`,
 * `{type: toggle}` (quick-settings tile), `{type: disconnect}` (notification).
 */
class CoreChannel(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val main = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var events: EventChannel.EventSink? = null

    /** The VPN consent dialog, answered by [MainActivity]. */
    var pendingConsent: CompletableDeferred<Boolean>? = null

    /** Config handed to the service, and the answer to the pending `start`. */
    @Volatile var pendingConfig: String? = null
    @Volatile var pendingStart: CompletableDeferred<String>? = null

    init {
        MethodChannel(messenger, "boxpilot/core").setMethodCallHandler(this)
        EventChannel(messenger, "boxpilot/core/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                events = sink
            }

            override fun onCancel(arguments: Any?) {
                events = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> result.success(
                mapOf(
                    "coreVersion" to Libbox.version(),
                    "dataDir" to BoxPilotApp.instance.engineDir.path,
                    "running" to BoxVpnService.running,
                    // Material You: the wallpaper's accent seeds the app's colour scheme.
                    "accent" to if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                        context.getColor(android.R.color.system_accent1_500)
                    } else {
                        null
                    },
                ),
            )

            "prepare" -> scope.launch {
                val granted = requestConsent()
                main.post { result.success(granted) }
            }

            "start" -> {
                val config = call.argument<String>("config") ?: ""
                scope.launch {
                    val error = start(config)
                    main.post { result.success(error) }
                }
            }

            "stop" -> scope.launch {
                BoxVpnService.instance?.stopCore("stopped")
                main.post { result.success(null) }
            }

            else -> result.notImplemented()
        }
    }

    /** Shows the system VPN consent dialog when the app is not yet allowed. */
    private suspend fun requestConsent(): Boolean {
        val intent = android.net.VpnService.prepare(context) ?: return true
        val activity = MainActivity.current ?: return false
        val deferred = CompletableDeferred<Boolean>()
        pendingConsent = deferred
        main.post { activity.askVpnConsent(intent) }
        return deferred.await()
    }

    /** Starts (or reloads) the core. Returns an empty string, or the error. */
    private suspend fun start(config: String): String {
        if (android.net.VpnService.prepare(context) != null) {
            return "VPN permission is required"
        }
        BoxVpnService.instance?.let { service ->
            return service.startCore(config)
        }
        val answer = CompletableDeferred<String>()
        pendingStart = answer
        pendingConfig = config
        main.post {
            ContextCompat.startForegroundService(context, Intent(context, BoxVpnService::class.java))
        }
        return withTimeoutOrNull(30_000) { answer.await() } ?: "the VPN service did not start"
    }

    fun emitLogs(lines: List<String>) = emit(mapOf("type" to "logs", "lines" to lines))

    fun emitStopped(reason: String) = emit(mapOf("type" to "stopped", "reason" to reason))

    fun emitToggle() = emit(mapOf("type" to "toggle"))

    /** Asks the engine to disconnect; `false` when no UI isolate is listening. */
    fun requestDisconnect(): Boolean {
        if (events == null) return false
        emit(mapOf("type" to "disconnect"))
        return true
    }

    private fun emit(event: Map<String, Any>) {
        main.post { events?.success(event) }
    }
}
