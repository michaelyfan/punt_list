# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PuntList is a mobile list app where items can be moved between lists with one tap, in addition to standard check-off behavior.

## App Concept

- Users create multiple named lists
- Each list item has a **checkbox** (check off) and a **move arrow →** (send to another list instantly)
- Move destinations are configured per-list in the settings page
- The move arrow is only shown on items when a destination is configured for that list
- Checked items are crossed out and sorted to the bottom

## Screen Flow

See `Screenshot 2026-03-07 at 11.40.37 PM.png` for the whiteboard wireframe.

**App Launch:** Tap app → Loading screen → Lists screen

Screens:
1. **Lists Screen** — shows all lists, link to settings, and UX to add new list
2. **List View** — items with checkbox + move arrow (when destination configured), title tap → rename dialog, text input to add items
3. **Title Edit Dialog** — rename a list inline
4. **Settings** — theme preferences + configure destination list for each source list's move arrow
5. **Popup/Explainer** — onboarding for the move feature

**Screen details:**
- Lists Screen: title "Lists", gear icon top-right; empty state when no lists exist
- List View: active items at top, checked/crossed-out at bottom, text input at bottom; lists without a configured destination show a message indicating no destination is set
- Settings: theme preferences (Light/Dark/System); each list maps to one destination list (or none)
- Popup/Explainer: triggered by help icon inside Settings

**Key Interactions:**

| Action | Result |
|--------|--------|
| Tap checkbox | Checks off item; crosses it out and moves to bottom |
| Tap move arrow (→) on item | Instantly moves item to configured destination list |
| Tap list title | Opens title edit dialog |
| Tap + on Lists screen | Creates and opens a new list |
| Tap gear on Lists screen | Opens Settings |
| Configure move destination in Settings | Sets destination list for each source list's move arrow |
| Tap item text | Opens inline text field to edit item |
| Uncheck a checked item | Moves it back to active (top) section |
| Checked items | Cannot be moved via the → arrow |
| Swipe item right | Indents item as child of item above (root items only) |
| Swipe item left | Promotes child to root, adopting later siblings as its children |
| Press Enter while editing | Splits item at cursor into two items |

## Behaviors

- Deleting a list clears it as a destination from any other list that referenced it
- New list creation immediately navigates to the new list (default name "New List")

## Sub-items (Sublists)

Items support one level of nesting via `parentId` on `PuntItem`. Sub-items are visually indented 48px.

### Data Model
- `PuntItem.parentId`: `null` = top-level root item, non-null = child of that parent
- `PuntItem.withParentId(String?)`: returns a copy with a new parentId (used by indent/promote)
- `DisplayItem`: wrapper used for rendering — holds the `PuntItem` plus `isGhostParent` flag and `isSubItem` getter
- `PuntList.activeDisplayItems` / `checkedDisplayItems`: hierarchy-aware display lists that group parents with their children

### Indent & Promote (Swipe Gestures)
- **Indent** (swipe right, 60px threshold): converts a root item into a child of the item above it. The item and all its children are reparented and repositioned after the new parent's last child.
- **Promote** (swipe left, 60px threshold): converts a child into a root item. Later siblings of the promoted item become children of the promoted item. The promoted block is inserted after the old parent's block.
- Only active (unchecked), non-ghost items can be swiped.

### Enter-to-Split Editing
- Pressing Enter while editing an item splits the text at the cursor position. The current item keeps text before the cursor; a new item is created with text after the cursor. The new item inherits the same `parentId` and receives auto-focus.

### Checked Propagation
- **Checking a parent**: cascades check to all children
- **Unchecking a child**: also unchecks the parent (Google Keep "incomplete" behavior)
- **Ghost parents**: when a parent is unchecked but has checked children, the parent appears in the checked section as a "ghost" — displayed with disabled styling, non-interactive checkbox, no drag handle, no delete/move buttons

### Reordering (Drag)
- Root items drag as a block with their children
- Dragging a block cannot split another parent-child group
- Child items can be dragged individually and reparent based on the item above the drop position

### Punt (Move) with Sub-items
- **Punting a sub-item**: moves the child to the destination list, creating a duplicate parent shell in the destination if one doesn't already exist (matched by parent's original ID)
- **Punting a parent**: moves the parent and all its children to the destination. If a duplicate parent already exists in the destination (from prior child punts), replaces it with the real parent

### Delete with Sub-items
- Deleting a parent cascades: removes the parent and all its children

## Detailed UI Interaction Flows

Concrete step-by-step flows derived from reading the source, useful for testing and automation.

### Create a new list
1. From Lists screen, tap the **"+"** FAB (bottom-right)
2. App immediately navigates to the new list's List View screen, titled **"New List"**

### Rename a list
1. From List View screen, tap the **list name in the AppBar**
2. A **"Rename List"** dialog appears — pre-filled text field, autofocused
3. Clear and type the new name, then tap **"Save"** (or press Enter)
4. AppBar title updates immediately; dialog closes

### Add an item to a list
1. From List View screen, tap the **"Add new item..."** text field at the bottom
2. Type the item text and press **Enter/Return** (or tap the submit button)
3. Item appears in the active items section; field clears and retains focus for next entry

### Navigate back to Lists screen
- Tap the **back arrow (←)** in the List View AppBar

### Open Settings
1. From the **Lists screen**, tap the **gear icon (⚙)** in the top-right of the AppBar
2. Settings screen opens with Theme section and Move Settings section

### Configure a move destination
1. In Settings, scroll to the **"Move Settings"** section
2. Each list has a card showing **"[List Name] moves to:"** with a **DropdownButton**
3. Tap the dropdown for the source list; options are **"— No destination —"** plus all other lists
4. Select a destination — change applies immediately, no save needed

## Running

```bash
flutter run -d chrome
```

## TODOs

### Bugs

- [ ] Delete list is bugged

### Deferred Infrastructure

- [ ] **Data persistence** — no local storage or database yet; all state is in-memory and lost on app restart
- [ ] **Authentication** — no user accounts or auth; implement later

### Deferred Features

- [ ] **Onboarding trigger logic** — currently Help popup is accessible only via Settings; decide when to auto-show (e.g. first launch only). *Skip for now.*

- [x] **Sub-bullets** — Implemented: data model with `parentId`, indent/promote gestures, enter-to-split editing, checked propagation, ghost parents, sub-item punt