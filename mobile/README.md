# Apex Resolve for Android

The Android application uses Flutter and connects to the same production accounts, communities, tickets and evidence as the website. Its application ID is `com.apexresolve.app`.

The home screen, searchable directories and Android chat are Flutter screens. Open an accepted DM or community in its directory to read and send text with the Nexconn Flutter SDK. The conversation menu opens the complete workspace thread. The workspace thread also has replies, issue conversion and workflow cards. Issue editing, evidence upload, review, AI tools and community administration use the first-party workspace in an Android WebView. These features require internet access.

## Build

Use Flutter 3.50.1, JDK 21 and the Android SDK configured for Flutter. Run the following in the mobile directory.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

For release builds, set `APEX_ANDROID_SIGNING_PROPERTIES` to a private properties file containing `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. On this Mac the default location is `~/.android/apex-resolve-signing/signing.properties`. Back up the keystore and properties together in secure storage. Installable APKs are generated under `build/app/outputs/flutter-apk/`.

## Firebase

Download the Android client configuration for `com.apexresolve.app` from Firebase project `apex-resolve` and place it at `android/app/google-services.json` before building. Gradle generates the native Firebase resources from this ignored file.

Register the release certificate fingerprints for Android Google authentication, enable the appropriate sign-in providers, then rebuild. The Android client exchanges its verified Firebase ID token at the existing first-party authentication endpoint. Nexconn tokens are requested for individual authorized conversations. Service credentials and signing files belong outside version control.
