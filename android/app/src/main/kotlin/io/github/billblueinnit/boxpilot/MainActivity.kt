package io.github.billblueinnit.boxpilot

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    companion object {
        private const val REQUEST_VPN = 1

        /** The visible activity, for the VPN consent dialog. */
        @Volatile
        var current: MainActivity? = null
            private set
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        current = this
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

    fun askVpnConsent(intent: Intent) {
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_VPN)
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
