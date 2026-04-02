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
        onIndent: (_, __) => indentCalled = true,
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

    testWidgets('ghost parent has disabled checkbox and no delete button', (tester) async {
      await tester.pumpWidget(buildTile(
        itemId: 'ghost-1',
        text: 'Ghost parent',
        isGhostParent: true,
      ));

      // Checkbox should be present but disabled
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);

      // No delete button for ghost parents
      expect(find.byIcon(Icons.delete_outline), findsNothing);
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
