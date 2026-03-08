# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PuntList is a mobile list app where items can be moved between lists with one tap, in addition to standard check-off behavior.

## App Concept

- Users create multiple named lists
- Each list item has a **checkbox** (check off) and a **move arrow →** (send to another list instantly)
- Move destinations are configured per-list in a Move Settings screen
- Checked items are crossed out and sorted to the bottom

## Screen Flow

See `Screenshot 2026-03-07 at 11.40.37 PM.png` for the whiteboard wireframe.

**App Launch:** Tap app → Loading screen → Lists screen

Screens:
1. **Lists Screen** — shows all lists, gear icon → Move Settings, + → new list
2. **List View** — items with checkbox + move arrow, title tap → rename dialog, text input to add items
3. **Title Edit Dialog** — rename a list inline
4. **Move Settings** — configure destination list for each source list's move arrow
5. **Popup/Explainer** — onboarding for the move feature

**Screen details:**
- Lists Screen: title "Lists", gear icon top-right; empty state shows "Tap '+' to make a list"
- List View: back arrow (←); item row = checkbox (left) | text (middle) | move arrow → (right); active items at top, checked/crossed-out at bottom, text input at bottom
- Move Settings: source lists (including an "Unowned" category) each map to one destination list
- Popup/Explainer: triggered by hamburger/info icon *inside* Move Settings

**Key Interactions:**

| Action | Result |
|--------|--------|
| Tap checkbox | Checks off item; crosses it out and moves to bottom |
| Tap move arrow (→) on item | Instantly moves item to configured destination list |
| Tap list title | Opens title edit dialog |
| Tap + on Lists screen | Creates and opens a new list |
| Tap gear on Lists screen | Opens Move Settings |
| Configure Move Settings | Sets destination list for each source list's move arrow |
