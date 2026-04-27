import 'package:flutter_test/flutter_test.dart';
import 'package:punt_list/models/punt_list.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('20,000-character list limit', () {
    test('totalCharacters sums text across parents and sub-items', () {
      final list = makeList(items: [
        makeItem(id: 'a', text: 'hello'), // 5
        makeItem(id: 'b', text: 'world', parentId: 'a'), // 5
        makeItem(id: 'c', text: 'xx', isChecked: true), // 2
      ]);
      expect(list.totalCharacters, 12);
    });

    test('addItems refuses when total would exceed limit', () {
      final big = 'x' * (PuntList.characterLimit - 5);
      final list = makeList(id: 'l1', items: [makeItem(text: big)]);
      final appState = createTestAppState(lists: [list]);

      // 6-char string would push past the 20k limit by 1.
      expect(appState.addItems('l1', ['123456']), isFalse);
      expect(list.items.length, 1);

      // 5-char string fits exactly.
      expect(appState.addItems('l1', ['12345']), isTrue);
      expect(list.items.length, 2);
      expect(list.totalCharacters, PuntList.characterLimit);
    });

    test('editItemText refuses when growth would exceed limit', () {
      final big = 'x' * (PuntList.characterLimit - 3);
      final list = makeList(id: 'l1', items: [
        makeItem(id: 'big', text: big),
        makeItem(id: 'small', text: 'ab'),
      ]);
      final appState = createTestAppState(lists: [list]);

      // Currently at 19,999 chars. Edit "ab" (2) → "abcd" (4) adds 2 → 20,001.
      expect(appState.editItemText('l1', 'small', 'abcd'), isFalse);
      expect(list.items.last.text, 'ab');

      // Shrinking is always allowed.
      expect(appState.editItemText('l1', 'big', 'tiny'), isTrue);
    });

    test('moveItem refuses when destination would exceed limit', () {
      final big = 'x' * (PuntList.characterLimit - 1);
      final source = makeList(
        id: 'src',
        items: [makeItem(id: 'i1', text: 'ab')],
        destinationListId: 'dst',
      );
      final dest = makeList(id: 'dst', items: [makeItem(text: big)]);
      final appState = createTestAppState(lists: [source, dest]);

      // dest at 19,999; adding 2 chars would exceed.
      expect(appState.moveItem('src', 'i1'), isFalse);
      expect(source.items.length, 1);
      expect(dest.items.length, 1);
    });
  });
}
