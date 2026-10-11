package com.bayanrme.bayan_rme

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    /**
     * Some devices keep apps at 60 Hz unless the window asks for a faster
     * display mode. Prefer the highest refresh rate offered at the current
     * resolution (the resolution itself is never changed). No-op on screens
     * that only support 60 Hz.
     */
    private fun requestHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val activeDisplay: Display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display ?: return
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }

        val current = activeDisplay.mode
        val fastest = activeDisplay.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate } ?: return

        // Set it explicitly even if it matches the current mode: some OEMs
        // still throttle apps to 60 Hz unless the window states a preference.
        window.attributes = window.attributes.apply {
            preferredDisplayModeId = fastest.modeId
        }
    }
}
