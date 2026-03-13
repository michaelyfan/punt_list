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

## Behaviors

- Deleting a list clears it as a destination from any other list that referenced it
- New list creation immediately navigates to the new list (default name "New List")

## TODOs

See `context/PROGRESS.md` for the full list of bugs, deferred infrastructure, and deferred features with implementation notes.