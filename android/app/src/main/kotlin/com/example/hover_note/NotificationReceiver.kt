package com.example.hover_note

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * NotificationReceiver
 * --------------------
 * Fired by AlarmManager when a scheduled notification is due.
 * Extracts the title/body from the intent and posts the notification.
 */
class NotificationReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "NotificationReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "Hover Note"
        val body = intent.getStringExtra("body") ?: ""

        Log.d(TAG, "Alarm fired for notification id=$id")

        // Show the notification
        NotificationHelper.show(context, id, title, body)

        // Clean up from SharedPreferences since it has fired
        NotificationHelper.removeScheduledNotification(context, id)
    }
}
