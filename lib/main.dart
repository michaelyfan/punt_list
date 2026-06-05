import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'state/app_state.dart';
import 'screens/lists_screen.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence for web (mobile has it by default).
  if (kIsWeb) {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
  }

  runApp(const PuntApp());
}

class PuntApp extends StatefulWidget {
  const PuntApp({super.key});

  @override
  State<PuntApp> createState() => _PuntAppState();
}

class _PuntAppState extends State<PuntApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  AppState _appState = AppState();
  String? _userId;
  DateTime? _lastErrorShownAt;

  void _initForUser(String uid) {
    if (_userId == uid) return;
    _userId = uid;

    _appState.dispose();
    _appState = AppState();
    _appState.onError = _handleWriteError;

    final firestore = FirestoreService(uid);
    _appState.init(firestore).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Surface a permanent Firestore write failure. Generic, non-actionable
  /// errors aren't worth leaking details for, so the message is fixed.
  /// Debounced to ~4s so a burst of failed writes shows one SnackBar, not many.
  void _handleWriteError(Object error) {
    final now = DateTime.now();
    if (_lastErrorShownAt != null &&
        now.difference(_lastErrorShownAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastErrorShownAt = now;
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text("Couldn't save your changes. They may not be synced."),
      ),
    );
  }

  void _update(VoidCallback fn) {
    setState(fn);
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuntList',
      scaffoldMessengerKey: _messengerKey,
      themeMode: _appState.themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: AuthGate(
        builder: (user) {
          _initForUser(user.uid);

          if (_appState.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return ListsScreen(appState: _appState, update: _update);
        },
      ),
    );
  }
}
