import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('AppState error signal', () {
    test('onError is exposed and defaults to null', () {
      final state = createTestAppState();
      expect(state.onError, isNull);
    });

    test('mutations without a FirestoreService never fire onError', () {
      // In tests AppState has no FirestoreService attached, so every write is a
      // no-op (the `_firestore?.` null-guard). The error channel must therefore
      // stay silent — _report only observes a real future, of which there are
      // none here. This guards the "tests run without Firestore" invariant.
      Object? reported;
      final list = makeList(id: 'l1', items: [makeItem(id: 'i1', text: 'a')]);
      final state = createTestAppState(lists: [list]);
      state.onError = (e) => reported = e;

      state.addItem('l1', 'b');
      state.editItemText('l1', 'i1', 'aa');
      state.toggleItem('l1', 'i1');
      state.deleteItem('l1', 'i1');
      state.renameList('l1', 'renamed');
      state.addList();

      expect(reported, isNull);
    });
  });
}
