import 'package:flutter/material.dart';
import 'config.dart';
import 'state/app_state.dart';
import 'screens/lists_screen.dart';

void main() {
  runApp(const PuntApp());
}

class PuntApp extends StatefulWidget {
  const PuntApp({super.key});

  @override
  State<PuntApp> createState() => _PuntAppState();
}

class _PuntAppState extends State<PuntApp> {
  final AppState _appState = seedTestData ? seedData() : AppState();

  void _update(VoidCallback fn) {
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuntList',
      themeMode: _appState.themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: ListsScreen(appState: _appState, update: _update),
    );
  }
}
