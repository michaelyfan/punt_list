# Open Questions

## Inconsistencies Between CLAUDE.md and Screenshots

### Move arrow missing from item rows (major)
CLAUDE.md describes `checkbox | text | move arrow →` per item, but every item in the screenshots shows `checkbox | text | trash icon`. No move arrow exists in the List View designs. This is the app's core differentiator — needs resolution before implementation.

### "Unowned" category not in Move Settings
CLAUDE.md mentions an "Unowned" category in Move Settings, but the screenshot shows all lists flat with no grouping. Is this a planned feature not yet designed?

### Info icon is `(?)`, not hamburger
CLAUDE.md says "hamburger/info icon" triggers the Popup/Explainer. Screenshot shows a `(?)` circle icon in the top-right of Move Settings.

### + button is a FAB, not a header icon
CLAUDE.md implies `+` is in the header, but it's a floating action button (bottom-right) in the screenshot.

## Undocumented UI in Screenshots

- **List card subtitles**: Each list shows "N active" or "N active, N completed" — not mentioned in CLAUDE.md
- **Delete list**: Trash icon on each list card — no mention of this interaction or any confirmation flow
- **Delete item**: Trash icon on each item row — not mentioned in CLAUDE.md
- **Move Settings info banner**: Blue descriptive text at top of Move Settings screen, not documented
- **Move Settings "— No destination —"**: Default state for unconfigured lists — behavior not specified

## Missing Flows / Edge Cases

1. **Move arrow when no destination set** — should it be hidden, disabled, or grayed out?
2. **Delete list** — confirmation dialog? What happens to items in the list?
3. **Delete item** — confirmation or immediate?
4. **Unchecking a completed item** — does it move back to the top of the list?
5. **Add item UX** — does keyboard dismiss after submit? Does input clear?
6. **Empty/whitespace list name** — validation on save in Rename dialog?
7. **Duplicate list names** — allowed or rejected?
8. **Self-referential move destination** — can a list be configured to move items to itself?
9. **Loading screen** — mentioned in App Launch flow but no screenshot exists
10. **Popup/Explainer content** — no screenshot for this screen
