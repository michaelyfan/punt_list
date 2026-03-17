# RESEARCH.md

Research notes for planned and investigated features.

---

## Sub-bullets (Sublists)

### Overview

Users can drag an item right to make it a sub-item of the item above it. Sublists are one level deep only. The example UI reference is `context/examples/subbullets.png`.

---

### Data Model Change

Add one field to `PuntItem`:

```dart
class PuntItem {
  final String id;
  final String text;
  final bool isChecked;
  final String? parentId;  // null = top-level, non-null = sub-item
}
```

Items stay flat in `PuntList.items`. The ordering convention is: parent immediately followed by its children contiguously. Example flat array:

```
[parent1, child1, child2, parent2, child3]
```

where `child1/child2.parentId = parent1.id`, `child3.parentId = parent2.id`.

This is a minimal change — no new model classes needed.

---

### Behavioral Rules

| Scenario | Behavior |
|---|---|
| Check parent | All sub-items checked with it |
| Uncheck parent | All sub-items unchecked with it |
| Drag item right | Becomes sub-item of the item above (or joins its existing sublist); blocked if the item above is already a sub-item (one level max) |
| Drag sub-item left (end of sublist) | Promoted to root level, no siblings affected |
| Drag sub-item left (middle of sublist) | Promoted to root; all subsequent siblings become its children (sublist splits into two parents) |
| Enter at end of root item | New root-level item inserted below |
| Enter at end of sub-item | New sub-item inserted in same sublist |
| Enter in middle of root item | Splits into two root-level items |
| Enter in middle of sub-item | Splits into two sub-items under same parent |
| Reorder parent | Parent + all its children move as a block |
| Reorder sub-item within parent | Fine |
| Drag sub-item to different parent | Becomes child of new parent |
| → on parent | Punts parent + all sub-items to destination as parent + sub-items |
| → on sub-item | Moves sub-item to destination, grouped under its parent (see Sub-item Punt Behavior below) |
| Delete parent | Hard-deletes all children |

#### Sublist split example

Promoting `child2` from the middle of a sublist:

```
Before:
  parent1
    child1
    child2   ← promoted
    child3

After:
  parent1
    child1
  child2     ← now root-level, becomes new parent
    child3   ← adopted by child2
```

---

### Enter Key / Item Splitting Behavior

This replaces the current "submit adds item to bottom" model. Items become inline-editable with Enter-to-split behavior (similar to Google Keep):

- **End of root item** → new root-level item inserted directly below
- **End of sub-item** → new sub-item inserted in same sublist, directly below
- **Middle of root item** → splits into two root-level items at cursor position
- **Middle of sub-item** → splits into two sub-items under same parent at cursor position

Implementation note: `onSubmitted` needs access to the cursor position in the text to split correctly. This requires reworking item editing — the `TextField` must expose cursor offset at the time Enter is pressed.

---

### Implementation Complexity

**Gesture conflict is the core challenge.** Currently `SliverReorderableList` uses long-press + vertical drag (via `ReorderableDragStartListener` on the drag handle icon). Horizontal drag-to-indent is an additional gesture — these can conflict if both live on the same touch target.

#### Proposed Approach

A single pan recognizer with axis locking handles both axes on the same touch target:

1. `onPanStart` — record origin, commit to no axis yet
2. `onPanUpdate` — accumulate `dx` and `dy`
3. Once total displacement exceeds ~8px slop: compare `|dx|` vs `|dy|`; the larger axis wins and locks
4. All subsequent events route to the winner; the loser drops out

#### Flutter Implementation Notes

Flutter's gesture arena rejects combining `onHorizontalDragUpdate` + `onVerticalDragUpdate` on the same widget — use `onPanUpdate` and lock the axis manually instead:

```dart
GestureDetector(
  onPanStart: (d) { _lockAxis = null; _origin = d.localPosition; },
  onPanUpdate: (d) {
    if (_lockAxis == null) {
      final dx = (d.localPosition - _origin).dx.abs();
      final dy = (d.localPosition - _origin).dy.abs();
      if (dx + dy > 8) _lockAxis = dx > dy ? Axis.horizontal : Axis.vertical;
    }
    if (_lockAxis == Axis.vertical) { /* feed into reorder */ }
    if (_lockAxis == Axis.horizontal) { /* indent/promote */ }
  },
)
```

The tricky part: feeding a locked vertical drag into `SliverReorderableList` requires calling `ReorderableListState.startItemDragReorder()` manually once the axis locks, rather than relying on `ReorderableDragStartListener` (which activates on long-press, not pan).

This approach lets the drag handle do both — matching Keep's UX exactly.

**`SliverReorderableList` changes needed:**
- Reorder callback must treat parent+children as a block: when dragging a parent, all its children ride along and move together in the data
- Visual collapse during parent move: while dragging a parent, render its children hidden/collapsed so the user isn't overwhelmed

**`activeItems`/`checkedItems` logic changes:**
- Currently simple `isChecked` filters; needs to become hierarchy-aware
- Checked section should show checked parents with their checked children inline, not a flat list

**Enter-to-split editing:**
- `onSubmitted` needs cursor position at time of Enter press
- Must split text at cursor, update current item, and insert a new item immediately after in the flat array

---

### Sub-item Punt Behavior

When → is tapped on a sub-item, it moves to the destination list grouped under its parent. E.g. punting `child1` from `parent1` shows `child1` under `parent1` in the destination.

#### Ghost parent

The parent entry must exist in the destination for grouping. If it isn't already there, a **ghost parent** is created — a new item in the destination with the same ID and text as the source parent. The source parent itself stays in the source list untouched.

**ID scoping:** This requires treating item IDs as **list-scoped** (unique within a list, not globally). The ghost parent shares the source parent's ID, so the same ID exists in two lists simultaneously. This is already implicit in the data model (`PuntItem` only lives inside a `PuntList`) — just needs to be made explicit.

**Grouping subsequent punted children:** When a second child is punted from the same source parent, the destination is checked for an item with the matching parent ID. If found, the child is added under it. This means multiple children punted separately still end up correctly grouped.

#### Checked state is preserved

When punting a parent (→ on parent), all children — checked or unchecked — ride along with their `isChecked` state intact. The "checked items cannot be punted" rule applies only to the individual sub-item → button, not to children carried along by a parent punt.

#### Edge cases

| Scenario | Behavior |
|---|---|
| Punt child, then punt parent later | Destination already has ghost-parent (same ID); parent punt merges into it rather than duplicating |
| Destination has unrelated item with same text as parent | Two items with same display text appear — structurally correct since IDs differ; no fix without user intent |
| Ghost parent checked/punted in destination | Behaves identically to a real parent — no special-casing needed |
| Source parent renamed after child was punted | Ghost parent retains the name captured at punt time; rename does not propagate |
| User deletes ghost parent in destination | Hard-deletes all children under it (consistent with existing delete rule) — consider a warning |

#### Open decisions

- **Rename propagation:** renaming source parent does NOT update ghost parents in other lists (keep simple)
- **Ghost parent deletion warning:** TBD — deleting a ghost parent also deletes punted children the user may care about

---

### Native vs 3rd Party — Verdict

**Go native.** The one-level constraint keeps the tree simple enough that no tree view library is needed. `flutter_fancy_tree_view` is designed for arbitrary depth and its drag API would conflict with the specific horizontal-drag-to-indent UX required.

Work breakdown:
1. `parentId` on `PuntItem` + updated state operations in `AppState`
2. Horizontal swipe gesture detection on `ItemTile`
3. Indent rendering (left padding on sub-items)
4. Block-move logic in `reorderItem` for parent+children
5. Enter-to-split editing behavior
6. Checked propagation through parent → children

---

## Milestones

### M1: Data model + basic rendering
- Add `parentId` to `PuntItem`
- Update `AppState` operations (delete cascades, `activeItems`/`checkedItems` become hierarchy-aware)
- Render sub-items with left-padding indent
- Checked propagation (parent check → all children check/uncheck)

### M2: Gesture + editing
- Pan gesture with axis-locking for horizontal swipe to indent/promote
- Block-move in reorder (parent + children travel together, children collapse visually during drag)
- Enter-to-split editing (replaces current "add to bottom" model)

### M3: Sub-item punt
- Ghost parent creation logic
- Grouping subsequent punted children under existing ghost parent
- Edge case handling (punt child then parent, ghost parent merges)
