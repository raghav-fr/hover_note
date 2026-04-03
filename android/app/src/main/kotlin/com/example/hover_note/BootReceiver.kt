package com.example.hover_note

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BootReceiver
 * ------------
 * Listens for BOOT_COMPLETED and MY_PACKAGE_REPLACED to
 * reschedule all pending notifications after a device reboot
 * or app update.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.d(TAG, "Boot/update detected — rescheduling notifications")
            NotificationHelper.createChannel(context)
            NotificationHelper.rescheduleAll(context)
        }
    }
}
