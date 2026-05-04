# lib/state

`AppState` — single mutable container holding all lists + theme, plus the
Firestore write path.

## Not a ChangeNotifier

Despite what older docs might say, `AppState` is a plain class. UI rebuilds are
driven by an `update: void Function(VoidCallback)` callback threaded down from
the top-level `StatefulWidget` (typically a `setState`). Mutators here do NOT
notify on their own — callers must wrap mutations in `update(() => …)` if the
UI needs to rebuild. Tests pass `testUpdate` (a no-op) when only state
assertions matter.

## Optimistic local-first writes

Every mutator updates `lists` in-memory first, then fires a fire-and-forget
Firestore call via `_firestore?.…`. The `?.` matters: in tests and pre-init
construction `_firestore` is null and persistence silently no-ops. Do not
`await` Firestore calls from mutators — the SDK queues offline writes itself,
and awaiting would block the UI.

## Item-reordering data strategy

Order is positional in `PuntList.items`. Persistence assigns
`sortOrder = index.toDouble()` at write time (`syncListItems`), so the in-memory
list order IS the canonical order. Consequences:

- After any reorder/indent/promote/add/split, call `_persistListItems` (which
  rewrites every item's sortOrder). Surgical updates (`updateItem`,
  `batchUpdateItems`) are only safe when order is unchanged.
- `reorderItem` for root items moves the parent + its unchecked children as a
  block; `displayItems` indices coming from the UI must be translated back to
  positions in the underlying `items` list.
- Drops that would split another parent-child group are rejected (the
  `leftGroup == rightGroup` early-return).

## Character-limit gating

`addItem`, `addItems`, `editItemText`, and `moveItem` return `bool` — false
means the limit would be exceeded and nothing was changed. `splitItem` is
exempt (text-preserving). Callers in screens/widgets check the bool and show a
SnackBar.

## Punt = atomic cross-list write

`moveItem` mutates two lists locally then calls `firestore.puntItems`, which
deletes from source and writes the full destination items in one batch. If you
add another cross-list operation, follow the same pattern — never split it
into two non-atomic calls.

Ghost-parent shells in the destination are matched by the original parent's
id, so re-punting a sibling later replaces the shell rather than duplicating.
