import 'package:flutter/material.dart';
import '../models/punt_item.dart';
import '../state/app_state.dart';

class ItemTile extends StatefulWidget {
  final PuntItem item;
  final String listId;
  final bool showMoveButton;
  final bool showDragHandle;
  final int itemIndex;
  final AppState appState;
  final void Function(VoidCallback) update;

  const ItemTile({
    super.key,
    required this.item,
    required this.listId,
    required this.showMoveButton,
    this.showDragHandle = false,
    this.itemIndex = 0,
    required this.appState,
    required this.update,
  });

  @override
  State<ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<ItemTile> {
  bool _isEditing = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _commitEdit();
      }
    });
  }

  @override
  void didUpdateWidget(ItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep controller text in sync if the item text changed externally
    if (!_isEditing && widget.item.text != _controller.text) {
      _controller.text = widget.item.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    // Defer focus request until after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _commitEdit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && text != widget.item.text) {
      widget.update(() {
        widget.appState.editItemText(widget.listId, widget.item.id, text);
      });
    } else {
      // Restore original text if empty or unchanged
      _controller.text = widget.item.text;
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = widget.item.isChecked;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            if (widget.showDragHandle)
              ReorderableDragStartListener(
                index: widget.itemIndex,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_indicator, color: Colors.grey),
                ),
              ),
            Checkbox(
              value: isChecked,
              onChanged: (_) => widget.update(() {
                widget.appState.toggleItem(widget.listId, widget.item.id);
              }),
            ),
            Expanded(
              child: _isEditing
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onSubmitted: (_) => _commitEdit(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _startEditing,
                      child: Text(
                        widget.item.text,
                        style: isChecked
                            ? TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Theme.of(context).disabledColor,
                              )
                            : null,
                      ),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => widget.update(() {
                widget.appState.deleteItem(widget.listId, widget.item.id);
              }),
            ),
            if (widget.showMoveButton && !isChecked)
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: const CircleBorder(),
                ),
                onPressed: () => widget.update(() {
                  widget.appState.moveItem(widget.listId, widget.item.id);
                }),
              ),
          ],
        ),
      ),
    );
  }
}
