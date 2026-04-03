import 'package:flutter/services.dart';
import 'package:hover_note/main.dart';
import 'package:hover_note/models/note_database.dart';
import 'package:provider/provider.dart';

class NotificationService {
  static const MethodChannel _channel =
      MethodChannel('hover_note_notifications');

  static Future<void> initialize() async {
    // Set up callback for notification clicks from native
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationClicked') {
        try {
          final context = navigatorKey.currentContext;
          if (context != null) {
            context.read<NoteDatabase>().fetchNotes();
          }
        } catch (e) {
          // Handle context errors
        }
      }
    });

    // Initialize native notification channel and request permissions
    await _channel.invokeMethod('initialize');
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await _channel.invokeMethod('showNotification', {
      'title': title,
      'body': body,
    });
  }

  static Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await _channel.invokeMethod('scheduleNotification', {
      'title': title,
      'body': body,
      'epochMillis': scheduledTime.millisecondsSinceEpoch,
    });
  }
}
