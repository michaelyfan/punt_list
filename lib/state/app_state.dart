import 'package:flutter/material.dart';
import '../models/punt_item.dart';
import '../models/punt_list.dart';

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

AppState seedData() {
  final list1 = PuntList(id: '1', name: 'List 1', items: [
    PuntItem(id: '1-1', text: 'Item 1'),
    PuntItem(id: '1-2', text: 'Item 2'),
    PuntItem(id: '1-3', text: 'Item 3'),
  ]);
  final list2 = PuntList(id: '2', name: 'List 2', items: [
    PuntItem(id: '2-1', text: 'Item 1'),
    PuntItem(id: '2-2', text: 'Item 2'),
    PuntItem(id: '2-3', text: 'Item 3'),
  ]);
  final list3 = PuntList(id: '3', name: 'List 3', items: [
    PuntItem(id: '3-1', text: 'Item 1'),
    PuntItem(id: '3-2', text: 'Item 2'),
    PuntItem(id: '3-3', text: 'Item 3'),
  ]);
  list1.destinationListId = list2.id;
  list2.destinationListId = list3.id;
  return AppState(lists: [list1, list2, list3]);
}

class AppState {
  final List<PuntList> lists;
  ThemeMode themeMode;

  AppState({List<PuntList>? lists, this.themeMode = ThemeMode.system})
      : lists = lists ?? [];

  // --- Lists ---

  PuntList addList() {
    final list = PuntList(id: _newId(), name: 'New List');
    lists.add(list);
    return list;
  }

  void reorderList(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final list = lists.removeAt(oldIndex);
    lists.insert(newIndex, list);
  }

  void deleteList(String listId) {
    // Clear this list as a destination from any other list
    for (final l in lists) {
      if (l.destinationListId == listId) {
        l.destinationListId = null;
      }
    }
    lists.removeWhere((l) => l.id == listId);
  }

  void renameList(String listId, String newName) {
    _findList(listId)?.name = newName;
  }

  void setDestination(String listId, String? destId) {
    final list = _findList(listId);
    if (list != null) list.destinationListId = destId;
  }

  /// Inserts a previously deleted list back at [index] and restores any lists
  /// that had it as their destination.
  void restoreList(PuntList list, int index, List<String> dependentListIds) {
    lists.insert(index.clamp(0, lists.length), list);
    for (final id in dependentListIds) {
      final dependent = _findList(id);
      if (dependent != null) dependent.destinationListId = list.id;
    }
  }

  // --- Items ---

  void addItem(String listId, String text) {
    _findList(listId)?.items.add(PuntItem(id: _newId(), text: text));
  }

  void reorderItem(String listId, int oldIndex, int newIndex) {
    final list = _findList(listId);
    if (list == null) return;
    final active = list.items.where((i) => !i.isChecked).toList();
    final checked = list.items.where((i) => i.isChecked).toList();
    if (newIndex > oldIndex) newIndex--;
    final item = active.removeAt(oldIndex);
    active.insert(newIndex, item);
    list.items
      ..clear()
      ..addAll(active)
      ..addAll(checked);
  }

  void deleteItem(String listId, String itemId) {
    _findList(listId)?.items.removeWhere((i) => i.id == itemId);
  }

  void clearCheckedItems(String listId) {
    _findList(listId)?.items.removeWhere((i) => i.isChecked);
  }

  void toggleItem(String listId, String itemId) {
    final list = _findList(listId);
    if (list == null) return;
    final index = list.items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    list.items[index] = list.items[index].copyWith(
      isChecked: !list.items[index].isChecked,
    );
  }

  void editItemText(String listId, String itemId, String newText) {
    final list = _findList(listId);
    if (list == null) return;
    final index = list.items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    list.items[index] = list.items[index].copyWith(text: newText);
  }

  void moveItem(String sourceListId, String itemId) {
    final source = _findList(sourceListId);
    if (source == null || source.destinationListId == null) return;
    final dest = _findList(source.destinationListId!);
    if (dest == null) return;

    final index = source.items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final item = source.items[index].copyWith(isChecked: false);
    source.items.removeAt(index);
    dest.items.add(item);
  }

  // --- Theme ---

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
  }

  // --- Helpers ---

  PuntList? _findList(String id) {
    try {
      return lists.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }
}
