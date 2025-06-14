// theme.dart
import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF50D890),
  scaffoldBackgroundColor: const Color(0xFFEFFFFB),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFEFFFFB),
    foregroundColor: Color(0xFF272727),
  ),
  iconTheme: const IconThemeData(color: Color(0xFF272727)),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFF272727)),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF50D890),
    primary: Color(0xFF50D890),
    secondary: Color(0xFF4F98CA),
    background: Color(0xFFEFFFFB),
    brightness: Brightness.light,
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF29A19C),
  scaffoldBackgroundColor: const Color(0xFF27323A),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF435055),
    foregroundColor: Color(0xFFA3F7BF),
  ),
  iconTheme: const IconThemeData(color: Color(0xFFA3F7BF)),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFFA3F7BF)),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF29A19C),
    primary: Color(0xFF29A19C),
    secondary: Color(0xFFA3F7BF),
    background: Color(0xFF27323A),
    brightness: Brightness.dark,
  ),
);
