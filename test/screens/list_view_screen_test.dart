import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punt_list/screens/list_view_screen.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('ListViewScreen', () {
    testWidgets('shows list name in app bar', (tester) async {
      final list = makeList(id: 'list-1', name: 'Groceries');
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets('shows empty state when no items', (tester) async {
      final list = makeList(id: 'list-1', name: 'Empty');
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      expect(find.text('No items yet. Tap + to add one.'), findsOneWidget);
    });

    testWidgets('add item via + button dialog', (tester) async {
      final list = makeList(id: 'list-1', name: 'Test');
      final appState = createTestAppState(lists: [list]);
      await pumpStatefulScreen(tester, builder: (update) =>
        ListViewScreen(listId: 'list-1', appState: appState, update: update),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final dialogField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogField, 'Buy milk');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(appState.lists.first.items.length, 1);
      expect(find.text('Buy milk'), findsOneWidget);
    });

    testWidgets('add multiple items via repeated dialog', (tester) async {
      final list = makeList(id: 'list-1', name: 'Test');
      final appState = createTestAppState(lists: [list]);
      await pumpStatefulScreen(tester, builder: (update) =>
        ListViewScreen(listId: 'list-1', appState: appState, update: update),
      );

      Future<void> addOne(String text) async {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        final dialogField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dialogField, text);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
        await tester.pumpAndSettle();
      }

      await addOne('Item A');
      await addOne('Item B');

      expect(appState.lists.first.items.length, 2);
      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
    });

    testWidgets('multiline input creates one item per line and shows hint', (tester) async {
      final list = makeList(id: 'list-1', name: 'Test');
      final appState = createTestAppState(lists: [list]);
      await pumpStatefulScreen(tester, builder: (update) =>
        ListViewScreen(listId: 'list-1', appState: appState, update: update),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final dialogField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogField, 'a\nb\n\nc');
      await tester.pumpAndSettle();

      // Hint visible while multi-line input is present
      expect(find.text('Line breaks will become different items.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      final items = appState.lists.first.items;
      expect(items.length, 3);
      expect(items[0].text, 'a');
      expect(items[1].text, 'b');
      expect(items[2].text, 'c');
    });

    testWidgets('empty submit is a no-op', (tester) async {
      final list = makeList(id: 'list-1', name: 'Test');
      final appState = createTestAppState(lists: [list]);
      await pumpStatefulScreen(tester, builder: (update) =>
        ListViewScreen(listId: 'list-1', appState: appState, update: update),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(appState.lists.first.items, isEmpty);
    });

    testWidgets('check item moves it to checked section', (tester) async {
      final item = makeItem(id: 'i1', text: 'Task 1');
      final list = makeList(id: 'list-1', name: 'Test', items: [item]);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      // Tap the checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(appState.lists.first.items.first.isChecked, true);
    });

    testWidgets('uncheck item moves it back to active section', (tester) async {
      final item = makeItem(id: 'i1', text: 'Done task', isChecked: true);
      final list = makeList(id: 'list-1', name: 'Test', items: [item]);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(appState.lists.first.items.first.isChecked, false);
    });

    testWidgets('move arrow visible when destination is set', (tester) async {
      final dest = makeList(id: 'dest', name: 'Dest');
      final item = makeItem(id: 'i1', text: 'Move me');
      final list = makeList(
        id: 'list-1',
        name: 'Source',
        items: [item],
        destinationListId: 'dest',
      );
      final appState = createTestAppState(lists: [list, dest]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('move arrow hidden when no destination', (tester) async {
      final item = makeItem(id: 'i1', text: 'Stay here');
      final list = makeList(id: 'list-1', name: 'Test', items: [item]);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('punt item moves it to destination list', (tester) async {
      final dest = makeList(id: 'dest', name: 'Done');
      final item = makeItem(id: 'i1', text: 'Punt me');
      final list = makeList(
        id: 'list-1',
        name: 'Source',
        items: [item],
        destinationListId: 'dest',
      );
      final appState = createTestAppState(lists: [list, dest]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      // Item removed from source
      expect(appState.lists[0].items, isEmpty);
      // Item added to destination
      expect(appState.lists[1].items.length, 1);
      expect(appState.lists[1].items.first.text, 'Punt me');
    });

    testWidgets('destination banner shows target list name', (tester) async {
      final dest = makeList(id: 'dest', name: 'Archive');
      final item = makeItem(id: 'i1', text: 'Item');
      final list = makeList(
        id: 'list-1',
        name: 'Active',
        items: [item],
        destinationListId: 'dest',
      );
      final appState = createTestAppState(lists: [list, dest]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      expect(find.textContaining('Archive'), findsOneWidget);
      expect(find.textContaining('Tap'), findsOneWidget);
    });

    testWidgets('delete item removes it', (tester) async {
      final item = makeItem(id: 'i1', text: 'Delete me');
      final list = makeList(id: 'list-1', name: 'Test', items: [item]);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(appState.lists.first.items, isEmpty);
    });

    testWidgets('rename list via menu', (tester) async {
      final list = makeList(id: 'list-1', name: 'Old Name');
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      // Open the popup menu and tap "Rename list"
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename list'));
      await tester.pumpAndSettle();

      // Dialog should appear with current name
      expect(find.byType(AlertDialog), findsOneWidget);

      // Find the TextField inside the dialog (not the "add item" field)
      final dialogTextField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogTextField, 'New Name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(appState.lists.first.name, 'New Name');
    });

    testWidgets('rename list caps name at 200 characters', (tester) async {
      final list = makeList(id: 'list-1', name: 'Old Name');
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename list'));
      await tester.pumpAndSettle();

      final dialogTextField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      final longName = 'a' * 600;
      await tester.enterText(dialogTextField, longName);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(appState.lists.first.name.length, 200);
      expect(appState.lists.first.name, 'a' * 200);
    });

    testWidgets('delete list via menu and confirm', (tester) async {
      final list = makeList(id: 'list-1', name: 'Doomed');
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap "Delete list"
      await tester.tap(find.text('Delete list'));
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(appState.lists, isEmpty);
    });

    testWidgets('clear checked items via menu', (tester) async {
      final items = [
        makeItem(id: 'i1', text: 'Active'),
        makeItem(id: 'i2', text: 'Done', isChecked: true),
        makeItem(id: 'i3', text: 'Also done', isChecked: true),
      ];
      final list = makeList(id: 'list-1', name: 'Test', items: items);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear checked items'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(appState.lists.first.items.length, 1);
      expect(appState.lists.first.items.first.text, 'Active');
    });

    testWidgets('checking parent cascades to children', (tester) async {
      final parent = makeItem(id: 'p1', text: 'Parent');
      final child1 = makeItem(id: 'c1', text: 'Child 1', parentId: 'p1');
      final child2 = makeItem(id: 'c2', text: 'Child 2', parentId: 'p1');
      final list = makeList(id: 'list-1', name: 'Test', items: [parent, child1, child2]);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      // Tap the first checkbox (parent)
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      final items = appState.lists.first.items;
      expect(items.every((i) => i.isChecked), true);
    });

    testWidgets('unchecking child unchecks parent', (tester) async {
      final parent = makeItem(id: 'p1', text: 'Parent', isChecked: true);
      final child = makeItem(id: 'c1', text: 'Child', isChecked: true, parentId: 'p1');
      final list = makeList(id: 'list-1', name: 'Test', items: [parent, child]);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      // Find the child's checkbox (second one) and tap it
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(appState.lists.first.items[0].isChecked, false); // parent unchecked
      expect(appState.lists.first.items[1].isChecked, false); // child unchecked
    });

    testWidgets('ghost parent appears in checked section', (tester) async {
      // Parent unchecked, child checked → ghost parent should appear
      final parent = makeItem(id: 'p1', text: 'Ghost Parent');
      final child = makeItem(id: 'c1', text: 'Checked Child', isChecked: true, parentId: 'p1');
      final list = makeList(id: 'list-1', name: 'Test', items: [parent, child]);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      // Ghost parent text should appear twice — once in active, once in checked as ghost
      expect(find.text('Ghost Parent'), findsNWidgets(2));
      expect(find.text('Checked Child'), findsOneWidget);
    });

    testWidgets('inline edit updates item text', (tester) async {
      final item = makeItem(id: 'i1', text: 'Original');
      final list = makeList(id: 'list-1', name: 'Test', items: [item]);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      // Tap item text to enter edit mode
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();

      // Clear and type new text
      // Find the TextField that appeared (not the "Add new item" one)
      final textFields = find.byType(TextField);
      // The first TextField is the inline edit, the last is the "add item" field
      await tester.enterText(textFields.first, 'Updated');

      // Unfocus to commit the edit
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(appState.lists.first.items.first.text, 'Updated');
    });

    testWidgets('tapping outside inline edit blurs and commits', (tester) async {
      final item = makeItem(id: 'i1', text: 'Original');
      final list = makeList(id: 'list-1', name: 'Test', items: [item]);
      final appState = createTestAppState(lists: [list]);
      await pumpScreen(
        tester,
        ListViewScreen(listId: 'list-1', appState: appState, update: testUpdate),
      );

      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Updated');
      await tester.pump();

      // Tap on the AppBar (outside the TextField's TapRegion) to trigger
      // onTapOutside, which unfocuses and commits the edit.
      await tester.tapAt(const Offset(400, 28));
      await tester.pumpAndSettle();

      expect(appState.lists.first.items.first.text, 'Updated');
    });
  });
}
