import 'punt_item.dart';

class DisplayItem {
  final PuntItem item;
  final bool isGhostParent;

  const DisplayItem(this.item, {this.isGhostParent = false});

  bool get isSubItem => item.parentId != null;
}

class PuntList {
  final String id;
  String name;
  final List<PuntItem> items;
  String? destinationListId;

  PuntList({
    required this.id,
    required this.name,
    List<PuntItem>? items,
    this.destinationListId,
  }) : items = items ?? [];

  bool hasChildren(String itemId) =>
      items.any((i) => i.parentId == itemId);

  // Simple counts (used by ListCard)
  List<PuntItem> get activeItems => items.where((i) => !i.isChecked).toList();
  List<PuntItem> get checkedItems => items.where((i) => i.isChecked).toList();

  /// Hierarchy-aware active items for display.
  /// Returns unchecked parents with their unchecked children, in order.
  List<DisplayItem> get activeDisplayItems {
    final result = <DisplayItem>[];
    for (final item in items) {
      if (item.parentId != null) continue; // children handled with parent
      if (item.isChecked) continue;
      result.add(DisplayItem(item));
      // Add this parent's unchecked children in list order
      for (final child in items) {
        if (child.parentId == item.id && !child.isChecked) {
          result.add(DisplayItem(child));
        }
      }
    }
    return result;
  }

  /// Hierarchy-aware checked items for display.
  /// Returns:
  ///   1. Checked parents with all their children
  ///   2. Ghost parents (unchecked) with their checked children
  List<DisplayItem> get checkedDisplayItems {
    final result = <DisplayItem>[];

    // 1. Fully checked parents with all children
    for (final item in items) {
      if (item.parentId != null || !item.isChecked) continue;
      result.add(DisplayItem(item));
      for (final child in items) {
        if (child.parentId == item.id) {
          result.add(DisplayItem(child));
        }
      }
    }

    // 2. Ghost parents: unchecked parents that have checked children
    for (final item in items) {
      if (item.parentId != null || item.isChecked) continue;
      final hasCheckedChildren =
          items.any((i) => i.parentId == item.id && i.isChecked);
      if (!hasCheckedChildren) continue;
      result.add(DisplayItem(item, isGhostParent: true));
      for (final child in items) {
        if (child.parentId == item.id && child.isChecked) {
          result.add(DisplayItem(child));
        }
      }
    }

    return result;
  }
}
