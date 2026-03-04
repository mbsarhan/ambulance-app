import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Import this
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'منبه الإسعاف', // Ambulance Alert
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial', // Optional: Good fallback for Arabic
      ),
      // 👇 RTL AND ARABIC CONFIGURATION 👇
      locale: const Locale('ar', ''), // Force Arabic
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''), // Arabic
        Locale('en', ''), // English (Backup)
      ],
      // 👆 ---------------------------- 👆
      home: const HomeScreen(),
    );
  }
}