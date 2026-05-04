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
  final bool isSubItem;
  final bool isGhostParent;
  final bool canIndent;
  final bool canPromote;
  final String? indentTargetParentId;
  final void Function(String itemId, String targetParentId)? onIndent;
  final void Function(String itemId)? onPromote;
  final void Function(String itemId, String beforeText, String afterText)? onSplit;
  final bool autoFocus;

  const ItemTile({
    super.key,
    required this.item,
    required this.listId,
    required this.showMoveButton,
    this.showDragHandle = false,
    this.itemIndex = 0,
    required this.appState,
    required this.update,
    this.isSubItem = false,
    this.isGhostParent = false,
    this.canIndent = false,
    this.canPromote = false,
    this.indentTargetParentId,
    this.onIndent,
    this.onPromote,
    this.onSplit,
    this.autoFocus = false,
  });

  @override
  State<ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<ItemTile> {
  bool _isEditing = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  double _swipeOffset = 0;
  static const _swipeThreshold = 60.0;

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
    if (widget.autoFocus) {
      _isEditing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        // Place cursor at start for split-created items
        _controller.selection = TextSelection.collapsed(offset: 0);
      });
    }
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
      bool ok = true;
      widget.update(() {
        ok = widget.appState
            .editItemText(widget.listId, widget.item.id, text);
      });
      if (!ok) {
        _controller.text = widget.item.text;
        _showLimitReached();
      }
    } else {
      // Restore original text if empty or unchanged
      _controller.text = widget.item.text;
    }
    setState(() => _isEditing = false);
  }

  void _showLimitReached() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('List is full (20,000-character limit reached).'),
    ));
  }

  void _handleSplit() {
    if (widget.onSplit == null) return;
    final cursorPos = _controller.selection.baseOffset;
    final text = _controller.text;
    // If cursor position is invalid, treat as end of text
    final pos = (cursorPos >= 0 && cursorPos <= text.length) ? cursorPos : text.length;
    final before = text.substring(0, pos).trim();
    final after = text.substring(pos).trim();
    setState(() => _isEditing = false);
    widget.onSplit!(widget.item.id, before.isEmpty ? text : before, after);
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = widget.item.isChecked;
    final isGhost = widget.isGhostParent;
    final indent = widget.isSubItem ? 48.0 : 0.0;
    final canSwipe = !isChecked && !isGhost && (widget.canIndent || widget.canPromote);

    Widget rowContent = Row(
      children: [
        if (widget.showDragHandle && !isGhost)
          ReorderableDragStartListener(
            index: widget.itemIndex,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_indicator, color: Colors.grey),
            ),
          ),
        Checkbox(
          value: isChecked,
          onChanged: isGhost
              ? null
              : (_) => widget.update(() {
                    widget.appState
                        .toggleItem(widget.listId, widget.item.id);
                  }),
        ),
        Expanded(
          child: isGhost
              ? Text(
                  widget.item.text,
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                  ),
                )
              : _isEditing
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onSubmitted: (_) => _handleSplit(),
                      onTapOutside: (_) => _focusNode.unfocus(),
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
        if (!isGhost)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => widget.update(() {
              widget.appState.deleteItem(widget.listId, widget.item.id);
            }),
          ),
        if (widget.showMoveButton && !isChecked && !isGhost)
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: const CircleBorder(),
            ),
            onPressed: () {
              bool ok = true;
              widget.update(() {
                ok = widget.appState
                    .moveItem(widget.listId, widget.item.id);
              });
              if (!ok) _showLimitReached();
            },
          ),
      ],
    );

    // Wrap row in swipe gesture detector if swipeable
    if (canSwipe) {
      rowContent = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          setState(() {
            _swipeOffset += details.delta.dx;
            if (_swipeOffset > 0 && !widget.canIndent) {
              _swipeOffset = 0;
            } else if (_swipeOffset < 0 && !widget.canPromote) {
              _swipeOffset = 0;
            }
            _swipeOffset = _swipeOffset.clamp(
              widget.canPromote ? -_swipeThreshold : 0,
              widget.canIndent ? _swipeThreshold : 0,
            );
          });
        },
        onHorizontalDragEnd: (_) {
          if (_swipeOffset >= _swipeThreshold && widget.canIndent && widget.indentTargetParentId != null) {
            widget.onIndent?.call(widget.item.id, widget.indentTargetParentId!);
          } else if (_swipeOffset <= -_swipeThreshold && widget.canPromote) {
            widget.onPromote?.call(widget.item.id);
          }
          setState(() => _swipeOffset = 0);
        },
        child: rowContent,
      );
    }

    return Transform.translate(
      offset: Offset(_swipeOffset, 0),
      child: Card(
        margin: EdgeInsets.only(left: 12 + indent, right: 12, top: 4, bottom: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: rowContent,
        ),
      ),
    );
  }
}
