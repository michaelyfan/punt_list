# PROGRESS.md

Tracks TODOs and implementation notes for PuntList.

## Bugs

- [ ] Delete list is bugged

## Deferred Infrastructure

- [ ] **Data persistence** — no local storage or database yet; all state is in-memory and lost on app restart
- [ ] **Authentication** — no user accounts or auth; implement later

## Deferred Features

- [ ] **Onboarding trigger logic** — currently Help popup is accessible only via Settings; decide when to auto-show (e.g. first launch only). *Skip for now.*

- [ ] **Sub-bullets** — See implementation notes below.
  - [ ] **Sub-item move (→) behavior** — Sub-items currently cannot be moved via the → button. Decision needed: should tapping → on a sub-item move just that item (orphaning it from parent), move the parent+whole sublist, or be disabled entirely? Disabled for now.
