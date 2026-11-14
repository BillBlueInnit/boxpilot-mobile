package io.github.billblueinnit.boxpilot.core

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.VpnService
import android.os.Build
import android.util.Base64
import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.CodedException
import expo.modules.kotlin.functions.Coroutine
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import io.nekohasekai.libbox.Libbox
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/**
 * The JavaScript side's handle on the engine and the VPN (`modules/boxpilot-core/index.ts`).
 *
 * `invoke(method, args)` is the engine (see `rust/src/api.rs`); the rest is what
 * only the platform knows: VPN consent, per-app proxy, installed apps and the
 * wallpaper colours. Engine events arrive as `onEvent`, `{json}`.
 */
class BoxpilotCoreModule : Module() {
    private val context: Context
        get() = appContext.reactContext ?: throw CodedException("The app is not ready")

    /** The system VPN consent dialog in flight. */
    private var pendingConsent: Promise? = null

    override fun definition() = ModuleDefinition {
        Name("BoxpilotCore")

        Events("onEvent")

        OnCreate {
            Core.ensure(context)?.let { android.util.Log.e("BoxPilot", it) }
            Core.listener = { json -> sendEvent("onEvent", mapOf("json" to json)) }
        }

        OnDestroy {
            Core.listener = null
        }

        Function("info") {
            mapOf(
                "coreVersion" to Libbox.version(),
                "dataDir" to Core.dataDir.path,
                "vpnReady" to Core.vpnReady,
                "perApp" to true,
            )
        }

        AsyncFunction("invoke") Coroutine { method: String, args: String ->
            withContext(Dispatchers.IO) { Native.invoke(method, args) }
        }

        // Shows the system VPN consent dialog when the app is not yet allowed.
        // Only Connect calls this: a permission prompt needs the user's tap.
        AsyncFunction("prepare") { promise: Promise ->
            val intent = VpnService.prepare(context)
            if (intent == null) {
                promise.resolve(true)
                return@AsyncFunction
            }
            val activity = appContext.currentActivity
            if (activity == null) {
                promise.resolve(false)
                return@AsyncFunction
            }
            pendingConsent?.resolve(false)
            pendingConsent = promise
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_VPN)
        }

        OnActivityResult { _, payload ->
            if (payload.requestCode == REQUEST_VPN) {
                pendingConsent?.resolve(payload.resultCode == Activity.RESULT_OK)
                pendingConsent = null
            }
        }

        // Ends the process. After a reset the engine holds deleted state; the
        // next launch starts clean.
        Function("exit") {
            BoxVpnService.instance?.stopSelf()
            android.os.Process.killProcess(android.os.Process.myPid())
        }

        // ------------------------------------------------------ per-app proxy

        Function("perApp") {
            mapOf("mode" to PerApp.mode(context), "packages" to PerApp.packages(context).toList())
        }

        Function("setPerApp") { mode: String, packages: List<String> ->
            PerApp.save(context, mode, packages)
        }

        AsyncFunction("apps") Coroutine { ->
            withContext(Dispatchers.IO) {
                PerApp.launchableApps(context).map { mapOf("package" to it.first, "label" to it.second) }
            }
        }

        // An app's icon as a PNG data URI, or null.
        AsyncFunction("appIcon") Coroutine { pkg: String ->
            withContext(Dispatchers.IO) { runCatching { iconDataUri(pkg) }.getOrNull() }
        }

        // ------------------------------------------------------- Material You

        // The wallpaper's tonal palettes (Android 12+), as `accent1_600` -> `#rrggbb`.
        Function("palette") {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return@Function null
            val res = context.resources
            buildMap {
                for (family in listOf("accent1", "accent2", "accent3", "neutral1", "neutral2")) {
                    for (tone in TONES) {
                        val id = res.getIdentifier("system_${family}_$tone", "color", "android")
                        if (id != 0) put("${family}_$tone", String.format("#%06x", context.getColor(id) and 0xFFFFFF))
                    }
                }
            }
        }
    }

    private fun iconDataUri(pkg: String): String {
        val drawable = context.packageManager.getApplicationIcon(pkg)
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        val png = ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            it.toByteArray()
        }
        return "data:image/png;base64," + Base64.encodeToString(png, Base64.NO_WRAP)
    }

    companion object {
        private const val REQUEST_VPN = 0xB0C5
        private val TONES = listOf(0, 10, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000)
    }
}
