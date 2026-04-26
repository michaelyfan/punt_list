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

### Web (Chrome)

```bash
flutter run -d chrome
```

<<<<<<< Updated upstream
## Tests

Widget tests cover core user flows — creating lists, adding/checking/punting items, swipe gestures (indent/promote), inline editing, settings, and parent-child cascading behavior. Tests render real widgets and simulate taps, drags, and text input without requiring Firebase.

```bash
flutter test                                    # run all tests
flutter test test/screens/                      # run all screen tests
flutter test test/widgets/item_tile_test.dart   # run a single test file
```
=======
### Android

1. Start an Android emulator from Android Studio's Device Manager (or `flutter emulators --launch <id>`), or connect a physical device with USB debugging enabled.
2. Verify the device is detected:
   ```bash
   flutter devices
   ```
3. Run the app:
   ```bash
   flutter run # this will automatically select the mobile device
   # OR
   flutter run -d android # this never works for me, but is supposed to be correct
   # OR
   flutter run -d emulator-1234
   ```

For Google Sign-In to work on Android, register your debug SHA-1 fingerprint with the Firebase project. Get it with:

```bash
cd android && ./gradlew signingReport
```

Or directly from the debug keystore:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA
```

Add the SHA-1 (and SHA-256, if prompted) under Firebase Console → Project Settings → your Android app → Add fingerprint. Then **re-download `google-services.json`** from the Firebase Console and replace `android/app/google-services.json` (or re-run `flutterfire configure`). The file changes after a fingerprint is added — easy to forget.

### Installing on a physical Android device (release build)

#### One-time prerequisites

Before the first release install will work end-to-end, the following must be done in the Firebase Console for project `punt-list`:

- Enable Email/Password and Google sign-in (Authentication → Sign-in method)
- Create the Cloud Firestore database
- Register the debug keystore SHA-1 on the Android app and download the resulting `google-services.json` into `android/app/` *(done — see SHA-1 instructions above)*
- Deploy security rules: `firebase deploy --only firestore:rules`
- Move Firestore out of dev/test mode into production mode
- If a real release keystore is later configured (or the app is published via Play App Signing), register that key's SHA-1 too — currently release builds fall back to the debug key, so the debug SHA-1 is sufficient.

#### Build and install

To install a standalone copy of the app on your phone (no debugger attached), build a release APK and install it:

```bash
flutter build apk --release
flutter install --release -d <device-id>   # device-id from `flutter devices`
```

The app stays on the phone after the install command finishes and works offline like any other app. Notes:

- **Signing key**: with no release keystore configured, `flutter build apk --release` falls back to the debug keystore. That means the debug SHA-1 registered above is sufficient for Google Sign-In to keep working. If you later configure a real release keystore (or publish to Play Store, where Play App Signing rotates the key), add that new SHA-1 to Firebase.
- **Reinstalling**: running `flutter install` again overwrites the existing app. App data is preserved as long as the signing key is unchanged.
- **No hot reload**: a release-installed app runs disconnected from `flutter` tooling — for iterative development use `flutter run` instead.
>>>>>>> Stashed changes
