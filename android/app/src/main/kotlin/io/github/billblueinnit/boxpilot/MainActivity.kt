package io.github.billblueinnit.boxpilot

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    companion object {
        private const val REQUEST_VPN = 1
        private const val REQUEST_NOTIFICATIONS = 2

        /** The visible activity, for the VPN consent dialog. */
        @Volatile
        var current: MainActivity? = null
            private set
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        current = this
        if (savedInstanceState == null) handleImport(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleImport(intent)
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }

    // The process-wide engine from BoxPilotApp, kept when the activity goes.
    override fun getCachedEngineId(): String = BoxPilotApp.ENGINE_ID

    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(BoxPilotApp.ENGINE_ID)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    /** `clash://install-config?url=…`, `sing-box://import-remote-profile?url=…`, `boxpilot://…`. */
    private fun handleImport(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        BoxPilotApp.instance.core.emitImport(uri.toString())
    }

    fun askVpnConsent(intent: Intent) {
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_VPN)
    }

    /** Asked once, right after VPN consent: the VPN notification needs it on Android 13+. */
    fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        val prefs = getSharedPreferences("prompts", MODE_PRIVATE)
        if (prefs.getBoolean("notifications_asked", false)) return
        prefs.edit().putBoolean("notifications_asked", true).apply()
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    @Deprecated("Activity result API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN) {
            val core = BoxPilotApp.instance.core
            core.pendingConsent?.complete(resultCode == RESULT_OK)
            core.pendingConsent = null
        }
    }
}
