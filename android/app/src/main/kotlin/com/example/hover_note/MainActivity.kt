package com.example.hover_note

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "hover_note_notifications"
    private val TAG = "MainActivity"
    private val NOTIFICATION_PERMISSION_CODE = 1001

    // Required to update the intent when the app is brought to front from the overlay
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register existing overlay channel
        OverlayPlugin.register(flutterEngine, this)

        // Register notification channel
        val notifChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
        notifChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    NotificationHelper.createChannel(this)

                    // Request POST_NOTIFICATIONS permission (Android 13+)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                            != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_CODE
                            )
                        }
                    }

                    // Request exact alarm permission (Android 12+)
                    if (!NotificationHelper.canScheduleExactAlarms(this)) {
                        NotificationHelper.openExactAlarmSettings(this)
                    }

                    result.success(true)
                }

                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "Hover Note"
                    val body = call.argument<String>("body") ?: ""
                    val id = (System.currentTimeMillis() % 100000).toInt()

                    NotificationHelper.show(this, id, title, body)
                    result.success(true)
                }

                "scheduleNotification" -> {
                    val title = call.argument<String>("title") ?: "Hover Note"
                    val body = call.argument<String>("body") ?: ""
                    val epochMillis = call.argument<Number>("epochMillis")?.toLong()

                    if (epochMillis == null) {
                        result.error("BAD_ARGS", "Missing epochMillis", null)
                        return@setMethodCallHandler
                    }

                    val id = (epochMillis % 100000).toInt()
                    NotificationHelper.schedule(this, id, title, body, epochMillis)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // Send notification-click event to Flutter when app opens from notification
        handleNotificationClick(flutterEngine)
    }

    private fun handleNotificationClick(flutterEngine: FlutterEngine) {
        if (intent?.getBooleanExtra("notification_clicked", false) == true) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            channel.invokeMethod("onNotificationClicked", null)
            Log.d(TAG, "Forwarded notification click to Flutter")
        }
    }
}