package io.github.billblueinnit.boxpilot

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.net.ConnectivityManager
import android.os.Build
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import java.io.File

/**
 * One Flutter engine for the whole process. The engine (and with it the Rust
 * `Engine` and its scheduler) outlives the activity, so the VPN service keeps a
 * working controller after the UI is closed. The foreground VPN service keeps
 * the process alive while connected.
 */
class BoxPilotApp : Application() {
    companion object {
        const val ENGINE_ID = "main"
        const val CHANNEL_VPN = "vpn"

        lateinit var instance: BoxPilotApp
            private set

        val connectivity: ConnectivityManager
            get() = instance.getSystemService(ConnectivityManager::class.java)
    }

    lateinit var core: CoreChannel
        private set

    /** Where settings, subscriptions and rule-sets live (the engine's `Paths` root). */
    val engineDir: File
        get() = File(filesDir, "BoxPilot")

    override fun onCreate() {
        super.onCreate()
        instance = this
        setupLibbox()
        createNotificationChannel()

        val engine = FlutterEngine(this)
        core = CoreChannel(this, engine.dartExecutor.binaryMessenger)
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(this)
        loader.ensureInitializationComplete(this, null)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    private fun setupLibbox() {
        val working = File(filesDir, "core").apply { mkdirs() }
        val options = SetupOptions().also {
            it.basePath = filesDir.path
            it.workingPath = working.path
            it.tempPath = cacheDir.path
            it.fixAndroidStack = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
            it.logMaxLines = 3000
            it.debug = false
            it.crashReportSource = "BoxPilot"
            it.appVersion = BuildConfig.VERSION_CODE.toString()
            it.appMarketingVersion = BuildConfig.VERSION_NAME
            it.oomKillerEnabled = true
        }
        Libbox.setup(options)
        Libbox.setLocale(java.util.Locale.getDefault().toLanguageTag().replace('-', '_'))
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_VPN,
            getString(R.string.notification_channel),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
