# PuntList

A list app that lets you move items between lists with one tap. Built with Flutter and Firebase.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) installed
- Firebase config files (gitignored, required for build):
  - `lib/firebase_options.dart`
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
  - `macos/Runner/GoogleService-Info.plist`

  Generate these by running `flutterfire configure` with access to the Firebase project.

## Running

```bash
flutter run -d chrome
```

## Tests

Widget tests cover core user flows — creating lists, adding/checking/punting items, swipe gestures (indent/promote), inline editing, settings, and parent-child cascading behavior. Tests render real widgets and simulate taps, drags, and text input without requiring Firebase.

```bash
flutter test                                    # run all tests
flutter test test/screens/                      # run all screen tests
flutter test test/widgets/item_tile_test.dart   # run a single test file
```
