import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/punt_item.dart';

/// Thin persistence layer over Cloud Firestore.
///
/// All paths are scoped to `users/{userId}`. Timestamps use server time
/// (with `estimate` behavior for offline reads so the UI never sees null).
class FirestoreService {
  final String userId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirestoreService(this.userId);

  // ── References ──────────────────────────────────────────────────────

  DocumentReference get _userDoc => _db.collection('users').doc(userId);
  CollectionReference get _listsCol => _userDoc.collection('lists');
  CollectionReference _itemsCol(String listId) =>
      _listsCol.doc(listId).collection('items');

  // ── ID generation ───────────────────────────────────────────────────

  /// Generate a Firestore auto-ID (works offline, collision-resistant).
  String generateId() => _db.collection('_').doc().id;

  // ── Initial load (one-time reads) ──────────────────────────────────

  Future<Map<String, dynamic>?> getUserPreferences() async {
    final doc = await _userDoc.get();
    return doc.exists ? doc.data() as Map<String, dynamic>? : null;
  }

  Future<List<MapEntry<String, Map<String, dynamic>>>> getAllLists() async {
    final snap = await _listsCol.get();
    return snap.docs
        .map((d) => MapEntry(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<List<MapEntry<String, Map<String, dynamic>>>> getItems(
      String listId) async {
    final snap = await _itemsCol(listId).orderBy('sortOrder').get();
    return snap.docs
        .map((d) => MapEntry(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  // ── User preferences ───────────────────────────────────────────────

  Future<void> saveUserPreferences(Map<String, dynamic> data) =>
      _userDoc.set(data, SetOptions(merge: true));

  // ── List CRUD ──────────────────────────────────────────────────────

  Future<void> saveList(String id, Map<String, dynamic> data) {
    data['updatedAt'] = FieldValue.serverTimestamp();
    return _listsCol.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteListAndItems(String id) async {
    final batch = _db.batch();
    final items = await _itemsCol(id).get();
    for (final doc in items.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_listsCol.doc(id));
    await batch.commit();
  }

  // ── Item CRUD ──────────────────────────────────────────────────────

  /// Write a single item field update (surgical — used for text edits, toggles).
  Future<void> updateItem(
      String listId, String itemId, Map<String, dynamic> data) {
    data['updatedAt'] = FieldValue.serverTimestamp();
    return _itemsCol(listId).doc(itemId).update(data);
  }

  /// Batch-update specific fields on multiple items (e.g. cascade toggle).
  Future<void> batchUpdateItems(
      String listId, Map<String, Map<String, dynamic>> updates) {
    if (updates.isEmpty) return Future.value();
    final batch = _db.batch();
    for (final entry in updates.entries) {
      entry.value['updatedAt'] = FieldValue.serverTimestamp();
      batch.update(_itemsCol(listId).doc(entry.key), entry.value);
    }
    return batch.commit();
  }

  /// Delete specific items by ID.
  Future<void> deleteItems(String listId, List<String> itemIds) {
    if (itemIds.isEmpty) return Future.value();
    final batch = _db.batch();
    for (final id in itemIds) {
      batch.delete(_itemsCol(listId).doc(id));
    }
    return batch.commit();
  }

  // ── Bulk sync ──────────────────────────────────────────────────────

  /// Write all items in a list with sortOrder = index.
  /// Used after operations that change item order (reorder, indent, promote,
  /// add, split). Does NOT delete items — call [deleteItems] separately for
  /// operations that remove items.
  ///
  /// When [isNew] is true, sets `createdAt` on every item (used for
  /// restoreList after undo-delete).
  Future<void> syncListItems(String listId, List<PuntItem> items,
      {bool isNew = false}) {
    final batch = _db.batch();
    for (int i = 0; i < items.length; i++) {
      final data = {
        ...items[i].toMap(),
        'sortOrder': i.toDouble(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isNew) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      batch.set(
          _itemsCol(listId).doc(items[i].id), data, SetOptions(merge: true));
    }
    return batch.commit();
  }

  /// Atomic punt: delete from source + write all dest items in one batch.
  Future<void> puntItems({
    required String sourceListId,
    required List<String> sourceDeleteIds,
    required String destListId,
    required List<PuntItem> destItems,
  }) {
    final batch = _db.batch();

    // Delete punted items from source
    for (final id in sourceDeleteIds) {
      batch.delete(_itemsCol(sourceListId).doc(id));
    }

    // Write all dest items with correct sortOrders
    for (int i = 0; i < destItems.length; i++) {
      final data = {
        ...destItems[i].toMap(),
        'sortOrder': i.toDouble(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.set(
          _itemsCol(destListId).doc(destItems[i].id), data, SetOptions(merge: true));
    }

    return batch.commit();
  }
}
