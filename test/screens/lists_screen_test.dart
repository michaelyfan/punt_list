import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punt_list/screens/lists_screen.dart';
import 'package:punt_list/screens/list_view_screen.dart';
import 'package:punt_list/screens/settings_screen.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('ListsScreen', () {
    testWidgets('shows empty state when no lists', (tester) async {
      final appState = createTestAppState();
      await pumpScreen(tester, ListsScreen(appState: appState, update: testUpdate));

      expect(find.text('No lists yet. Tap + to create one!'), findsOneWidget);
    });

    testWidgets('shows all lists with names and item counts', (tester) async {
      final appState = createTestAppState(lists: [
        makeList(name: 'Groceries', items: [
          makeItem(text: 'Milk'),
          makeItem(text: 'Eggs'),
          makeItem(text: 'Done', isChecked: true),
        ]),
        makeList(name: 'Work'),
        makeList(name: 'Ideas', items: [
          makeItem(text: 'Idea 1'),
        ]),
      ]);
      await pumpScreen(tester, ListsScreen(appState: appState, update: testUpdate));

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('2 active, 1 completed'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('No items'), findsOneWidget);
      expect(find.text('Ideas'), findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);
    });

    testWidgets('tap FAB creates new list and navigates to it', (tester) async {
      final appState = createTestAppState();
      await pumpScreen(tester, ListsScreen(appState: appState, update: testUpdate));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(appState.lists.length, 1);
      expect(appState.lists.first.name, 'New List');
      expect(find.byType(ListViewScreen), findsOneWidget);
    });

    testWidgets('tap list card opens list view', (tester) async {
      final list = makeList(id: 'list-1', name: 'Groceries');
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(tester, ListsScreen(appState: appState, update: testUpdate));

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      expect(find.byType(ListViewScreen), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets('tap gear icon opens settings', (tester) async {
      final appState = createTestAppState();
      await pumpScreen(tester, ListsScreen(appState: appState, update: testUpdate));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
