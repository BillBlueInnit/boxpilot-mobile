package io.github.billblueinnit.boxpilot.core

import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** Quick Settings tile: connect and disconnect without opening the app. */
class BoxTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            state = if (BoxVpnService.running) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        if (!BoxVpnService.running && VpnService.prepare(this) != null) {
            // The consent dialog needs an activity.
            openApp()
            return
        }
        if (Core.ensure(this) != null) return
        // The engine decides what runs; it answers through the VPN service,
        // which refreshes this tile.
        Core.invokeAsync(if (Native.isRunning()) "stop" else "start")
        qsTile?.apply {
            state = Tile.STATE_UNAVAILABLE
            updateTile()
        }
    }

    @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
    private fun openApp() {
        val intent = Core.launchIntent(this).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE))
        } else {
            startActivityAndCollapse(intent)
        }
    }
}
