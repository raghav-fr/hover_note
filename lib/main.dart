import 'package:flutter/material.dart';
import 'package:hover_note/models/note_database.dart';
// import 'package:hover_note/screens/createEditPage/createEditPage.dart';
import 'package:hover_note/screens/homepage/HomePage.dart';
import 'package:hover_note/services/notification_service/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

void main() async {
  //initialize note hive db
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
          title: 'Flutter Demo',
          theme: ThemeData(),
          home: const Homepage(),
        );
      },
    );
  }
}
