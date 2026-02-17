package com.example.hover_note

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object OverlayPlugin {
    private const val CHANNEL = "overlay_launcher"

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openEditPage" -> {
                    val noteId = call.argument<Int>("id")
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