# Sublist Research & Progress

Research notes and implementation progress for the sub-bullets (sublists) feature.

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
| Uncheck child of checked parent | Parent becomes unchecked too (Google Keep "incomplete" behavior); child returns to active section under parent |
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
| Indent parent with children | Parent + all children become children of the target parent above (hierarchy flattens one level) |

#### Sublist split example

Promoting `child2` from the middle of a sublist:

```
Before:
  parent1
    child1
    child2   <- promoted
    child3

After:
  parent1
    child1
  child2     <- now root-level, becomes new parent
    child3   <- adopted by child2
```

---

### Enter Key / Item Splitting Behavior

This replaces the current "submit adds item to bottom" model. Items become inline-editable with Enter-to-split behavior (similar to Google Keep):

- **End of root item** -> new root-level item inserted directly below
- **End of sub-item** -> new sub-item inserted in same sublist, directly below
- **Middle of root item** -> splits into two root-level items at cursor position
- **Middle of sub-item** -> splits into two sub-items under same parent at cursor position

Implementation note: `onSubmitted` needs access to the cursor position in the text to split correctly. This requires reworking item editing -- the `TextField` must expose cursor offset at the time Enter is pressed.

---

### Implementation Complexity

**Gesture conflict is the core challenge.** Currently `SliverReorderableList` uses long-press + vertical drag (via `ReorderableDragStartListener` on the drag handle icon). Horizontal drag-to-indent is an additional gesture -- these can conflict if both live on the same touch target.

#### Proposed Approach

A single pan recognizer with axis locking handles both axes on the same touch target:

1. `onPanStart` -- record origin, commit to no axis yet
2. `onPanUpdate` -- accumulate `dx` and `dy`
3. Once total displacement exceeds ~8px slop: compare `|dx|` vs `|dy|`; the larger axis wins and locks
4. All subsequent events route to the winner; the loser drops out

#### Flutter Implementation Notes

Flutter's gesture arena rejects combining `onHorizontalDragUpdate` + `onVerticalDragUpdate` on the same widget -- use `onPanUpdate` and lock the axis manually instead:

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

This approach lets the drag handle do both -- matching Keep's UX exactly.

**`SliverReorderableList` changes needed:**
- Reorder callback must treat parent+children as a block: when dragging a parent, all its children ride along and move together in the data
- Visual collapse during parent move: while dragging a parent, render its children hidden/collapsed so the user isn't overwhelmed

**`activeItems`/`checkedItems` logic changes:**
- Currently simple `isChecked` filters; needs to become hierarchy-aware
- Active section: unchecked parents with their unchecked children
- Checked section: checked children grouped under a **ghost parent** -- a greyed-out, non-interactive copy of the parent shown for grouping context only. The real parent stays in the active section. When the parent itself is checked (all children checked), the whole group appears in checked section with the parent fully interactive.
- If all children are checked and user checks parent -> whole group moves to checked section. If user then unchecks any child -> parent also unchecks (Google Keep "incomplete" behavior), parent + unchecked children return to active, remaining checked children stay in checked section under a ghost parent.

**Enter-to-split editing:**
- `onSubmitted` needs cursor position at time of Enter press
- Must split text at cursor, update current item, and insert a new item immediately after in the flat array

---

### Sub-item Punt Behavior

When -> is tapped on a sub-item, it moves to the destination list grouped under its parent. E.g. punting `child1` from `parent1` shows `child1` under `parent1` in the destination.

#### Ghost parent

The parent entry must exist in the destination for grouping. If it isn't already there, a **ghost parent** is created -- a new item in the destination with the same ID and text as the source parent. The source parent itself stays in the source list untouched.

**ID scoping:** This requires treating item IDs as **list-scoped** (unique within a list, not globally). The ghost parent shares the source parent's ID, so the same ID exists in two lists simultaneously. This is already implicit in the data model (`PuntItem` only lives inside a `PuntList`) -- just needs to be made explicit.

**Grouping subsequent punted children:** When a second child is punted from the same source parent, the destination is checked for an item with the matching parent ID. If found, the child is added under it. This means multiple children punted separately still end up correctly grouped.

#### Checked state is preserved

When punting a parent (-> on parent), all children -- checked or unchecked -- ride along with their `isChecked` state intact. The "checked items cannot be punted" rule applies only to the individual sub-item -> button, not to children carried along by a parent punt.

#### Edge cases

| Scenario | Behavior |
|---|---|
| Punt child, then punt parent later | Destination already has ghost-parent (same ID); parent punt merges into it rather than duplicating |
| Destination has unrelated item with same text as parent | Two items with same display text appear -- structurally correct since IDs differ; no fix without user intent |
| Ghost parent checked/punted in destination | Behaves identically to a real parent -- no special-casing needed |
| Source parent renamed after child was punted | Ghost parent retains the name captured at punt time; rename does not propagate |
| User deletes ghost parent in destination | Hard-deletes all children under it (consistent with existing delete rule) -- consider a warning |
| **Checked children during indent/promote** | **Unresolved** -- see below |

#### Checked children during indent/promote (unresolved)

When a parent with checked children is indented (or a sibling is promoted, reparenting checked children):

- `indentItem` collects all children (checked and unchecked) and reparents them to the target parent. A checked child silently moves from its original parent to the target parent.
- `promoteItem` reparents later siblings (checked and unchecked) to the promoted item. A checked child silently changes parents.

In both cases, the checked child appears in the checked section under a different ghost parent than before. The user may not realize the reparenting happened.

**Preferred fix (not yet implemented):** Only move unchecked children during indent/promote. Checked children stay with their original parent. Rationale: checking something off means "done" -- it shouldn't silently move around.

#### Open decisions

- **Rename propagation:** renaming source parent does NOT update ghost parents in other lists (keep simple)
- **Ghost parent deletion warning:** TBD -- deleting a ghost parent also deletes punted children the user may care about
- **Checked children reparenting:** fix indent/promote to leave checked children with original parent (see edge case above)

---

### Native vs 3rd Party -- Verdict

**Go native.** The one-level constraint keeps the tree simple enough that no tree view library is needed. `flutter_fancy_tree_view` is designed for arbitrary depth and its drag API would conflict with the specific horizontal-drag-to-indent UX required.

Work breakdown:
1. `parentId` on `PuntItem` + updated state operations in `AppState`
2. Horizontal swipe gesture detection on `ItemTile`
3. Indent rendering (left padding on sub-items)
4. Block-move logic in `reorderItem` for parent+children
5. Enter-to-split editing behavior
6. Checked propagation through parent -> children

---

## Milestones

### M1: Data model + basic rendering -- DONE

- [x] Add `parentId` to `PuntItem`
- [x] Add `withParentId()` method to `PuntItem` for reparenting
- [x] Add `DisplayItem` wrapper class with `isGhostParent` flag
- [x] Update `AppState` operations (delete cascades, toggle cascades parent<->child)
- [x] Hierarchy-aware `activeDisplayItems` and `checkedDisplayItems` on `PuntList`
- [x] Render sub-items with 48px left-padding indent
- [x] Checked propagation (parent check -> all children check; uncheck child -> uncheck parent)
- [x] Ghost parent rendering in checked section (greyed-out, non-interactive)
- [x] Move (punt) parent -> moves parent + all children as block
- [x] Sub-item punt deferred (returns early in `moveItem`)

### M2: Gesture + editing -- DONE

What was implemented:

- [x] `PuntItem.withParentId()` helper for reparenting
- [x] `PuntList.hasChildren()` helper
- [x] Horizontal swipe gesture on `ItemTile` using `GestureDetector` with `onHorizontalDragUpdate`/`End`
  - Swipe right to indent (become child of item above)
  - Swipe left to promote (become root item)
  - Visual feedback via `Transform.translate`, clamped to 60px threshold, snaps back on release
  - `GestureDetector` placed inside the Card wrapping the Row content with `HitTestBehavior.opaque` so it works on the drag handle area too
- [x] `AppState.indentItem(listId, itemId, targetParentId)` -- reparents item + its children to target parent
- [x] `AppState.promoteItem(listId, itemId)` -- promotes sub-item to root; later siblings become its children (sublist split)
- [x] `AppState.splitItem(listId, itemId, beforeText, afterText)` -- splits item text at cursor, returns new item ID
- [x] `AppState.reorderItem` rewritten for block moves -- parent + unchecked children move as a unit
- [x] Enter-to-split editing: Enter in edit TextField splits text at cursor position; unfocus commits without split
- [x] Auto-focus: `ListViewScreen` tracks `_autoFocusItemId`; newly split items auto-enter edit mode
- [x] `canIndent` computed per item in `ListViewScreen`: root item with an item above (parents with children can also indent)
- [x] `canPromote` computed per item: must be a sub-item

Implementation notes:
- Gesture approach uses separate `GestureDetector` (horizontal drag) from `ReorderableDragStartListener` (long-press). No gesture conflict because they're different gesture types.
- Did NOT implement the pan-with-axis-locking approach from the research notes. The simpler approach of separate gesture detectors works because the drag handle uses long-press (not pan) for reorder.
- Visual collapse during parent drag is deferred (polish). Children stay visible during drag but the data operation is correct.

### M3: Sub-item punt -- PENDING

- [ ] Ghost parent creation logic
- [ ] Grouping subsequent punted children under existing ghost parent
- [ ] Edge case handling (punt child then parent, ghost parent merges)
- [ ] Fix checked children reparenting during indent/promote (see edge cases)
