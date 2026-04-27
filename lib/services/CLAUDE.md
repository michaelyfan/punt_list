# lib/services

Thin wrappers over Firebase. No business logic — that lives in `AppState`.

## Firestore layout

All paths are scoped under `users/{userId}`:

- `users/{userId}` — preferences doc (`themePreference`, `listOrder`)
- `users/{userId}/lists/{listId}` — list metadata (`name`, `destinationListId`,
  timestamps)
- `users/{userId}/lists/{listId}/items/{itemId}` — items (`text`, `isChecked`,
  `parentId`, `sortOrder`, timestamps)

Items are loaded with `orderBy('sortOrder')`. `sortOrder` is a `double`
assigned by index at write time — there is no fractional-rebalance scheme;
every reorder rewrites the affected items.

## ID generation

`FirestoreService.generateId()` uses `_db.collection('_').doc().id` so IDs are
real Firestore auto-IDs and work offline. `AppState` falls back to
microsecond-timestamp IDs only when no service is attached (tests).

## Write methods, by use case

- `updateItem` — single field change, order unchanged (text edit, single toggle)
- `batchUpdateItems` — same, multiple items (parent toggle cascade)
- `deleteItems` — explicit deletes; never inferred from `syncListItems`
- `syncListItems` — rewrites every item's full doc + sortOrder (reorder, indent,
  promote, add, split). Does NOT delete; pair with `deleteItems` if needed.
- `puntItems` — atomic delete-from-source + full-write-destination, single batch

If you add a mutator that changes order, use `syncListItems`; if it only
changes fields on existing items, prefer the surgical methods.

## Timestamps

Every write stamps `updatedAt` with `FieldValue.serverTimestamp()`. `createdAt`
is set only on first creation (`saveList`, `syncListItems(isNew: true)` for
restore-after-undo).

## No real-time listeners

v1 reads once on init via `getAllLists` / `getItems`. Cross-device sync happens
on next launch through Firestore's disk cache. Adding listeners is a deferred
TODO — if you do it, beware of double-applying local optimistic mutations.
