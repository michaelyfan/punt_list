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

If `editItemText` returns false (limit), revert the controller text and show
a SnackBar — do not leave the field in an inconsistent state.

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
