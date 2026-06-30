import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/main_menu_screen.dart';

void main() {
  runApp(const ProviderScope(child: SudaneseWestApp()));
}

class SudaneseWestApp extends StatelessWidget {
  const SudaneseWestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'West السوداني',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
