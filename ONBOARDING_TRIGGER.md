# Plan: Auto-show onboarding help dialog on first launch

## Context

From CLAUDE.md → "Deferred" TODOs: "Onboarding trigger logic — currently help popup is only in Settings; decide when to auto-show". Today `HelpDialog` (`lib/widgets/help_dialog.dart`) is fully built and reachable only via the help icon in Settings (`lib/screens/settings_screen.dart:28-29`). New users who sign up never see it. Goal: auto-show `HelpDialog` exactly once for any user who has never seen it, then never again.

Persistence already has the right hook: `FirestoreService.getUserPreferences` / `saveUserPreferences` (`lib/services/firestore_service.dart:28, 50`). Currently used for `themePreference` and `listOrder`. Adding one more bool key (`onboardingCompleted`) is the natural shape.

## Approach

### 1. Persist a flag in user preferences (`lib/state/app_state.dart`)

- Add field `bool onboardingCompleted = false;` on `AppState`.
- In `init(...)`, after the existing `prefs` read, parse it:
  ```dart
  onboardingCompleted = (prefs?['onboardingCompleted'] as bool?) ?? false;
  ```
- Add a mutator:
  ```dart
  void markOnboardingCompleted() {
    if (onboardingCompleted) return;
    onboardingCompleted = true;
    _firestore?.saveUserPreferences({'onboardingCompleted': true});
  }
  ```
  `saveUserPreferences` already does `SetOptions(merge: true)` (verified at `firestore_service.dart:50-53`), so this won't clobber `themePreference` or `listOrder`.

### 2. Auto-show on first build of `ListsScreen` (`lib/screens/lists_screen.dart`)

`ListsScreen` is the first screen a signed-in user lands on after `AppState.init` completes (`main.dart:69-76`), so it's the right host.

- Convert `ListsScreen` from `StatelessWidget` to `StatefulWidget` (it's currently stateless — minimal blast radius; constructor and `build` body unchanged).
- In `initState`, schedule a post-frame callback that checks `!widget.appState.onboardingCompleted` and, if true, shows the dialog and marks it completed:
  ```dart
  @override
  void initState() {
    super.initState();
    if (!widget.appState.onboardingCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => const HelpDialog(),
        );
        if (!mounted) return;
        widget.update(() => widget.appState.markOnboardingCompleted());
      });
    }
  }
  ```
- Mark completed *after* the dialog closes (any close path: "Got it!", X button, barrier tap) so a force-quit during onboarding still re-shows next launch.
- Add the import: `import '../widgets/help_dialog.dart';`.

### 3. `_PuntAppState._initForUser` interaction

`main.dart` reuses the same `ListsScreen` widget across rebuilds for a given signed-in user, so `initState` only fires once per sign-in session — exactly what we want. On sign-out → sign-in as a different user, `_initForUser` constructs a fresh `AppState` (`main.dart:39-46`); `ListsScreen` remounts because `_appState.isLoading` flips false → AuthGate rebuilds → new instance. Verified by reading the existing flow; no change needed in `main.dart`.

## Critical files

- `lib/state/app_state.dart` — add `onboardingCompleted` field + load in `init` + `markOnboardingCompleted` mutator.
- `lib/screens/lists_screen.dart` — Stateless → Stateful; auto-show on first build.

## Reuse

- `HelpDialog` (`lib/widgets/help_dialog.dart`) — used as-is, no changes.
- `FirestoreService.saveUserPreferences` — already merge-writes; safe to add a new key.
- `appState`/`update` callback pattern — same as every other screen here (`lib/screens/CLAUDE.md`).

## Out of scope

- Multi-step / per-screen onboarding tooltips (e.g. a coach mark on the FAB). Single dialog is the existing affordance; expanding it is a product decision, not this TODO.
- Locally-stored "skip onboarding" for unauthenticated users — onboarding only matters post-sign-in (auth-gated app).
- "Show again" / re-trigger button beyond the existing Settings help icon.

## Verification

1. `flutter analyze` — must pass clean.
2. `flutter test` — existing widget suite must still pass. The `lists_screen_test.dart` cases construct `ListsScreen` via `createTestAppState` (no Firestore), so `onboardingCompleted` defaults to `false`, which means the dialog WILL try to fire in tests. Default `onboardingCompleted = true` in `createTestAppState` (in `test/helpers/test_helpers.dart`) so existing tests aren't disrupted; add one new test that flips it to `false` and asserts the dialog appears.
3. Manual: `flutter run -d chrome`. Sign in with a fresh account (or delete `users/<uid>/preferences/main` in Firebase console). Confirm dialog appears on Lists screen, dismiss it, hot-restart — confirm it does NOT reappear. Sign out and sign in as a different fresh user — confirm it appears for the new user.
4. After completing the work, mark the TODO checked in `CLAUDE.md` ("Onboarding trigger logic") with a short note on the chosen trigger.
