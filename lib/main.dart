import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hover_note/models/note_database.dart';
import 'package:hover_note/overlay/hoverOverlay.dart' ;
// import 'package:hover_note/screens/createEditPage/createEditPage.dart';
import 'package:hover_note/screens/homepage/HomePage.dart';
import 'package:hover_note/services/notification_service/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';


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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, _, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Hover Note',
          theme: ThemeData(),
          home: const Homepage(),
        );
      },
    );
  }
}
