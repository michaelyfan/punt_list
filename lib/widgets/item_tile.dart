import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Called when Backspace is pressed while the editor caret is at offset 0.
  /// The screen decides whether to delete this (empty) item or merge it into
  /// the previous one. Returns true if the tile should stop editing (an
  /// operation occurred and focus moved elsewhere), false to let the default
  /// TextField behavior proceed.
  final bool Function(String itemId)? onBackspaceAtStart;

  final bool autoFocus;

  /// Caret offset to place when [autoFocus] starts editing. Defaults to 0
  /// (used by split-created items). Backspace-merge passes the merge boundary.
  final int autoFocusCursorOffset;

  /// Shared focus node for the active inline editor. When a split creates a
  /// new item, the old tile stops editing and the new tile (autoFocus) starts
  /// editing using this same node — focus never drops, so the soft keyboard
  /// stays open instead of flashing closed/open. Optional: when null, each
  /// tile falls back to an internal node (used by isolated widget tests).
  final FocusNode? sharedEditFocusNode;

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
    this.onBackspaceAtStart,
    this.autoFocus = false,
    this.autoFocusCursorOffset = 0,
    this.sharedEditFocusNode,
  });

  @override
  State<ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<ItemTile> {
  bool _isEditing = false;
  late final TextEditingController _controller;
  FocusNode? _ownFocusNode;
  double _swipeOffset = 0;
  static const _swipeThreshold = 60.0;

  /// The node bound to this tile's TextField. Prefers the screen-shared node
  /// so focus survives split transitions; falls back to an internal node.
  FocusNode get _focusNode =>
      widget.sharedEditFocusNode ?? (_ownFocusNode ??= FocusNode());

  /// True when this item is a parent of a sub-list (has at least one child).
  /// Parents are exempt from Backspace-delete/merge, so they retain the trash
  /// icon as their delete affordance.
  bool get _hasChildren {
    final matches = widget.appState.lists.where((l) => l.id == widget.listId);
    if (matches.isEmpty) return false;
    return matches.first.hasChildren(widget.item.id);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _commitEdit();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
    _focusNode.addListener(_onFocusChange);
    if (widget.autoFocus) {
      _isEditing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyAutoFocus());
    }
  }

  @override
  void didUpdateWidget(ItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep controller text in sync if the item text changed externally
    if (!_isEditing && widget.item.text != _controller.text) {
      _controller.text = widget.item.text;
    }
    // autoFocus flips true on an existing tile when the previous item absorbs a
    // Backspace delete/merge (the previous tile is reused, so initState does not
    // re-run). Enter edit mode and grab focus in that case.
    if (widget.autoFocus && !oldWidget.autoFocus) {
      setState(() => _isEditing = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyAutoFocus());
    }
  }

  /// Requests focus and positions the caret at [ItemTile.autoFocusCursorOffset]
  /// (clamped to the current text length).
  void _applyAutoFocus() {
    if (!mounted) return;
    _focusNode.requestFocus();
    final offset =
        widget.autoFocusCursorOffset.clamp(0, _controller.text.length);
    _controller.selection = TextSelection.collapsed(offset: offset);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    // Only dispose a node this tile created; the shared node is owned by the
    // screen and outlives individual tiles.
    _ownFocusNode?.dispose();
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

  /// Intercepts Backspace at caret offset 0 so the screen can delete this
  /// (empty) item or merge it into the previous one. Returns
  /// [KeyEventResult.handled] when an operation occurred so the default
  /// TextField backspace does not also run; otherwise [ignored].
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (widget.onBackspaceAtStart == null) return KeyEventResult.ignored;

    final selection = _controller.selection;
    // Only act on a collapsed caret sitting at the very start of the text.
    if (!selection.isCollapsed || selection.baseOffset != 0) {
      return KeyEventResult.ignored;
    }

    final handled = widget.onBackspaceAtStart!(widget.item.id);
    if (handled) {
      setState(() => _isEditing = false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
                  ? Focus(
                      // Observes key events from the focused TextField below so
                      // Backspace-at-start can delete/merge; does not steal
                      // focus or traversal from the field itself.
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: _handleKeyEvent,
                      child: TextField(
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
        // The per-item trash icon was removed in favor of Backspace-to-delete
        // (empty item) / Backspace-to-merge (caret at start). Parents of a
        // sub-list are exempt from that behavior, so they would otherwise have
        // no delete entry point — keep the trash icon for those (and for ghost
        // parents, which represent an unchecked parent with checked children).
        if (_hasChildren)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete (with sub-items)',
            onPressed: () => widget.update(() {
              widget.appState.deleteItem(widget.listId, widget.item.id);
            }),
          ),
        if (widget.showMoveButton && !isChecked && !isGhost)
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            tooltip: 'Move',
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
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
