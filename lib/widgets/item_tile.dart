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

  /// Called when Backspace is pressed while the editor caret is at the logical
  /// start of the text (offset 0). The screen decides whether to delete this
  /// (empty) item or merge it into the previous one. Returns true if an
  /// operation occurred (this item went away and focus moved elsewhere), false
  /// for a no-op (e.g. first item) so the editor restores its start state.
  ///
  /// Detection is sentinel-based rather than key-event-based so it works on
  /// mobile soft keyboards — see [editStartSentinel].
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

  /// Zero-width space prepended to the edit buffer so that a Backspace pressed
  /// at the logical start of the text produces a *detectable* edit (the
  /// sentinel is deleted) instead of a no-op. This is what makes
  /// Backspace-at-start work on mobile soft keyboards, which deliver edits as
  /// text deltas rather than raw key events. Never persisted to the model —
  /// stripped on read (see `_logicalText`).
  static const String editStartSentinel = '\u200B';

  @override
  State<ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<ItemTile> {
  bool _isEditing = false;
  late final TextEditingController _controller;
  FocusNode? _ownFocusNode;
  double _swipeOffset = 0;
  static const _swipeThreshold = 60.0;

  /// Guards `_controller` mutations we make ourselves (rebuilding the sentinel
  /// buffer) so `_onControllerChanged` doesn't treat them as user edits.
  bool _mutatingBuffer = false;

  /// Whether this tile uses the zero-width-space sentinel for Backspace-at-start
  /// detection. Only when a handler is wired (the real app); isolated widget
  /// tests that don't pass `onBackspaceAtStart` edit plain text.
  bool get _usesSentinel => widget.onBackspaceAtStart != null;

  /// The user-visible text in the editor, with the sentinel stripped.
  String get _logicalText {
    final t = _controller.text;
    if (_usesSentinel && t.startsWith(ItemTile.editStartSentinel)) {
      return t.substring(ItemTile.editStartSentinel.length);
    }
    return t;
  }

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

  /// Watches the edit buffer for the sentinel disappearing from the front,
  /// which a Backspace at the logical start produces (the user deleted the
  /// sentinel). On a real soft keyboard this is the only reliable signal —
  /// there is no raw key event to observe.
  void _onControllerChanged() {
    if (_mutatingBuffer || !_isEditing || !_usesSentinel) return;
    final text = _controller.text;
    if (text.startsWith(ItemTile.editStartSentinel)) return; // sentinel intact

    if (text.contains(ItemTile.editStartSentinel)) {
      // The user typed *before* the sentinel (caret at absolute 0). Pull the
      // sentinel back to the front so start-detection keeps working.
      _renormalizeBuffer();
    } else {
      // Sentinel was deleted → Backspace at the logical start of the text.
      _handleBackspaceAtStart();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
    _controller.addListener(_onControllerChanged);
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

  /// Requests focus and (re)builds the edit buffer with the caret at
  /// [ItemTile.autoFocusCursorOffset].
  void _applyAutoFocus() {
    if (!mounted) return;
    _focusNode.requestFocus();
    _setBuffer(widget.item.text, widget.autoFocusCursorOffset);
  }

  /// Installs [content] into the controller — sentinel-prefixed when this tile
  /// uses sentinel detection — and places the caret at the logical [caret]
  /// offset (clamped to the content length). Self-mutations are flagged so
  /// `_onControllerChanged` ignores them.
  void _setBuffer(String content, int caret) {
    final offset = caret.clamp(0, content.length);
    _mutatingBuffer = true;
    if (_usesSentinel) {
      _controller.value = TextEditingValue(
        text: ItemTile.editStartSentinel + content,
        selection: TextSelection.collapsed(
            offset: offset + ItemTile.editStartSentinel.length),
      );
    } else {
      _controller.value = TextEditingValue(
        text: content,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
    _mutatingBuffer = false;
  }

  /// The user typed before the sentinel; move it back to the front, preserving
  /// the content and the caret's position relative to that content.
  void _renormalizeBuffer() {
    final raw = _controller.text;
    final sentinelAt = raw.indexOf(ItemTile.editStartSentinel);
    final content = raw.replaceFirst(ItemTile.editStartSentinel, '');
    final caret = _controller.selection.baseOffset;
    final logicalCaret = caret > sentinelAt ? caret - 1 : caret;
    _setBuffer(content, logicalCaret);
  }

  /// The sentinel was deleted (Backspace at logical start). Ask the screen to
  /// delete/merge; if it declines (no-op), restore the start state so detection
  /// keeps working.
  void _handleBackspaceAtStart() {
    final handled = widget.onBackspaceAtStart?.call(widget.item.id) ?? false;
    if (handled) {
      setState(() => _isEditing = false);
    } else {
      // No-op (e.g. first item): keep editing, caret back at logical start.
      _setBuffer(_controller.text, 0);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    // Only dispose a node this tile created; the shared node is owned by the
    // screen and outlives individual tiles.
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    // Defer focus + buffer setup until after build (the TextField must exist).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _setBuffer(widget.item.text, widget.item.text.length);
    });
  }

  void _commitEdit() {
    final text = _logicalText.trim();
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
    final text = _logicalText;
    // Caret in logical (sentinel-stripped) coordinates.
    final rawCaret = _controller.selection.baseOffset;
    final cursorPos = (_usesSentinel && rawCaret >= 0)
        ? rawCaret - ItemTile.editStartSentinel.length
        : rawCaret;
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
