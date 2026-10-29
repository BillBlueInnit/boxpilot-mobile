package io.github.billblueinnit.boxpilot

import android.content.Context
import android.content.Intent
import io.nekohasekai.libbox.OverrideOptions

/**
 * Per-app proxy: which apps the VPN carries. Android-only (iOS has no per-app VPN
 * outside device management), so it lives here rather than in the engine's
 * settings, and reaches the core through libbox's override options.
 */
object PerApp {
    const val ALL = "all"
    const val INCLUDE = "include"
    const val EXCLUDE = "exclude"

    private const val PREFS = "per_app"

    fun mode(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("mode", ALL) ?: ALL

    fun packages(context: Context): Set<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getStringSet("packages", emptySet()).orEmpty()

    fun save(context: Context, mode: String, packages: List<String>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("mode", mode)
            .putStringSet("packages", packages.toSet())
            .apply()
    }

    /** The override options for the core: BoxPilot itself always stays in the VPN. */
    fun overrideOptions(context: Context): OverrideOptions {
        val own = context.packageName
        val list = packages(context)
        return OverrideOptions().apply {
            when (mode(context)) {
                INCLUDE -> if (list.isNotEmpty()) includePackage = (list + own).toList().toStringIterator()
                EXCLUDE -> if (list.isNotEmpty()) excludePackage = (list - own).toList().toStringIterator()
            }
        }
    }

    /** Apps with a launcher entry, as (package, label), sorted by label. */
    fun launchableApps(context: Context): List<Pair<String, String>> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != context.packageName }
            .map { it.packageName to pm.getApplicationLabel(it).toString() }
            .sortedBy { it.second.lowercase() }
    }
}
