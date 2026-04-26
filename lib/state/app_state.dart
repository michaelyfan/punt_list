import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/material.dart';
import '../models/punt_item.dart';
import '../models/punt_list.dart';
import '../services/firestore_service.dart';

class AppState {
  final List<PuntList> lists;
  ThemeMode themeMode;
  bool isLoading = true;

  FirestoreService? _firestore;

  AppState({List<PuntList>? lists, this.themeMode = ThemeMode.system})
      : lists = lists ?? [];

  // ── Firestore integration ─────────────────────────────────────────

  /// Load all data from Firestore. Call once after construction.
  Future<void> init(FirestoreService firestore) async {
    _firestore = firestore;

    // Load user preferences
    final prefs = await firestore.getUserPreferences();
    if (prefs != null) {
      themeMode = _parseThemeMode(prefs['themePreference'] as String?);
    }
    final listOrder =
        (prefs?['listOrder'] as List<dynamic>?)?.cast<String>() ?? [];

    // Load all lists with their items
    final listEntries = await firestore.getAllLists();
    lists.clear();

    for (final entry in listEntries) {
      final list = PuntList.fromMap(entry.key, entry.value);
      final itemEntries = await firestore.getItems(list.id);
      for (final itemEntry in itemEntries) {
        list.items.add(PuntItem.fromMap(itemEntry.key, itemEntry.value));
      }
      lists.add(list);
    }

    // Sort lists by persisted order
    if (listOrder.isNotEmpty) {
      lists.sort((a, b) {
        final ai = listOrder.indexOf(a.id);
        final bi = listOrder.indexOf(b.id);
        if (ai == -1 && bi == -1) return 0;
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
    }

    isLoading = false;
  }

  void dispose() {
    // Reserved for future listener cleanup.
  }

  // ── ID generation ─────────────────────────────────────────────────

  String _generateId() =>
      _firestore?.generateId() ??
      DateTime.now().microsecondsSinceEpoch.toString();

  // ── Persistence helpers ───────────────────────────────────────────

  void _persistListOrder() {
    _firestore?.saveUserPreferences({
      'listOrder': lists.map((l) => l.id).toList(),
    });
  }

  void _persistListItems(String listId, {bool isNew = false}) {
    if (_firestore == null) return;
    final list = _findList(listId);
    if (list == null) return;
    _firestore!.syncListItems(listId, List.from(list.items), isNew: isNew);
  }

  // ── Lists ─────────────────────────────────────────────────────────

  PuntList addList() {
    final list = PuntList(id: _generateId(), name: 'New List');
    lists.add(list);

    _firestore?.saveList(list.id, {
      ...list.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _persistListOrder();

    return list;
  }

  void reorderList(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final list = lists.removeAt(oldIndex);
    lists.insert(newIndex, list);

    _persistListOrder();
  }

  void deleteList(String listId) {
    final affectedListIds = <String>[];
    for (final l in lists) {
      if (l.destinationListId == listId) {
        l.destinationListId = null;
        affectedListIds.add(l.id);
      }
    }
    lists.removeWhere((l) => l.id == listId);

    _firestore?.deleteListAndItems(listId);
    _persistListOrder();
    for (final id in affectedListIds) {
      _firestore?.saveList(id, {'destinationListId': null});
    }
  }

  void renameList(String listId, String newName) {
    _findList(listId)?.name = newName;
    _firestore?.saveList(listId, {'name': newName});
  }

  void setDestination(String listId, String? destId) {
    final list = _findList(listId);
    if (list != null) {
      list.destinationListId = destId;
      _firestore?.saveList(listId, {'destinationListId': destId});
    }
  }

  void restoreList(PuntList list, int index, List<String> dependentListIds) {
    lists.insert(index.clamp(0, lists.length), list);
    for (final id in dependentListIds) {
      final dependent = _findList(id);
      if (dependent != null) dependent.destinationListId = list.id;
    }

    _firestore?.saveList(list.id, {
      ...list.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _persistListItems(list.id, isNew: true);
    _persistListOrder();
    for (final id in dependentListIds) {
      _firestore?.saveList(id, {'destinationListId': list.id});
    }
  }

  // ── Items ─────────────────────────────────────────────────────────

  void addItem(String listId, String text) {
    final id = _generateId();
    _findList(listId)?.items.add(PuntItem(id: id, text: text));

    _persistListItems(listId);
  }

  void addItems(String listId, List<String> texts) {
    if (texts.isEmpty) return;
    final list = _findList(listId);
    if (list == null) return;
    for (final text in texts) {
      list.items.add(PuntItem(id: _generateId(), text: text));
    }
    _persistListItems(listId);
  }

  void reorderItem(String listId, int oldIndex, int newIndex) {
    final list = _findList(listId);
    if (list == null) return;
    final rawNewIndex = newIndex;
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final displayItems = list.activeDisplayItems;
    if (oldIndex >= displayItems.length || newIndex >= displayItems.length) {
      return;
    }

    final draggedItem = displayItems[oldIndex].item;

    if (draggedItem.parentId != null) {
      // --- Child item drag: move single child ---
      list.items.removeWhere((i) => i.id == draggedItem.id);

      final tempList =
          PuntList(id: 'temp', name: 'temp', items: List.from(list.items));
      final newDisplay = tempList.activeDisplayItems;

      String? newParentId;
      if (newIndex > 0) {
        final aboveIndex = (newIndex - 1).clamp(0, newDisplay.length - 1);
        final aboveItem = newDisplay[aboveIndex].item;
        newParentId = aboveItem.parentId ?? aboveItem.id;
      }

      final movedItem = draggedItem.withParentId(newParentId);

      if (newIndex >= newDisplay.length) {
        final lastActive = list.items.lastIndexWhere((i) => !i.isChecked);
        list.items.insert(lastActive + 1, movedItem);
      } else {
        final targetItem = newDisplay[newIndex].item;
        final targetIdx = list.items.indexWhere((i) => i.id == targetItem.id);
        list.items.insert(
            targetIdx == -1 ? list.items.length : targetIdx, movedItem);
      }

      _persistListItems(listId);
      return;
    }

    // --- Root item drag: move parent + children block ---

    int blockEnd = oldIndex;
    for (int i = oldIndex + 1; i < displayItems.length; i++) {
      if (displayItems[i].item.parentId == draggedItem.id) {
        blockEnd = i;
      } else {
        break;
      }
    }
    final blockSize = blockEnd - oldIndex + 1;

    if (newIndex >= oldIndex && newIndex <= blockEnd) return;

    if (rawNewIndex > 0 && rawNewIndex < displayItems.length) {
      final leftItem = displayItems[rawNewIndex - 1].item;
      final rightItem = displayItems[rawNewIndex].item;
      final leftGroup = leftItem.parentId ?? leftItem.id;
      final rightGroup = rightItem.parentId ?? rightItem.id;
      if (leftGroup == rightGroup) return;
    }

    if (newIndex > blockEnd) {
      newIndex -= (blockSize - 1);
    }

    final blockIds = <String>{draggedItem.id};
    for (final item in list.items) {
      if (item.parentId == draggedItem.id && !item.isChecked) {
        blockIds.add(item.id);
      }
    }

    final block = list.items.where((i) => blockIds.contains(i.id)).toList();
    final remaining =
        list.items.where((i) => !blockIds.contains(i.id)).toList();

    final tempList = PuntList(id: 'temp', name: 'temp', items: remaining);
    final remainingDisplay = tempList.activeDisplayItems;

    int insertIndex;
    if (newIndex >= remainingDisplay.length) {
      final lastActive = remaining.lastIndexWhere((i) => !i.isChecked);
      insertIndex = lastActive + 1;
    } else {
      final targetItem = remainingDisplay[newIndex].item;
      insertIndex = remaining.indexWhere((i) => i.id == targetItem.id);
      if (insertIndex == -1) insertIndex = remaining.length;
    }

    remaining.insertAll(insertIndex, block);
    list.items
      ..clear()
      ..addAll(remaining);

    _persistListItems(listId);
  }

  void indentItem(String listId, String itemId, String targetParentId) {
    final list = _findList(listId);
    if (list == null) return;
    final itemIndex = list.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;
    final item = list.items[itemIndex];
    if (item.parentId != null) return;

    final block = <PuntItem>[item.withParentId(targetParentId)];
    for (final child in list.items) {
      if (child.parentId == itemId) {
        block.add(child.withParentId(targetParentId));
      }
    }

    final blockIds = block.map((i) => i.id).toSet();
    list.items.removeWhere((i) => blockIds.contains(i.id));

    int parentIdx = list.items.indexWhere((i) => i.id == targetParentId);
    if (parentIdx == -1) return;
    int insertAt = parentIdx + 1;
    while (insertAt < list.items.length &&
        list.items[insertAt].parentId == targetParentId) {
      insertAt++;
    }
    list.items.insertAll(insertAt, block);

    _persistListItems(listId);
  }

  void promoteItem(String listId, String itemId) {
    final list = _findList(listId);
    if (list == null) return;
    final itemIndex = list.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;
    final item = list.items[itemIndex];
    if (item.parentId == null) return;

    final oldParentId = item.parentId!;

    final laterSiblings = <int>[];
    for (int i = itemIndex + 1; i < list.items.length; i++) {
      if (list.items[i].parentId == oldParentId) {
        laterSiblings.add(i);
      } else if (list.items[i].parentId == null) {
        break;
      }
    }

    for (final idx in laterSiblings) {
      list.items[idx] = list.items[idx].withParentId(itemId);
    }

    list.items[itemIndex] = item.withParentId(null);

    final promotedBlock = <PuntItem>[list.items[itemIndex]];
    for (final idx in laterSiblings) {
      promotedBlock.add(list.items[idx]);
    }

    final blockIds = promotedBlock.map((i) => i.id).toSet();
    list.items.removeWhere((i) => blockIds.contains(i.id));

    int parentIdx = list.items.indexWhere((i) => i.id == oldParentId);
    if (parentIdx == -1) {
      list.items.addAll(promotedBlock);
      _persistListItems(listId);
      return;
    }
    int insertAt = parentIdx + 1;
    while (insertAt < list.items.length &&
        list.items[insertAt].parentId == oldParentId) {
      insertAt++;
    }
    list.items.insertAll(insertAt, promotedBlock);

    _persistListItems(listId);
  }

  String splitItem(
      String listId, String itemId, String beforeText, String afterText) {
    final list = _findList(listId);
    final newId = _generateId();
    if (list == null) return newId;
    final itemIndex = list.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return newId;
    final item = list.items[itemIndex];

    list.items[itemIndex] =
        item.copyWith(text: beforeText.isEmpty ? beforeText : beforeText);

    int insertAt = itemIndex + 1;
    if (item.parentId == null) {
      while (insertAt < list.items.length &&
          list.items[insertAt].parentId == itemId) {
        insertAt++;
      }
    }

    list.items.insert(
      insertAt,
      PuntItem(id: newId, text: afterText, parentId: item.parentId),
    );

    _persistListItems(listId);
    return newId;
  }

  void deleteItem(String listId, String itemId) {
    final list = _findList(listId);
    if (list == null) return;

    final deletedIds = list.items
        .where((i) => i.id == itemId || i.parentId == itemId)
        .map((i) => i.id)
        .toList();

    list.items.removeWhere((i) => i.id == itemId || i.parentId == itemId);

    _firestore?.deleteItems(listId, deletedIds);
  }

  void clearCheckedItems(String listId) {
    final list = _findList(listId);
    if (list == null) return;

    final checkedIds =
        list.items.where((i) => i.isChecked).map((i) => i.id).toList();

    list.items.removeWhere((i) => i.isChecked);

    _firestore?.deleteItems(listId, checkedIds);
  }

  void toggleItem(String listId, String itemId) {
    final list = _findList(listId);
    if (list == null) return;
    final index = list.items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final item = list.items[index];
    final newChecked = !item.isChecked;
    list.items[index] = item.copyWith(isChecked: newChecked);

    // Track toggled items for surgical Firestore update
    final updates = <String, Map<String, dynamic>>{
      itemId: {'isChecked': newChecked},
    };

    if (item.parentId == null) {
      // Parent: cascade to all children
      for (int i = 0; i < list.items.length; i++) {
        if (list.items[i].parentId == itemId) {
          list.items[i] = list.items[i].copyWith(isChecked: newChecked);
          updates[list.items[i].id] = {'isChecked': newChecked};
        }
      }
    } else if (!newChecked) {
      // Unchecking a child: if parent is checked, uncheck parent too
      final parentIndex =
          list.items.indexWhere((i) => i.id == item.parentId);
      if (parentIndex != -1 && list.items[parentIndex].isChecked) {
        list.items[parentIndex] =
            list.items[parentIndex].copyWith(isChecked: false);
        updates[item.parentId!] = {'isChecked': false};
      }
    }

    _firestore?.batchUpdateItems(listId, updates);
  }

  void editItemText(String listId, String itemId, String newText) {
    final list = _findList(listId);
    if (list == null) return;
    final index = list.items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    list.items[index] = list.items[index].copyWith(text: newText);

    _firestore?.updateItem(listId, itemId, {'text': newText});
  }

  void moveItem(String sourceListId, String itemId) {
    final source = _findList(sourceListId);
    if (source == null || source.destinationListId == null) return;
    final dest = _findList(source.destinationListId!);
    if (dest == null) return;
    final destListId = source.destinationListId!;

    final index = source.items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final item = source.items[index];

    if (item.parentId != null) {
      // Sub-item punt
      final parentIndex =
          source.items.indexWhere((i) => i.id == item.parentId);
      if (parentIndex == -1) return;
      final parent = source.items[parentIndex];

      final existingParentIndex =
          dest.items.indexWhere((i) => i.id == parent.id);
      if (existingParentIndex == -1) {
        dest.items
            .add(PuntItem(id: parent.id, text: parent.text, parentId: null));
      }

      source.items.removeAt(index);
      dest.items.add(item.copyWith(isChecked: false));

      _firestore?.puntItems(
        sourceListId: sourceListId,
        sourceDeleteIds: [itemId],
        destListId: destListId,
        destItems: List.from(dest.items),
      );
      return;
    }

    // Parent punt
    final children =
        source.items.where((i) => i.parentId == itemId).toList();
    final removedIds = [itemId, ...children.map((c) => c.id)];

    final existingIndex = dest.items.indexWhere((i) => i.id == itemId);
    source.items
        .removeWhere((i) => i.id == itemId || i.parentId == itemId);

    if (existingIndex != -1) {
      dest.items[existingIndex] = item.copyWith(isChecked: false);
    } else {
      dest.items.add(item.copyWith(isChecked: false));
    }
    dest.items.addAll(children);

    _firestore?.puntItems(
      sourceListId: sourceListId,
      sourceDeleteIds: removedIds,
      destListId: destListId,
      destItems: List.from(dest.items),
    );
  }

  // ── Theme ─────────────────────────────────────────────────────────

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _firestore?.saveUserPreferences({
      'themePreference': _themeModeToString(mode),
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────

  PuntList? _findList(String id) {
    try {
      return lists.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

