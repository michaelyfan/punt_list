# lib/widgets

Reusable widgets, including the swipe/edit-heavy `ItemTile`.

## ItemTile

The most behavior-dense widget in the app. Owns:

- **Inline edit** — tap text → editable `TextField`. `onSubmitted` (Enter)
  splits at cursor via `onSplit` callback (which calls `AppState.splitItem`).
  The screen sets `autoFocus: true` on the new item id so it picks up focus.
- **Swipe indent/promote** — horizontal drag with a 60px threshold.
  `canIndent` / `canPromote` and the `indentTargetParentId` are computed by
  the parent (the screen) from the item's position in `activeDisplayItems`,
  not by the tile itself. The tile only triggers the callback once threshold
  is crossed.
- **Ghost parent** — `isGhostParent: true` renders the parent in a disabled
  style (no checkbox toggle, no swipe, no move arrow). Ghost parents only
  appear in the checked section.
- **Sub-item indent** — purely visual (48px left padding when `isSubItem`).
- **Backspace-delete / merge** — a `Focus.onKeyEvent` wrapper around the edit
  `TextField` intercepts Backspace when the caret is collapsed at offset 0 and
  fires `onBackspaceAtStart`. The screen runs `AppState.backspaceAtStart`
  (delete empty / prepend-merge into previous) and then auto-focuses the
  previous item via the shared focus node, passing the caret position through
  `autoFocusCursorOffset`. `didUpdateWidget` re-applies autoFocus so a *reused*
  tile (the previous item already on screen) re-enters edit mode.
- **Trash icon** — only rendered when the item `hasChildren` (parents of a
  sub-list, plus ghost parents). Childless items have no trash icon; Backspace
  is their delete path. Parents are exempt from Backspace-delete, hence the
  retained affordance.

If `editItemText` returns false (limit), revert the controller text and show
a SnackBar — do not leave the field in an inconsistent state.

## Enter / Backspace item editing (consolidated reference)

This is the single source of truth for Enter-to-split and Backspace
delete/merge while inline-editing an item. The logic is split across three
files by responsibility:

| File | Responsibility |
|------|----------------|
| `item_tile.dart` | **Key detection.** `onSubmitted` (Enter) and `Focus.onKeyEvent` (Backspace) detect the gesture, read the caret/text from the controller, and fire callbacks. No state mutation here. |
| `app_state.dart` | **State mutation.** `splitItem` and `backspaceAtStart` mutate `PuntList.items` (and fire Firestore writes). They are pure model operations and return the info the screen needs to move focus. |
| `list_view_screen.dart` | **Orchestration.** Wires the callbacks, owns the shared `_editFocusNode` and the `_autoFocusItemId` / `_autoFocusCursorOffset` fields, and decides which tile autofocuses next. |

### Enter — split at cursor (`splitItem`)

- `ItemTile._handleSplit` (on `TextField.onSubmitted`) reads the caret offset
  and slices the text into `before` (trimmed) and `after` (trimmed). An
  invalid/`-1` caret is treated as end-of-text. If `before` is empty the full
  original text is kept as `before` (Enter at offset 0 doesn't blank the item).
- `AppState.splitItem` writes `before` back onto the original item and inserts
  a **new** `PuntItem` (`after`) immediately after it. For a root item with
  children the new item is inserted *after the whole child block* so it stays a
  root sibling; for a sub-item the new item inherits the same `parentId`
  (stays a sub-item). Returns the new item's id.
- **Focus transfer:** the screen sets `_autoFocusItemId = newId`,
  `_autoFocusCursorOffset = 0`. On rebuild the new tile gets `autoFocus: true`
  and grabs the shared focus node, caret at offset 0.
- **Char-limit exempt:** split is text-preserving (total chars unchanged), so
  `splitItem` returns `void`/id, never a `bool` gate.

### Backspace at caret offset 0 (`backspaceAtStart`)

`ItemTile._handleKeyEvent` only fires when the caret is **collapsed at offset
0**; otherwise it returns `ignored` and the normal TextField backspace runs.
`AppState.backspaceAtStart` then decides, returning a
`({String previousItemId, int cursorOffset})?` record (null = no-op, tile lets
default backspace proceed):

- **Parent exemption:** if the item `hasChildren`, returns null (no
  delete/merge). Parents keep the trash icon as their delete path.
- **First-item guard:** "previous item" is the item *before this one in
  `list.activeDisplayItems`* (display order, not flat `items` order). If this
  item is first in that order (`pos <= 0`), returns null.
- **Empty item → delete:** if the item's text is empty, remove it; caret goes
  to the **end** of the previous item (`cursorOffset = previous.text.length`).
- **Non-empty → merge:** prepend this item's text onto the previous item, then
  delete this item. Caret goes to the **merge boundary**
  (`cursorOffset = this.text.length`, i.e. just after the prepended text).
- **Focus transfer:** the screen sets `_autoFocusItemId = previousItemId` and
  `_autoFocusCursorOffset = cursorOffset`. The previous tile is *already on
  screen and reused*, so `initState` does not re-run — `ItemTile.didUpdateWidget`
  detects `autoFocus` flipping false→true and re-enters edit mode with the
  caret at the offset.
- **Char-limit exempt:** merge only concatenates existing text (no net growth).

### Focus architecture (why no keyboard flash)

`ListViewScreen` owns one shared `FocusNode _editFocusNode` and passes it to
every active `ItemTile` as `sharedEditFocusNode`. Each tile binds its
`TextField` to this same node (falling back to an internal `_ownFocusNode` only
when null, e.g. isolated widget tests — which is why tests can render a tile in
isolation). Because the focus node is shared and never disposed between the old
and new/previous tile, focus never drops during a split or merge, so the soft
keyboard stays open instead of flashing closed/reopen.

`autoFocusCursorOffset` is clamped to the text length in
`_applyAutoFocus` and applied via `WidgetsBinding.addPostFrameCallback` after
the rebuild. The screen clears `_autoFocusItemId` in its own post-frame
callback so a tile only autofocuses once per operation.

## DestinationDropdown

Excludes the current list from options (a list can't punt to itself). When
the chosen destination list is later deleted, `AppState.deleteList` clears
the reference (`destinationListId = null`); the dropdown reflects that on
next build with no extra wiring.

## AuthGate

`StreamBuilder` over `FirebaseAuth.authStateChanges()`. On sign-in it builds
a `FirestoreService` for that user and runs `AppState.init`. Sign-out tears
down — `AppState` is reconstructed on next sign-in (no stale data carried
across users).

## Dialogs

`AddItemsDialog`, `RenameListDialog`, `HelpDialog` — return their result via
`Navigator.pop(value)`. Callers always handle a `null` return (user
dismissed). Don't perform mutations inside dialogs; return data and let the
calling screen mutate so SnackBars show on the right Scaffold.
