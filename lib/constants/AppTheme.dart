import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      surface: Colors.white,
      onSurface: Colors.black,
      primary: Color.fromRGBO(255, 205, 7, 1),
      onPrimary: Colors.white,
      secondary: Color.fromRGBO(20, 255, 20, 1),
      onSecondary: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      surface: Color(0xFF121212),
      onSurface: Colors.white,
      primary: Color.fromRGBO(255, 205, 7, 1),
      onPrimary: Colors.white,
      secondary: Color.fromRGBO(20, 255, 20, 1),
      onSecondary: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF121212),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
  );
}
