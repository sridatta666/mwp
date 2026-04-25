# Packaging MWP for Android and iOS

This guide covers building release artifacts for the **MWP** Flutter app on Android and iOS.

---

## Android

### Build outputs (already generated)

After running the commands below, artifacts are here:

| Artifact | Path | Use |
|----------|------|-----|
| **APK** (direct install) | `build/app/outputs/flutter-apk/app-release.apk` | Sideload, testing, or stores that accept APK |
| **App Bundle** (Play Store) | `build/app/outputs/bundle/release/app-release.aab` | **Google Play Store** (preferred) |

### Commands

```bash
# Release APK (single file, all ABIs)
flutter build apk --release

# Release App Bundle for Play Store (smaller downloads per device)
flutter build appbundle --release
```

### Release signing (for Play Store)

The project currently uses **debug signing** for release builds. For production:

1. **Create a keystore** (once):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Add `android/key.properties`** (do not commit to git):

   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

3. **Configure signing in `android/app/build.gradle.kts`**:

   - Load `key.properties` in the `android { }` block.
   - In `buildTypes { release { } }`, set `signingConfig` to use the keystore (see [Flutter docs: Android signing](https://docs.flutter.dev/deployment/android#signing-the-app)).

4. Add `key.properties` and `*.jks` to `.gitignore`.

Then run `flutter build appbundle --release` again; the AAB will be signed with your key.

### Application ID

- Current ID: `com.example.mwp` (in `android/app/build.gradle.kts`).
- For a real app, change this to your own package name (e.g. `com.yourcompany.mwp`) before publishing.

---

## iOS

iOS builds require **macOS** and **Xcode**. They cannot be produced on Windows.

### Prerequisites (on Mac)

- Xcode (from App Store).
- CocoaPods: `sudo gem install cocoapods`.
- Apple Developer account (for device testing and App Store).
- In Xcode: open `ios/Runner.xcworkspace` (not `.xcodeproj`), select the Runner target, set **Team** and **Bundle Identifier** (e.g. `com.yourcompany.mwp`).

### Build commands (on Mac)

```bash
# Build iOS release (creates Runner.app)
flutter build ios --release

# Build IPA for App Store / TestFlight (requires signing)
flutter build ipa
```

- **`flutter build ios`**: Produces a release build; you can run on device or archive in Xcode.
- **`flutter build ipa`**: Produces an `.ipa` in `build/ios/ipa/` for upload to App Store Connect (after configuring signing in Xcode).

### First-time iOS setup on Mac

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select **Runner** target → **Signing & Capabilities**.
3. Choose your **Team** and set a unique **Bundle Identifier**.
4. For App Store: create an app in [App Store Connect](https://appstoreconnect.apple.com) and use the same bundle ID.

---

## Version and build number

Controlled in `pubspec.yaml`:

```yaml
version: 1.0.0+1   # 1.0.0 = version name, 1 = build number
```

Override when building:

```bash
flutter build apk --release --build-name=1.0.1 --build-number=2
flutter build appbundle --release --build-name=1.0.1 --build-number=2
flutter build ios --release --build-name=1.0.1 --build-number=2
```

---

## Summary

| Platform | Artifact | Command | Where |
|----------|----------|---------|--------|
| Android | APK | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android | App Bundle | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` |
| iOS | IPA | `flutter build ipa` (on Mac) | `build/ios/ipa/` |

- **Android**: Built on this machine; APK and AAB are ready. Configure release signing and application ID before publishing.
- **iOS**: Build on a Mac with Xcode; configure signing and bundle ID, then run `flutter build ios` or `flutter build ipa`.
