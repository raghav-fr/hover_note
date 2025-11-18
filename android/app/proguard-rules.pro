# ===== Overlay entrypoint (match your Dart function name) =====
# KEEP the overlay entrypoint EXACTLY
-keepclassmembers class * {
    void overlayMain();
}


# Keep Flutter embedding classes used to start isolates / engines
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.**

# Keep Play Core split install API (Deferred components)
-keep class com.google.android.play.core.splitinstall.** { *; }
-dontwarn com.google.android.play.core.splitinstall.**

# Keep Play Core Tasks API
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.tasks.**

# Keep the overlay plugin classes (some plugin package names vary)
-keep class com.pravera.flutter_overlay_window.** { *; }
-dontwarn com.pravera.flutter_overlay_window.**

# Keep Isar
-keep class isar.** { *; }
-dontwarn isar.**

# Keep Awesome Notifications
-keep class me.carda.awesome_notifications.** { *; }
-dontwarn me.carda.awesome_notifications.**

# Safety: keep main Flutter native entrypoints (prevent accidental tree-shaking)
-keepclassmembers class io.flutter.embedding.engine.FlutterJNI {
    public *; 
}
