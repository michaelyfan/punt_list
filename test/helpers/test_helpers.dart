import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punt_list/models/punt_item.dart';
import 'package:punt_list/models/punt_list.dart';
import 'package:punt_list/state/app_state.dart';

// ── Factories ───────────────────────────────────────────────────────

PuntItem makeItem({
  String? id,
  String text = 'Item',
  bool isChecked = false,
  String? parentId,
}) {
  return PuntItem(
    id: id ?? UniqueKey().toString(),
    text: text,
    isChecked: isChecked,
    parentId: parentId,
  );
}

PuntList makeList({
  String? id,
  String name = 'Test List',
  List<PuntItem>? items,
  String? destinationListId,
}) {
  return PuntList(
    id: id ?? UniqueKey().toString(),
    name: name,
    items: items,
    destinationListId: destinationListId,
  );
}

AppState createTestAppState({
  List<PuntList>? lists,
  ThemeMode themeMode = ThemeMode.system,
}) {
  final state = AppState(lists: lists, themeMode: themeMode);
  state.isLoading = false;
  return state;
}

// ── Pump helpers ────────────────────────────────────────────────────

/// Wraps [screen] in a MaterialApp and pumps it.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: screen,
    ),
  );
}

/// Wraps a screen builder in a StatefulBuilder so that `update` triggers
/// a real rebuild, just like `setState` does in the production app.
Future<void> pumpStatefulScreen(
  WidgetTester tester, {
  required Widget Function(void Function(VoidCallback) update) builder,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: StatefulBuilder(
        builder: (context, setState) => builder(setState),
      ),
    ),
  );
}

/// A simple update callback for tests — just runs the closure.
/// Use this when you only need to verify state changes, not UI updates.
void testUpdate(VoidCallback fn) => fn();
