# Plan: Error feedback for failed Firestore writes

## Context

Per the "Deferred" section of `CLAUDE.md`: today every mutation in `AppState` calls `_firestore?.<method>(...)` without awaiting and without a `.catchError`. If Firestore permanently rejects a write (e.g. security-rule denial, malformed data, expired test-mode rules — which is exactly the failure mode the team just hit and wants to avoid silently next time), the local optimistic state will diverge from the server with no signal to the user. This change adds a single user-facing channel so failures surface as a snackbar, without changing the optimistic-write architecture.

Note on offline behavior: with offline persistence enabled, `batch.commit()` futures only resolve once the server acknowledges. Awaiting them inline would hang while offline. The design below keeps writes fire-and-forget and only reacts to real, terminal failures via `.catchError`.

## Approach

1. **Add an error callback to `AppState`.**
   - In `lib/state/app_state.dart`, add a field `void Function(Object error)? onError;` (public, mutable so `main.dart` can wire it after construction).
   - Add a private helper `void _report(Future<void>? f) { f?.catchError((e) { onError?.call(e); }); }`.
   - Replace every `_firestore?.<method>(...)` call site (lines 72, 90–93, 117–121, 126, 133, 144–151, 161, 171, 215, 274, 304, 343, 351, 381, 396, 408, 444, 454, 485, 510, 522) with `_report(_firestore?.<method>(...))`. Mechanical edit; no behavior change for the success path.

2. **Wire a global ScaffoldMessenger from `lib/main.dart`.**
   - Add a `final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey();` to `_PuntAppState`.
   - Pass `scaffoldMessengerKey: _messengerKey` to `MaterialApp`.
   - In `_initForUser`, after constructing the new `AppState()`, set `_appState.onError = (e) { _messengerKey.currentState?.showSnackBar(SnackBar(content: Text('Couldn\'t save changes. Check your connection.'))); };`. Generic message — Firestore errors aren't user-actionable beyond "retry / check connection", and we don't want to leak rule details.
   - Optional debounce: add a `DateTime? _lastErrorAt;` guard so we don't spam the snackbar when many writes fail in quick succession (e.g. ≥3s gap between snackbars).

3. **No changes** to `firestore_service.dart` — it already returns `Future<void>` from every write; the futures simply weren't being observed.

## Critical files

- `lib/state/app_state.dart` — add `onError`, `_report`, wrap all `_firestore?.` write calls.
- `lib/main.dart` — add `scaffoldMessengerKey`, set `onError` in `_initForUser`.

## Reuse

- `ScaffoldMessenger` snackbar pattern already used in `lib/screens/list_view_screen.dart:54–105` (delete-undo). Same API, different key.
- `FirestoreService` write methods already return `Future<void>` — no signature changes needed.

## Out of scope

- Per-action error UI (e.g. "couldn't delete item X"). The fire-and-forget architecture has lost the call-site context by the time the future fails; a generic banner is the right granularity for v1.
- Retry / undo on failure. The optimistic local change stays applied; user can retry the action manually.
- Test coverage for failure paths. The existing widget tests don't exercise Firestore (per `CLAUDE.md` testing notes), and `AppState.onError` is just a callback — no new logic worth a unit test.

## Verification

1. `flutter analyze` — must pass clean.
2. `flutter test` — existing widget suite must still pass (no behavior change in success path; tests don't exercise Firestore).
3. Manual: `flutter run -d chrome`. Force a failure by temporarily editing `firestore.rules` to deny writes (or by disabling network in DevTools and waiting — note offline writes queue, so prefer the rule-deny path). Add an item; confirm the snackbar appears. Restore rules.
