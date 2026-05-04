# lib/screens

Top-level routes: auth, lists, list view, settings.

## State propagation

Screens receive `appState` and `update` from the parent (no Provider, no
inherited widget). Mutate via `widget.update(() => widget.appState.foo(...))`
when UI rebuild is needed. `AppState` mutators do not notify — see
`../state/CLAUDE.md`.

## Limit-gated actions show a SnackBar

`addItems`, `editItemText`, and `moveItem` return `bool`. When false, the
screen (or `ItemTile`) shows a SnackBar explaining the per-list character
limit was hit. Capture the `ScaffoldMessenger` before any `await` to avoid
"used a BuildContext across an async gap" lints.

## ListViewScreen specifics

- `_autoFocusItemId` is set after `splitItem` so the newly created item's
  `ItemTile` enters edit mode with focus on next build.
- The reorderable list operates on `activeDisplayItems` indices. Translation
  back to flat-list positions happens in `AppState.reorderItem` — don't try
  to do it here.
- Move arrow visibility is `list.destinationListId != null` AND item is
  unchecked. Checked items cannot be punted.

## Auth flow

`AuthGate` (in `lib/widgets/`) decides whether to render `AuthScreen` or the
main app. Screens here can assume a signed-in user; `AppState.init` has
already run by the time they mount.
