import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hover_note/models/note_database.dart';
import 'package:hover_note/screens/homepage/HomePage.dart';
import 'package:hover_note/services/notification_service/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

// Global key to allow navigation from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await NotificationService.initialize();
  await NoteDatabase.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (context) => NoteDatabase(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // The channel must match the one in OverlayPlugin.kt
  static const MethodChannel _channel = MethodChannel('overlay_launcher');

  @override
  void initState() {
    super.initState();

    // --- NATIVE OVERLAY CALLBACK HANDLER ---
    // Listen for events sent FROM the native NativeOverlayService TO Flutter.
    // These are triggered when the user interacts with a native overlay window.
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {

        // User tapped the ✕ close button on a native overlay
        case 'onOverlayClosed':
          final id = call.arguments['id'] as int;
          onOverlayClosed(id);  // Updates _activeOverlayIds in HomePage.dart
          break;

        // User tapped the ✎ edit button on a native overlay
        case 'openEditPage':
          final id = call.arguments['id'] as int;
          // Use OverlayPlugin's native openEditPage to bring app to front
          _channel.invokeMethod('openEditPage', {'id': id});
          break;

        // Native service is expanding a minimized bubble and needs the note's text/color
        case 'requestNoteData':
          final id = call.arguments['id'] as int;
          // Look up the note from the database
          final db = navigatorKey.currentContext
              ?.read<NoteDatabase>();
          if (db != null) {
            try {
              final note = db.currentNotes.firstWhere((n) => n.id == id);
              // Send the data back to native so it can rebuild the expanded view
              _channel.invokeMethod('expandOverlay', {
                'id': note.id,
                'text': note.text,
                'color': note.color,
              });
            } catch (_) {
              // Note not found — ignore
            }
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, _, _) {
        return MaterialApp(
          navigatorKey: navigatorKey, // Attach the global key here
          debugShowCheckedModeBanner: false,
          title: 'Hover Note',
          theme: ThemeData(),
          home: const Homepage(),
        );
      },
    );
  }
}