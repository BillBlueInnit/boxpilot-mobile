package io.github.billblueinnit.boxpilot.core

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.VpnService
import android.os.Build
import androidx.core.content.ContextCompat
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

/**
 * The engine for the whole process. It outlives the activity and the JavaScript
 * runtime: the foreground VPN service keeps the process alive while connected,
 * so the engine's scheduler, Auto picks and the tile keep working with the UI
 * closed. Whoever comes first (the UI, the tile) calls [ensure].
 */
object Core : Native.Host {
    const val CHANNEL_VPN = "vpn"

    private lateinit var app: Context
    private var ready = false
    private val worker = Executors.newSingleThreadExecutor()

    /** Engine events for the UI, when one is attached. */
    @Volatile
    var listener: ((String) -> Unit)? = null

    /** Config handed to the service, and the answer to the pending start. */
    @Volatile
    var pendingConfig: String? = null

    @Volatile
    var pendingStart: CompletableDeferred<String>? = null

    val connectivity: ConnectivityManager
        get() = app.getSystemService(ConnectivityManager::class.java)

    /** Where settings, subscriptions and rule-sets live (the engine's `Paths` root). */
    val dataDir: File
        get() = File(app.filesDir, "BoxPilot")

    val vpnReady: Boolean
        get() = VpnService.prepare(app) == null

    /** Sets up libbox and the engine once. Returns an error text, or null. */
    @Synchronized
    fun ensure(context: Context): String? {
        if (ready) return null
        app = context.applicationContext
        setupLibbox()
        createNotificationChannel()
        val answer = Native.init(dataDir.path, Libbox.version(), vpnReady, this)
        if (answer.startsWith("error")) return answer
        ready = true
        return null
    }

    /** An engine call nobody waits for (tile, notification). */
    fun invokeAsync(method: String, args: String = "") {
        worker.execute { Native.invoke(method, args) }
    }

    /** The service's core stopped on its own (VPN revoked, stopped by the core). */
    fun coreExited(reason: String) {
        invokeAsync("coreExited", JSONObject().put("reason", reason).toString())
    }

    fun launchIntent(context: Context): Intent =
        (context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent())
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)

    // ------------------------------------------------------------ Native.Host

    /** Starts (or reloads) the core. Never prompts: permission is asked on Connect. */
    override fun startCore(config: String): String = runBlocking {
        if (!vpnReady) return@runBlocking "VPN permission is required"
        BoxVpnService.instance?.let { return@runBlocking it.startCore(config) }
        val answer = CompletableDeferred<String>()
        pendingStart = answer
        pendingConfig = config
        ContextCompat.startForegroundService(app, Intent(app, BoxVpnService::class.java))
        withTimeoutOrNull(30_000) { answer.await() } ?: "the VPN service did not start"
    }

    override fun stopCore() {
        runBlocking { BoxVpnService.instance?.stopCore("stopped") }
    }

    override fun onEvent(json: String) {
        listener?.invoke(json)
    }

    // ------------------------------------------------------------------ setup

    private fun setupLibbox() {
        val working = File(app.filesDir, "core").apply { mkdirs() }
        val info = app.packageManager.getPackageInfo(app.packageName, 0)
        val options = SetupOptions().also {
            it.basePath = app.filesDir.path
            it.workingPath = working.path
            it.tempPath = app.cacheDir.path
            it.fixAndroidStack = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
            it.logMaxLines = 3000
            it.debug = false
            it.crashReportSource = "BoxPilot"
            it.appVersion = info.longVersionCode.toString()
            it.appMarketingVersion = info.versionName ?: ""
            it.oomKillerEnabled = true
        }
        Libbox.setup(options)
        Libbox.setLocale(java.util.Locale.getDefault().toLanguageTag().replace('-', '_'))
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_VPN,
            app.getString(R.string.notification_channel),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setShowBadge(false)
        }
        app.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
