import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/add_items_dialog.dart';
import '../widgets/item_tile.dart';
import '../widgets/rename_list_dialog.dart';

enum _ListAction { delete, clearChecked }

class ListViewScreen extends StatefulWidget {
  final String listId;
  final AppState appState;
  final void Function(VoidCallback) update;

  const ListViewScreen({
    super.key,
    required this.listId,
    required this.appState,
    required this.update,
  });

  @override
  State<ListViewScreen> createState() => _ListViewScreenState();
}

class _ListViewScreenState extends State<ListViewScreen> {
  String? _autoFocusItemId;

  Future<void> _showAddItemsDialog(BuildContext context) async {
    final lines = await showDialog<List<String>>(
      context: context,
      builder: (_) => const AddItemsDialog(),
    );
    if (lines == null || lines.isEmpty) return;
    widget.update(() {
      widget.appState.addItems(widget.listId, lines);
    });
  }

  Future<void> _showRenameDialog(BuildContext context, String currentName) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => RenameListDialog(currentName: currentName),
    );
    if (newName != null) {
      widget.update(() {
        widget.appState.renameList(widget.listId, newName);
      });
    }
  }

  Future<void> _confirmDeleteList(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete list?'),
        content: const Text('This will permanently delete the list and all its items.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Gather undo data before deletion
    final index = widget.appState.lists.indexWhere((l) => l.id == widget.listId);
    if (index == -1) return;
    final list = widget.appState.lists[index];
    final dependents = widget.appState.lists
        .where((l) => l.destinationListId == widget.listId)
        .map((l) => l.id)
        .toList();

    widget.update(() {
      widget.appState.deleteList(widget.listId);
    });

    // Show undo snackbar — ScaffoldMessenger persists across navigation
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('"${list.name}" deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            widget.update(() {
              widget.appState.restoreList(list, index, dependents);
            });
          },
        ),
      ),
    );
    // Navigator.pop is handled by the null-list guard in build()
  }

  Future<void> _confirmClearChecked(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear checked items?'),
        content: const Text('All checked items will be removed from this list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.update(() {
      widget.appState.clearCheckedItems(widget.listId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.appState.lists.where((l) => l.id == widget.listId);
    final list = matches.isEmpty ? null : matches.first;

    if (list == null) {
      // List was deleted; pop on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final activeItems = list.activeDisplayItems;
    final checkedItems = list.checkedDisplayItems;
    final hasDestination = list.destinationListId != null;
    final destName = hasDestination
        ? widget.appState.lists
            .where((l) => l.id == list.destinationListId)
            .map((l) => l.name)
            .firstOrNull
        : null;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showRenameDialog(context, list.name),
          child: Text(list.name),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add items',
            onPressed: () => _showAddItemsDialog(context),
          ),
          PopupMenuButton<_ListAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              if (action == _ListAction.delete) {
                _confirmDeleteList(context);
              } else if (action == _ListAction.clearChecked) {
                _confirmClearChecked(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ListAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete list'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _ListAction.clearChecked,
                child: ListTile(
                  leading: Icon(Icons.playlist_remove),
                  title: Text('Clear checked items'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Destination banner
          if (destName != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  text: 'Tap → to move items to ',
                  children: [
                    TextSpan(
                      text: destName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Items list
          Expanded(
            child: activeItems.isEmpty && checkedItems.isEmpty
                ? const Center(child: Text('No items yet. Tap + to add one.'))
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 8),
                        sliver: SliverReorderableList(
                          itemCount: activeItems.length,
                          onReorder: (oldIndex, newIndex) => widget.update(() {
                            widget.appState.reorderItem(widget.listId, oldIndex, newIndex);
                          }),
                          itemBuilder: (context, index) {
                            final displayItem = activeItems[index];
                            final item = displayItem.item;

                            // Compute canIndent: root item, not first in display list
                            bool canIndent = false;
                            String? indentTargetParentId;
                            if (item.parentId == null && index > 0) {
                              final above = activeItems[index - 1].item;
                              indentTargetParentId = above.parentId ?? above.id;
                              canIndent = true;
                            }

                            final canPromote = item.parentId != null;

                            final shouldAutoFocus = _autoFocusItemId == item.id;
                            if (shouldAutoFocus) {
                              // Clear after this build
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_autoFocusItemId == item.id) {
                                  setState(() => _autoFocusItemId = null);
                                }
                              });
                            }

                            return ItemTile(
                              key: ValueKey(item.id),
                              item: item,
                              listId: widget.listId,
                              showMoveButton: hasDestination,
                              showDragHandle: true,
                              itemIndex: index,
                              appState: widget.appState,
                              update: widget.update,
                              isSubItem: displayItem.isSubItem,
                              canIndent: canIndent,
                              canPromote: canPromote,
                              indentTargetParentId: indentTargetParentId,
                              autoFocus: shouldAutoFocus,
                              onIndent: (itemId, targetParentId) {
                                widget.update(() {
                                  widget.appState.indentItem(
                                      widget.listId, itemId, targetParentId);
                                });
                              },
                              onPromote: (itemId) {
                                widget.update(() {
                                  widget.appState.promoteItem(
                                      widget.listId, itemId);
                                });
                              },
                              onSplit: (itemId, beforeText, afterText) {
                                widget.update(() {
                                  final newId = widget.appState.splitItem(
                                      widget.listId, itemId, beforeText, afterText);
                                  _autoFocusItemId = newId;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      if (activeItems.isNotEmpty && checkedItems.isNotEmpty)
                        const SliverToBoxAdapter(
                          child: Divider(indent: 16, endIndent: 16),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 8),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            checkedItems.map((displayItem) => ItemTile(
                              key: ValueKey('${displayItem.item.id}${displayItem.isGhostParent ? '-ghost' : ''}'),
                              item: displayItem.item,
                              listId: widget.listId,
                              showMoveButton: false,
                              appState: widget.appState,
                              update: widget.update,
                              isSubItem: displayItem.isSubItem,
                              isGhostParent: displayItem.isGhostParent,
                            )).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
