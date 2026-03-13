import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/item_tile.dart';
import '../widgets/rename_list_dialog.dart';

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
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    widget.update(() {
      widget.appState.addItem(widget.listId, text);
    });
    _addController.clear();
    _addFocusNode.requestFocus();
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

  void _deleteList(BuildContext context) {
    widget.update(() {
      widget.appState.deleteList(widget.listId);
    });
    // Navigator.pop is handled by the null-list guard in build()
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.appState.lists
        .cast()
        .firstWhere((l) => l.id == widget.listId, orElse: () => null);

    if (list == null) {
      // List was deleted; pop on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final activeItems = list.activeItems;
    final checkedItems = list.checkedItems;
    final hasDestination = list.destinationListId != null;
    final destName = hasDestination
        ? widget.appState.lists
            .cast()
            .firstWhere((l) => l.id == list.destinationListId, orElse: () => null)
            ?.name
        : null;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showRenameDialog(context, list.name),
          child: Text(list.name),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteList(context),
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
                ? const Center(child: Text('No items yet. Add one below!'))
                : ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    children: [
                      ...activeItems.map((item) => ItemTile(
                            key: ValueKey(item.id),
                            item: item,
                            listId: widget.listId,
                            showMoveButton: hasDestination,
                            appState: widget.appState,
                            update: widget.update,
                          )),
                      if (activeItems.isNotEmpty && checkedItems.isNotEmpty)
                        const Divider(indent: 16, endIndent: 16),
                      ...checkedItems.map((item) => ItemTile(
                            key: ValueKey(item.id),
                            item: item,
                            listId: widget.listId,
                            showMoveButton: false,
                            appState: widget.appState,
                            update: widget.update,
                          )),
                    ],
                  ),
          ),

          // Add item input
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: TextField(
              controller: _addController,
              focusNode: _addFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addItem(),
              decoration: InputDecoration(
                hintText: 'Add new item...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
