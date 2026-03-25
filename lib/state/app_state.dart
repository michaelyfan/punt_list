import 'package:flutter/material.dart';
import '../models/punt_item.dart';
import '../models/punt_list.dart';

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

AppState seedData() {
  final list1 = PuntList(id: '1', name: 'List 1', items: [
    PuntItem(id: '1-1', text: 'Buy groceries'),
    PuntItem(id: '1-1a', text: 'Milk', parentId: '1-1'),
    PuntItem(id: '1-1b', text: 'Eggs', parentId: '1-1'),
    PuntItem(id: '1-1c', text: 'Bread', parentId: '1-1', isChecked: true),
    PuntItem(id: '1-2', text: 'Solo item'),
    PuntItem(id: '1-3', text: 'Pack bag'),
    PuntItem(id: '1-3a', text: 'Laptop', parentId: '1-3'),
    PuntItem(id: '1-3b', text: 'Charger', parentId: '1-3'),
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
    final rawNewIndex = newIndex;
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final displayItems = list.activeDisplayItems;
    if (oldIndex >= displayItems.length || newIndex >= displayItems.length) return;

    final draggedItem = displayItems[oldIndex].item;

    if (draggedItem.parentId != null) {
      // --- Child item drag: move single child ---
      list.items.removeWhere((i) => i.id == draggedItem.id);

      // Recompute display without dragged item
      final tempList = PuntList(id: 'temp', name: 'temp', items: List.from(list.items));
      final newDisplay = tempList.activeDisplayItems;

      // Determine new parent from item above drop position
      String? newParentId;
      if (newIndex > 0) {
        final aboveIndex = (newIndex - 1).clamp(0, newDisplay.length - 1);
        final aboveItem = newDisplay[aboveIndex].item;
        newParentId = aboveItem.parentId ?? aboveItem.id;
      }
      // newIndex == 0: becomes root (newParentId stays null)

      final movedItem = draggedItem.withParentId(newParentId);

      // Insert at correct position in raw items
      if (newIndex >= newDisplay.length) {
        final lastActive = list.items.lastIndexWhere((i) => !i.isChecked);
        list.items.insert(lastActive + 1, movedItem);
      } else {
        final targetItem = newDisplay[newIndex].item;
        final targetIdx = list.items.indexWhere((i) => i.id == targetItem.id);
        list.items.insert(targetIdx == -1 ? list.items.length : targetIdx, movedItem);
      }
      return;
    }

    // --- Root item drag: move parent + children block ---

    // Compute block range in display list
    int blockEnd = oldIndex;
    for (int i = oldIndex + 1; i < displayItems.length; i++) {
      if (displayItems[i].item.parentId == draggedItem.id) {
        blockEnd = i;
      } else {
        break;
      }
    }
    final blockSize = blockEnd - oldIndex + 1;

    // No-op if dropping within own block
    if (newIndex >= oldIndex && newIndex <= blockEnd) return;

    // No-op if insertion would split another parent-child group
    if (rawNewIndex > 0 && rawNewIndex < displayItems.length) {
      final leftItem = displayItems[rawNewIndex - 1].item;
      final rightItem = displayItems[rawNewIndex].item;
      final leftGroup = leftItem.parentId ?? leftItem.id;
      final rightGroup = rightItem.parentId ?? rightItem.id;
      if (leftGroup == rightGroup) return;
    }

    // Adjust newIndex for block removal (line 92 only subtracted 1)
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
    final remaining = list.items.where((i) => !blockIds.contains(i.id)).toList();

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
  }

  void indentItem(String listId, String itemId, String targetParentId) {
    final list = _findList(listId);
    if (list == null) return;
    final itemIndex = list.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;
    final item = list.items[itemIndex];
    // Must be a root item
    if (item.parentId != null) return;

    // Collect the item and its children as a block
    final block = <PuntItem>[item.withParentId(targetParentId)];
    for (final child in list.items) {
      if (child.parentId == itemId) {
        block.add(child.withParentId(targetParentId));
      }
    }

    // Remove the block from the list
    final blockIds = block.map((i) => i.id).toSet();
    list.items.removeWhere((i) => blockIds.contains(i.id));

    // Find position after target parent's last child
    int parentIdx = list.items.indexWhere((i) => i.id == targetParentId);
    if (parentIdx == -1) return;
    int insertAt = parentIdx + 1;
    while (insertAt < list.items.length &&
        list.items[insertAt].parentId == targetParentId) {
      insertAt++;
    }
    list.items.insertAll(insertAt, block);
  }

  void promoteItem(String listId, String itemId) {
    final list = _findList(listId);
    if (list == null) return;
    final itemIndex = list.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;
    final item = list.items[itemIndex];
    if (item.parentId == null) return; // already root

    final oldParentId = item.parentId!;

    // Find siblings that come after this item — they become children of promoted item
    final laterSiblings = <int>[];
    for (int i = itemIndex + 1; i < list.items.length; i++) {
      if (list.items[i].parentId == oldParentId) {
        laterSiblings.add(i);
      } else if (list.items[i].parentId == null) {
        break; // hit next root item, stop
      }
    }

    // Reparent later siblings to promoted item
    for (final idx in laterSiblings) {
      list.items[idx] = list.items[idx].withParentId(itemId);
    }

    // Promote this item to root
    list.items[itemIndex] = item.withParentId(null);

    // Move promoted item (+ its new children) to after old parent's block
    // First, collect the promoted block
    final promotedBlock = <PuntItem>[list.items[itemIndex]];
    for (final idx in laterSiblings) {
      promotedBlock.add(list.items[idx]);
    }

    // Remove them all (indices shift, so remove by ID)
    final blockIds = promotedBlock.map((i) => i.id).toSet();
    list.items.removeWhere((i) => blockIds.contains(i.id));

    // Find end of old parent's block
    int parentIdx = list.items.indexWhere((i) => i.id == oldParentId);
    if (parentIdx == -1) {
      // Parent gone, just append
      list.items.addAll(promotedBlock);
      return;
    }
    int insertAt = parentIdx + 1;
    while (insertAt < list.items.length &&
        list.items[insertAt].parentId == oldParentId) {
      insertAt++;
    }
    list.items.insertAll(insertAt, promotedBlock);
  }

  /// Splits item text at cursor. Returns new item's ID for auto-focus.
  String splitItem(String listId, String itemId, String beforeText, String afterText) {
    final list = _findList(listId);
    final newId = _newId();
    if (list == null) return newId;
    final itemIndex = list.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return newId;
    final item = list.items[itemIndex];

    // Update current item text
    list.items[itemIndex] = item.copyWith(text: beforeText.isEmpty ? beforeText : beforeText);

    // Determine insert position: after current item's children (if root), or right after current item (if sub-item)
    int insertAt = itemIndex + 1;
    if (item.parentId == null) {
      // Skip past children
      while (insertAt < list.items.length &&
          list.items[insertAt].parentId == itemId) {
        insertAt++;
      }
    }

    // New item has same parentId
    list.items.insert(
      insertAt,
      PuntItem(id: newId, text: afterText, parentId: item.parentId),
    );
    return newId;
  }

  void deleteItem(String listId, String itemId) {
    final list = _findList(listId);
    if (list == null) return;
    // If it's a parent, cascade delete all children
    list.items.removeWhere((i) => i.id == itemId || i.parentId == itemId);
  }

  void clearCheckedItems(String listId) {
    _findList(listId)?.items.removeWhere((i) => i.isChecked);
  }

  void toggleItem(String listId, String itemId) {
    final list = _findList(listId);
    if (list == null) return;
    final index = list.items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final item = list.items[index];
    final newChecked = !item.isChecked;
    list.items[index] = item.copyWith(isChecked: newChecked);

    if (item.parentId == null) {
      // Parent: cascade to all children
      for (int i = 0; i < list.items.length; i++) {
        if (list.items[i].parentId == itemId) {
          list.items[i] = list.items[i].copyWith(isChecked: newChecked);
        }
      }
    } else if (!newChecked) {
      // Unchecking a child: if parent is checked, uncheck parent too
      // (Google Keep "incomplete" behavior)
      final parentIndex =
          list.items.indexWhere((i) => i.id == item.parentId);
      if (parentIndex != -1 && list.items[parentIndex].isChecked) {
        list.items[parentIndex] =
            list.items[parentIndex].copyWith(isChecked: false);
      }
    }
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
    final item = source.items[index];

    if (item.parentId != null) {
      // Sub-item punt: move child to destination, grouped under a duplicate parent
      final parentIndex = source.items.indexWhere((i) => i.id == item.parentId);
      if (parentIndex == -1) return;
      final parent = source.items[parentIndex];

      // Check if destination already has the parent (from a prior punt)
      final existingParentIndex = dest.items.indexWhere((i) => i.id == parent.id);
      if (existingParentIndex == -1) {
        // Create duplicate parent in destination
        dest.items.add(PuntItem(
          id: parent.id,
          text: parent.text,
          parentId: null,
        ));
      }

      // Remove from source and add to destination under the parent
      source.items.removeAt(index);
      dest.items.add(item.copyWith(isChecked: false));
      return;
    }

    // Parent punt: check if destination already has a duplicate (from prior child punts)
    final existingIndex = dest.items.indexWhere((i) => i.id == itemId);

    // Collect all children from source
    final children =
        source.items.where((i) => i.parentId == itemId).toList();
    source.items
        .removeWhere((i) => i.id == itemId || i.parentId == itemId);

    if (existingIndex != -1) {
      // Replace the duplicate parent with the real one
      dest.items[existingIndex] = item.copyWith(isChecked: false);
    } else {
      dest.items.add(item.copyWith(isChecked: false));
    }
    dest.items.addAll(children);
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
