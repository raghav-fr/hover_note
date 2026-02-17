import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for MethodChannel
import 'package:flutter_overlay_window/flutter_overlay_window.dart'; // Required for listener
import 'package:hover_note/models/note_database.dart';
import 'package:hover_note/overlay/hoverOverlay.dart';
import 'package:hover_note/screens/homepage/HomePage.dart';
import 'package:hover_note/services/notification_service/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

// Global key to allow navigation from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HoverOverlay());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  // The channel name must match your Kotlin file
  static const MethodChannel _channel = MethodChannel('overlay_launcher');

  @override
  void initState() {
    super.initState();

    // --- THE GLOBAL BRIDGE LISTENER ---
    // This catches the message from the Overlay Engine
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && data['command'] == 'open_edit_page') {
        // Since we are in the Main Engine, the MethodChannel is registered!
        // This triggers the Kotlin code to bring the app to the front.
        _channel.invokeMethod('openEditPage', {'id': data['id']});
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