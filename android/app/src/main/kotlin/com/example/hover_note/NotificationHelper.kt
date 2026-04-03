package com.example.hover_note

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * NotificationHelper
 * ------------------
 * Pure-Kotlin notification helper. Handles channel creation,
 * showing notifications, and scheduling via AlarmManager.
 *
 * Icons used:
 *   - Small icon (status bar): R.drawable.ic_small_noti
 *   - Large icon (expanded):  R.drawable.ic_notification
 */
object NotificationHelper {
    private const val TAG = "NotificationHelper"
    private const val CHANNEL_ID = "basic_channel"
    private const val CHANNEL_NAME = "Basic Notifications"
    private const val CHANNEL_DESC = "Notification channel for reminders"
    private const val PREFS_NAME = "scheduled_notifications"

    /**
     * Create the notification channel (required on API 26+).
     */
    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESC
                enableVibration(true)
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }

    /**
     * Post a notification immediately.
     */
    fun show(context: Context, id: Int, title: String, body: String) {
        // Intent to open the app when notification is tapped
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_clicked", true)
        }
        val pendingIntent = PendingIntent.getActivity(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )



        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        // Ensure channel exists
        createChannel(context)

        try {
            NotificationManagerCompat.from(context).notify(id, notification)
            Log.d(TAG, "Notification shown: id=$id, title=$title")
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing POST_NOTIFICATIONS permission", e)
        }
    }

    /**
     * Schedule a notification at a specific epoch time (milliseconds).
     * Uses AlarmManager for exact alarm delivery.
     */
    fun schedule(context: Context, id: Int, title: String, body: String, epochMillis: Long) {
        // Persist the notification data so we can reschedule after reboot
        saveScheduledNotification(context, id, title, body, epochMillis)

        val intent = Intent(context, NotificationReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, epochMillis, pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP, epochMillis, pendingIntent
                )
            }
            Log.d(TAG, "Notification scheduled: id=$id at $epochMillis")
        } catch (e: SecurityException) {
            Log.e(TAG, "Cannot schedule exact alarm, permission denied", e)
        }
    }

    /**
     * Check if POST_NOTIFICATIONS permission is granted (API 33+).
     */
    fun hasNotificationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /**
     * Check if exact alarm permission is granted (API 31+).
     */
    fun canScheduleExactAlarms(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    /**
     * Open the exact alarm settings page (API 31+).
     */
    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        }
    }

    // ── SharedPreferences helpers for boot rescheduling ──

    private fun saveScheduledNotification(
        context: Context, id: Int, title: String, body: String, epochMillis: Long
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString("notif_${id}_title", title)
            .putString("notif_${id}_body", body)
            .putLong("notif_${id}_time", epochMillis)
            .apply()

        // Also keep track of all IDs
        val ids = prefs.getStringSet("all_ids", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        ids.add(id.toString())
        prefs.edit().putStringSet("all_ids", ids).apply()
    }

    fun removeScheduledNotification(context: Context, id: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .remove("notif_${id}_title")
            .remove("notif_${id}_body")
            .remove("notif_${id}_time")
            .apply()

        val ids = prefs.getStringSet("all_ids", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        ids.remove(id.toString())
        prefs.edit().putStringSet("all_ids", ids).apply()
    }

    /**
     * Re-schedule all persisted notifications (called after boot).
     */
    fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet("all_ids", emptySet()) ?: emptySet()
        val now = System.currentTimeMillis()

        for (idStr in ids) {
            val id = idStr.toIntOrNull() ?: continue
            val title = prefs.getString("notif_${id}_title", null) ?: continue
            val body = prefs.getString("notif_${id}_body", null) ?: continue
            val time = prefs.getLong("notif_${id}_time", 0L)

            if (time > now) {
                // Still in the future — reschedule
                schedule(context, id, title, body, time)
                Log.d(TAG, "Rescheduled notification $id after boot")
            } else {
                // Already past — clean up
                removeScheduledNotification(context, id)
            }
        }
    }
}
