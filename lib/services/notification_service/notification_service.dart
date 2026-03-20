import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:hover_note/main.dart';
import 'package:hover_note/models/note_database.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tzData;

class NotificationService {
  static Future<void> initialize() async {
    // ✅ Initialize timezone
    tzData.initializeTimeZones();

    await AwesomeNotifications().initialize('resource://drawable/ic_note_sticky', [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'Notification channel for reminders',
        importance: NotificationImportance.High,
      ),
    ], debug: true);

    // ✅ Ask for permissions including Precise Alarms
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications(
        permissions: [
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.Badge,
          NotificationPermission.Vibration,
          NotificationPermission.Light,
        ],
      );
    }

    // Explicitly ask for precise alarms permission (needed on Android 12+ for exact scheduling)
    List<NotificationPermission> preciseAlarmPerm = await AwesomeNotifications().checkPermissionList(
      channelKey: 'basic_channel',
      permissions: [NotificationPermission.PreciseAlarms],
    );

    if (!preciseAlarmPerm.contains(NotificationPermission.PreciseAlarms)) {
      await AwesomeNotifications().requestPermissionToSendNotifications(
        permissions: [NotificationPermission.PreciseAlarms],
      );
    }

    // ✅ Background execution requires listeners to be set to be reliable
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {}

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {}

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {}

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // When a notification is clicked, refresh the database if we can
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        context.read<NoteDatabase>().fetchNotes();
      }
    } catch (e) {
      // Handle potential errors if context is not available
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'basic_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        wakeUpScreen: true,
        category: NotificationCategory.Reminder,
        largeIcon: 'resource://drawable/notification_icon',
      ),
    );
  }

  /// ✅ Schedule notification at exact `DateTime`
  static Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'basic_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        wakeUpScreen: true,
        category: NotificationCategory.Reminder,
        largeIcon: 'resource://drawable/notification_icon',
      ),
      schedule: NotificationCalendar.fromDate(
        date: scheduledTime.toLocal(),
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
  }
}
