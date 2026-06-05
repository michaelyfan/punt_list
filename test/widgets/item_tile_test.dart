import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punt_list/widgets/item_tile.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('ItemTile', () {
    late final String listId;
    late final Function(VoidCallback) update;

    setUpAll(() {
      listId = 'list-1';
      update = testUpdate;
    });

    Widget buildTile({
      required String itemId,
      String text = 'Test item',
      bool isChecked = false,
      String? parentId,
      bool showMoveButton = false,
      bool showDragHandle = false,
      bool isSubItem = false,
      bool isGhostParent = false,
      bool canIndent = false,
      bool canPromote = false,
      String? indentTargetParentId,
      void Function(String, String)? onIndent,
      void Function(String)? onPromote,
      void Function(String, String, String)? onSplit,
      bool Function(String)? onBackspaceAtStart,
      bool autoFocus = false,
      List<dynamic>? lists,
    }) {
      final item = makeItem(id: itemId, text: text, isChecked: isChecked, parentId: parentId);
      final appState = createTestAppState(lists: [
        makeList(id: listId, name: 'Test', items: [item]),
        if (lists != null) ...lists,
      ]);
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ItemTile(
              item: item,
              listId: listId,
              showMoveButton: showMoveButton,
              showDragHandle: showDragHandle,
              itemIndex: 0,
              appState: appState,
              update: update,
              isSubItem: isSubItem,
              isGhostParent: isGhostParent,
              canIndent: canIndent,
              canPromote: canPromote,
              indentTargetParentId: indentTargetParentId,
              onIndent: onIndent,
              onPromote: onPromote,
              onSplit: onSplit,
              onBackspaceAtStart: onBackspaceAtStart,
              autoFocus: autoFocus,
            ),
          ),
        ),
      );
    }

    testWidgets('swipe right triggers indent', (tester) async {
      String? indentedItemId;
      String? indentedParentId;

      await tester.pumpWidget(buildTile(
        itemId: 'item-1',
        canIndent: true,
        indentTargetParentId: 'parent-1',
        onIndent: (itemId, parentId) {
          indentedItemId = itemId;
          indentedParentId = parentId;
        },
      ));

      // Verify the swipe GestureDetector is present
      final gestureDetectors = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onHorizontalDragUpdate != null,
      );
      expect(gestureDetectors, findsOneWidget);

      // Swipe right past threshold (60px) using fling for reliable gesture
      await tester.fling(gestureDetectors, const Offset(100, 0), 200);
      await tester.pumpAndSettle();

      expect(indentedItemId, 'item-1');
      expect(indentedParentId, 'parent-1');
    });

    testWidgets('swipe left triggers promote', (tester) async {
      String? promotedItemId;

      await tester.pumpWidget(buildTile(
        itemId: 'child-1',
        parentId: 'parent-1',
        canPromote: true,
        onPromote: (itemId) {
          promotedItemId = itemId;
        },
      ));

      final gestureDetectors = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onHorizontalDragUpdate != null,
      );
      await tester.fling(gestureDetectors, const Offset(-100, 0), 200);
      await tester.pumpAndSettle();

      expect(promotedItemId, 'child-1');
    });

    testWidgets('swipe right blocked when canIndent is false', (tester) async {
      bool indentCalled = false;

      await tester.pumpWidget(buildTile(
        itemId: 'item-1',
        canIndent: false,
        onIndent: (_, _) => indentCalled = true,
      ));

      await tester.drag(find.text('Test item'), const Offset(70, 0));
      await tester.pumpAndSettle();

      expect(indentCalled, false);
    });

    testWidgets('enter in edit mode triggers split', (tester) async {
      String? splitItemId;
      String? splitBefore;
      String? splitAfter;

      await tester.pumpWidget(buildTile(
        itemId: 'item-1',
        text: 'Hello World',
        autoFocus: true,
        onSplit: (itemId, before, after) {
          splitItemId = itemId;
          splitBefore = before;
          splitAfter = after;
        },
      ));
      await tester.pumpAndSettle();

      // Move cursor to position 5 ("Hello|World")
      final textField = tester.widget<TextField>(find.byType(TextField));
      textField.controller!.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      // Submit triggers split at cursor position
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(splitItemId, 'item-1');
      expect(splitBefore, 'Hello');
      expect(splitAfter, 'World');
    });

    testWidgets('split offsets are correct with the start sentinel enabled',
        (tester) async {
      // When onBackspaceAtStart is wired (the real app), the editor prepends a
      // zero-width-space sentinel. Splitting must report *logical* offsets, not
      // the sentinel-shifted controller offsets.
      String? splitBefore;
      String? splitAfter;

      await tester.pumpWidget(buildTile(
        itemId: 'item-1',
        text: 'Hello World',
        autoFocus: true,
        onSplit: (itemId, before, after) {
          splitBefore = before;
          splitAfter = after;
        },
        onBackspaceAtStart: (_) => false,
      ));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      // Buffer carries the sentinel; logical "Hello|World" is controller pos 6.
      expect(textField.controller!.text,
          '${ItemTile.editStartSentinel}Hello World');
      textField.controller!.selection = const TextSelection.collapsed(offset: 6);
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(splitBefore, 'Hello');
      expect(splitAfter, 'World');
    });

    testWidgets('select-all then replace is not misread as backspace-at-start',
        (tester) async {
      // Selecting the whole field (which includes the leading sentinel) and
      // typing a replacement removes the sentinel without it being a Backspace.
      // It must NOT fire onBackspaceAtStart; the typed text must survive and the
      // sentinel must be re-anchored so detection keeps working.
      var backspaceCalls = 0;

      await tester.pumpWidget(buildTile(
        itemId: 'item-1',
        text: 'Hello',
        autoFocus: true,
        onBackspaceAtStart: (_) {
          backspaceCalls++;
          return true;
        },
      ));
      await tester.pumpAndSettle();

      final controller =
          tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(controller.text, '${ItemTile.editStartSentinel}Hello');

      // Simulate select-all + type "X": the entire buffer (sentinel included) is
      // replaced by the single typed character.
      controller.value = const TextEditingValue(
        text: 'X',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pumpAndSettle();

      expect(backspaceCalls, 0, reason: 'replace is not a backspace-at-start');
      // Sentinel re-anchored, user input preserved, caret after the typed char.
      expect(controller.text, '${ItemTile.editStartSentinel}X');
      expect(controller.selection.baseOffset, 2);
    });

    testWidgets('ghost parent has disabled checkbox', (tester) async {
      await tester.pumpWidget(buildTile(
        itemId: 'ghost-1',
        text: 'Ghost parent',
        isGhostParent: true,
      ));

      // Checkbox should be present but disabled
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);
    });

    testWidgets('plain item has no trash icon', (tester) async {
      // The per-item trash icon was removed; non-parent items rely on
      // Backspace-to-delete instead.
      await tester.pumpWidget(buildTile(itemId: 'item-1', text: 'Plain'));
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('parent-with-children shows a trash icon', (tester) async {
      // A parent of a sub-list is exempt from Backspace-delete, so it keeps the
      // trash icon as its delete affordance.
      final parent = makeItem(id: 'parent-1', text: 'Parent');
      final child = makeItem(id: 'child-1', text: 'Child', parentId: 'parent-1');
      final appState = createTestAppState(lists: [
        makeList(id: listId, name: 'Test', items: [parent, child]),
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ItemTile(
              item: parent,
              listId: listId,
              showMoveButton: false,
              itemIndex: 0,
              appState: appState,
              update: update,
            ),
          ),
        ),
      ));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('sub-item has indented card margin', (tester) async {
      await tester.pumpWidget(buildTile(
        itemId: 'child-1',
        text: 'Child item',
        isSubItem: true,
        parentId: 'parent-1',
      ));

      // Find the Card and check its margin includes the 48px indent
      final card = tester.widget<Card>(find.byType(Card));
      final container = card.margin as EdgeInsets;
      // Normal left margin is 12, sub-item adds 48 = 60
      expect(container.left, 60.0);
    });

    testWidgets('auto-focus opens in edit mode', (tester) async {
      await tester.pumpWidget(buildTile(
        itemId: 'item-1',
        text: 'Editable',
        autoFocus: true,
      ));
      await tester.pumpAndSettle();

      // Should show a TextField (edit mode) instead of plain Text
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('move button shown only when showMoveButton is true and item unchecked', (tester) async {
      await tester.pumpWidget(buildTile(
        itemId: 'item-1',
        showMoveButton: true,
      ));

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('move button hidden when item is checked', (tester) async {
      await tester.pumpWidget(buildTile(
        itemId: 'item-1',
        isChecked: true,
        showMoveButton: true,
      ));

      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('move button hidden when showMoveButton is false', (tester) async {
      await tester.pumpWidget(buildTile(
        itemId: 'item-1',
        showMoveButton: false,
      ));

      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });
  });
}
