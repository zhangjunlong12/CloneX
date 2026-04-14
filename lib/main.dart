import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/recording_screen.dart';

void main() {
  runApp(const ProviderScope(child: CloneXApp()));
}

class CloneXApp extends StatelessWidget {
  const CloneXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloneX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
        ),
      ),
      home: const HomeScreen(),
      routes: {
        '/record': (context) => const RecordingScreen(),
      },
    );
  }
}
