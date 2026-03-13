# PROGRESS.md

Tracks TODOs and implementation notes for PuntList.

## Bugs

- [ ] Delete list is bugged

## Deferred Infrastructure

- [ ] **Data persistence** — no local storage or database yet; all state is in-memory and lost on app restart
- [ ] **Authentication** — no user accounts or auth; implement later

## Deferred Features

- [ ] **Item reordering** — drag-to-reorder active items within a list. Use a six-dot icon to convey the ability to drag. See `context/Reorder Item Example.png` for reference.

- [ ] **Undo on delete** — snackbar with undo when an item or list is deleted

- [ ] **Clear checked items** — Replace the current top-right delete button in the List View toolbar with a three-dot (⋮) button that opens a collapsible popup menu with two options:
  1. Delete list (existing behavior)
  2. Clear checked items (asks for confirmation before acting)
  - Each menu item should show an icon + text label (not icon only)

- [ ] **List ordering** — drag-to-reorder lists on the Lists Screen. Tap/click opens the list; drag triggers reorder.

- [ ] **Onboarding trigger logic** — currently Help popup is accessible only via Settings; decide when to auto-show (e.g. first launch only). *Skip for now.*

- [ ] **Sub-bullets** — *Skip for now.*
