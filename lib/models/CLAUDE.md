# lib/models

Plain data classes for items and lists, plus Firestore (de)serialization.

## Hierarchy is flat-list, not tree

`PuntList.items` is a single flat `List<PuntItem>`. Sub-items are expressed via
`PuntItem.parentId` (null = root). Order in the flat list is the source of truth
for display order — children must appear directly after their parent and before
the next root item. Reorder/indent/promote logic in `AppState` maintains this
invariant; do not break it.

`DisplayItem` is a render-time wrapper over `PuntItem` produced by
`activeDisplayItems` / `checkedDisplayItems`. It exists so the UI can render
ghost parents (unchecked parent shown in checked section because it has checked
children) without mutating the model. Only one nesting level is supported.

## Serialization shape

`toMap()` / `fromMap()` deliberately exclude `id`, `sortOrder`, `createdAt`, and
`updatedAt` — those are owned by `FirestoreService` (id = Firestore doc id,
sortOrder = list index, timestamps = server time). When adding a model field,
update `toMap`/`fromMap` and remember the field needs a default in `fromMap` for
older docs that predate it.

## Character limit

`PuntList.characterLimit` (20K) and `totalCharacters` live on the model;
enforcement lives in `AppState` mutators that grow text. Keep the constant here
so tests and UI can reference one source of truth.
