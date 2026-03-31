import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punt_list/screens/settings_screen.dart';
import 'package:punt_list/widgets/help_dialog.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('theme radio buttons change theme', (tester) async {
      final appState = createTestAppState();
      await pumpScreen(
        tester,
        SettingsScreen(appState: appState, update: testUpdate),
      );

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(appState.themeMode, ThemeMode.dark);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(appState.themeMode, ThemeMode.light);
    });

    testWidgets('theme persists across rebuild', (tester) async {
      final appState = createTestAppState(themeMode: ThemeMode.dark);
      await pumpStatefulScreen(tester, builder: (update) =>
        SettingsScreen(appState: appState, update: update),
      );

      // Verify appState still reflects dark mode
      expect(appState.themeMode, ThemeMode.dark);

      // Switch to light and verify
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(appState.themeMode, ThemeMode.light);

      // Switch back to dark and verify
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(appState.themeMode, ThemeMode.dark);
    });

    testWidgets('destination dropdown shows other lists as options', (tester) async {
      final lists = [
        makeList(id: 'a', name: 'Alpha'),
        makeList(id: 'b', name: 'Beta'),
        makeList(id: 'c', name: 'Gamma'),
      ];
      final appState = createTestAppState(lists: lists);
      await pumpScreen(
        tester,
        SettingsScreen(appState: appState, update: testUpdate),
      );

      // Scroll to ensure all dropdowns are rendered
      await tester.scrollUntilVisible(
        find.text('Gamma'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // Each list should have a dropdown
      expect(find.byType(DropdownButton<String?>), findsNWidgets(3));

      // Tap Alpha's dropdown to see options
      await tester.tap(find.byType(DropdownButton<String?>).first);
      await tester.pumpAndSettle();

      // Should see Beta and Gamma as options (not Alpha)
      // Also "No destination" option
      expect(find.text('Beta'), findsWidgets);
      expect(find.text('Gamma'), findsWidgets);
    });

    testWidgets('set destination updates app state', (tester) async {
      final lists = [
        makeList(id: 'a', name: 'Alpha'),
        makeList(id: 'b', name: 'Beta'),
      ];
      final appState = createTestAppState(lists: lists);
      await pumpScreen(
        tester,
        SettingsScreen(appState: appState, update: testUpdate),
      );

      // Tap Alpha's dropdown
      await tester.tap(find.byType(DropdownButton<String?>).first);
      await tester.pumpAndSettle();

      // Select Beta as destination
      await tester.tap(find.text('Beta').last);
      await tester.pumpAndSettle();

      expect(appState.lists[0].destinationListId, 'b');
    });

    testWidgets('clear destination sets null', (tester) async {
      final lists = [
        makeList(id: 'a', name: 'Alpha', destinationListId: 'b'),
        makeList(id: 'b', name: 'Beta'),
      ];
      final appState = createTestAppState(lists: lists);
      await pumpStatefulScreen(tester, builder: (update) =>
        SettingsScreen(appState: appState, update: update),
      );

      // Tap Alpha's dropdown (currently shows Beta)
      await tester.tap(find.byType(DropdownButton<String?>).first);
      await tester.pumpAndSettle();

      // Select "No destination"
      await tester.tap(find.text('— No destination —').last);
      await tester.pumpAndSettle();

      expect(appState.lists[0].destinationListId, isNull);
    });

    testWidgets('shows no lists message when empty', (tester) async {
      final appState = createTestAppState();
      await pumpScreen(
        tester,
        SettingsScreen(appState: appState, update: testUpdate),
      );

      expect(find.text('No lists yet.'), findsOneWidget);
    });

    testWidgets('help dialog opens on tap', (tester) async {
      final appState = createTestAppState();
      await pumpScreen(
        tester,
        SettingsScreen(appState: appState, update: testUpdate),
      );

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(find.byType(HelpDialog), findsOneWidget);
    });
  });
}
