package com.example.hover_note

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * OverlayPlugin
 * -------------
 * The MethodChannel bridge between Flutter ↔ Native.
 *
 * Flutter calls methods on the "overlay_launcher" channel, and this plugin
 * either handles them directly or forwards them to NativeOverlayService.
 *
 * IMPORTANT: Dart `int` is 64-bit, so the platform channel may send values
 * as Java Long (not Int). We use a helper `getIntArg()` that handles both.
 */
object OverlayPlugin {
    private const val CHANNEL = "overlay_launcher"
    private const val TAG = "OverlayPlugin"

    /**
     * Safely extracts an integer argument from a MethodCall.
     * Dart int → Java Integer (if value fits 32b) or Long (if 64b).
     * This helper handles BOTH cases.
     */
    private fun MethodCall.getIntArg(key: String): Int? {
        val value = argument<Any>(key) ?: return null
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toInt()
            else -> null
        }
    }

    fun register(engine: FlutterEngine, context: Context) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)

        // Store the channel in the Service companion so native → Flutter communication works
        NativeOverlayService.methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            Log.d(TAG, "Received method call: ${call.method}, args: ${call.arguments}")

            when (call.method) {

                // ──────────────────────────────────────────
                // Show a new native overlay for a note
                // ──────────────────────────────────────────
                "showNativeOverlay" -> {
                    val id = call.getIntArg("id")
                    val text = call.argument<String>("text")
                    val color = call.getIntArg("color")

                    Log.d(TAG, "showNativeOverlay: id=$id, text=$text, color=$color")

                    if (id == null || text == null || color == null) {
                        result.error("BAD_ARGS", "Missing id=$id, text=$text, or color=$color", null)
                        return@setMethodCallHandler
                    }

                    val intent = Intent(context, NativeOverlayService::class.java).apply {
                        action = "SHOW_OVERLAY"
                        putExtra("id", id)
                        putExtra("text", text)
                        putExtra("color", color)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }

                    result.success(true)
                }

                // ──────────────────────────────────────────
                // Close a specific note's overlay
                // ──────────────────────────────────────────
                "closeNativeOverlay" -> {
                    val id = call.getIntArg("id")
                    if (id == null) {
                        result.error("BAD_ARGS", "Missing id", null)
                        return@setMethodCallHandler
                    }

                    val intent = Intent(context, NativeOverlayService::class.java).apply {
                        action = "CLOSE_OVERLAY"
                        putExtra("id", id)
                    }
                    context.startService(intent)
                    result.success(true)
                }

                // ──────────────────────────────────────────
                // Close all overlays
                // ──────────────────────────────────────────
                "closeAllOverlays" -> {
                    val intent = Intent(context, NativeOverlayService::class.java).apply {
                        action = "CLOSE_ALL"
                    }
                    context.startService(intent)
                    result.success(true)
                }

                // ──────────────────────────────────────────
                // Check if overlay permission is granted
                // ──────────────────────────────────────────
                "checkOverlayPermission" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(context)
                    } else {
                        true
                    }
                    Log.d(TAG, "checkOverlayPermission: $granted")
                    result.success(granted)
                }

                // ──────────────────────────────────────────
                // Request overlay permission (opens system settings)
                // ──────────────────────────────────────────
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:${context.packageName}")
                        )
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        context.startActivity(intent)
                    }
                    result.success(true)
                }

                // ──────────────────────────────────────────
                // Respond to requestNoteData (expand a minimized bubble)
                // ──────────────────────────────────────────
                "expandOverlay" -> {
                    val id = call.getIntArg("id")
                    val text = call.argument<String>("text")
                    val color = call.getIntArg("color")

                    if (id != null && text != null && color != null) {
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            val intent = Intent(context, NativeOverlayService::class.java).apply {
                                action = "SHOW_OVERLAY"
                                putExtra("id", id)
                                putExtra("text", text)
                                putExtra("color", color)
                            }
                            context.startService(intent)
                        }
                    }
                    result.success(true)
                }

                // ──────────────────────────────────────────
                // Existing: open edit page (bring app to front)
                // ──────────────────────────────────────────
                "openEditPage" -> {
                    val noteId = call.getIntArg("id")
                    val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    intent?.apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("open_edit", true)
                        putExtra("note_id", noteId)
                    }
                    context.startActivity(intent)
                    result.success(true)
                }

                // ──────────────────────────────────────────
                // Existing: get initial intent data
                // ──────────────────────────────────────────
                "getInitialIntent" -> {
                    val activityIntent = (context as? MainActivity)?.intent
                    val openEdit = activityIntent?.getBooleanExtra("open_edit", false) ?: false
                    val noteId = activityIntent?.getIntExtra("note_id", -1) ?: -1
                    
                    val map = HashMap<String, Any>()
                    map["open_edit"] = openEdit
                    map["note_id"] = noteId
                    result.success(map)
                }

                else -> result.notImplemented()
            }
        }
    }
}