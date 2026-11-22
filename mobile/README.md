<div align="center">

# 📱 Apex Resolve Mobile (iOS & Android)

### *Cross-Platform Native Mobile Client for Issue Resolution & Real-Time Collaboration*

[![Flutter 3.50+](https://img.shields.io/badge/Flutter-3.50.1-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Android Physical Devices](https://img.shields.io/badge/Android-Physical_Phones_%26_Tablets-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://apex-resolve-one.vercel.app/submission/apex-resolve-android.apk)
[![Apple iOS Physical Devices](https://img.shields.io/badge/Apple_iOS-Physical_iPhones_%26_iPads-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Nexconn SDK](https://img.shields.io/badge/Nexconn-Flutter_Plugin-6366F1?style=for-the-badge)](https://nexconn.ai)
[![Tests Passing](https://img.shields.io/badge/Tests-12%2F12_Passed-22C55E?style=for-the-badge&logo=checkmarx&logoColor=white)](test/widget_test.dart)

<br/>

**Apex Resolve Mobile** is a 100% native Flutter client built for physical **Android phones/tablets** and physical **Apple iPhones/iPads**. It connects directly to the production backend, Supabase PostgreSQL, Firebase Auth, and the Nexconn Real-Time Messaging network.

---

</div>

## 📑 Contents

- [✨ 100% Native Architecture (Zero Embedded WebViews)](#-100-native-architecture-zero-embedded-webviews)
- [📲 Physical Device Deployment](#-physical-device-deployment)
  - [Apple iOS (Physical iPhones & iPads)](#1-apple-ios-physical-iphones--ipads)
  - [Google Android (Physical Phones & Signed Release APK)](#2-google-android-physical-phones--signed-release-apk)
- [🔒 Native Platform Session Bridge](#-native-platform-session-bridge)
- [💬 Nexconn Chat Experience & Customization](#-nexconn-chat-experience--customization)
- [🧪 Automated Test Suite & Layout Verification](#-automated-test-suite--layout-verification)

---

## ✨ 100% Native Architecture (Zero Embedded WebViews)

Every user journey is rendered natively with high-performance Flutter widgets:

- **Intelligent Workspace Copilot ([lib/apex_ai_screen.dart](lib/apex_ai_screen.dart)):** Native AI assistant powered by OpenRouter and Gemini with full Markdown rendering, code syntax highlighting, copy-to-clipboard, and diagnostic suggestions.
- **People Discovery & Security PIN ([lib/user_discovery.dart](lib/user_discovery.dart)):** Live user search by display name or `@handle`, 4-digit PIN unlock modal, contact requests, and direct chat launching.
- **Profile Studio ([lib/profile_screen.dart](lib/profile_screen.dart)):** Real camera capture and photo library picker, avatar upload to Supabase storage, display name, handle preview, bio editor, and workspace memberships.
- **4-Stage Resolution Stepper & ProofGuard ([lib/resolution_screens.dart](lib/resolution_screens.dart)):**
  - Visual progress stepper (`Reported` → `In Progress` → `Review` → `Verified`).
  - Interactive task checklist.
  - Evidence vault supporting notes, URLs, logs, and uploaded media attachments.
  - Independent review gate mathematically enforcing separation of duties (preventing resolvers from self-approving).
- **Workspace Administration ([lib/workspace_management.dart](lib/workspace_management.dart)):** Organizations and community groups overview, community creation dialogs, and member role administration.
- **Explorer Cockpit ([lib/home.dart](lib/home.dart)):** Real-time metric counters, quick actions, copilot banner, and resolution shortcuts.

---

## 📲 Physical Device Deployment

### 1. Apple iOS (Physical iPhones & iPads)

The iOS target (`ios/Runner.xcworkspace`) is a fully native application designed to run on physical Apple hardware (iPhone 11 through iPhone 16 Pro Max, and iPadOS devices), with optional support for the Xcode Simulator during rapid prototyping.

#### Running on a Physical iPhone:
1. Connect your physical iPhone to your Mac via USB or Wi-Fi.
2. Ensure **Developer Mode** is enabled on your iPhone (*Settings → Privacy & Security → Developer Mode*).
3. Open the workspace in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
4. Select your **Apple Development Team** in the *Runner → Signing & Capabilities* tab to generate an automatic provisioning profile.
5. In your terminal, check the connected iPhone device ID:
   ```bash
   flutter devices
   ```
6. Run the app directly onto your physical iPhone:
   ```bash
   flutter run -d <your-iphone-device-id>
   ```

#### Building an iOS Archive / IPA for TestFlight or Ad-Hoc Distribution:
```bash
flutter build ipa --release
```

---

### 2. Google Android (Physical Phones & Signed Release APK)

The Android target (`android/`) compiles for `arm64-v8a`, `armeabi-v7a`, and `x86_64` Android hardware running Android 8.0 (API Level 26) through Android 15 (API Level 35).

#### Installing on a Connected Android Phone:
1. Enable **USB Debugging** on your phone (*Settings → Developer Options → USB Debugging*).
2. Connect your device via USB.
3. Install and run directly:
   ```bash
   flutter run -d <your-android-device-id>
   ```

#### Compiling the Signed Production Release APK:
```bash
# Set Java and Android SDK paths
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export ANDROID_HOME="$HOME/Library/Android/sdk"

# Build optimized ARM64 release APK
flutter build apk --release --target-platform android-arm64
```

#### Verifying Release Signature:
```bash
$ANDROID_HOME/build-tools/36.0.0/apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔒 Native Platform Session Bridge

To guarantee maximum security without embedding sensitive API keys or database service secrets into client binaries:

```
┌────────────────────────────────────────────────────────┐
│               Flutter Native UI Layer                  │
└──────────────────────────┬─────────────────────────────┘
                           │ MethodChannel('apex/session')
              ┌────────────┴────────────┐
              ▼                         ▼
   ┌───────────────────────┐ ┌───────────────────────┐
   │ Android MainActivity  │ │   iOS AppDelegate     │
   │  CookieManager Bridge │ │ WKWebsiteDataStore    │
   └──────────┬────────────┘ └──────────┬────────────┘
              │                         │
              └────────────┬────────────┘
                           ▼
     ┌───────────────────────────────────────────┐
     │ Next.js Edge Gateway (/api/mobile/*)      │
     │  - Authenticated via sb-*-auth-token      │
     │  - Calls PostgreSQL RPCs with RLS         │
     └───────────────────────────────────────────┘
```

- **Android:** [`MainActivity.kt`](android/app/src/main/kotlin/com/apexresolve/app/MainActivity.kt) extracts active cookies via `android.webkit.CookieManager` and forwards authenticated HTTP requests.
- **iOS:** [`AppDelegate.swift`](ios/Runner/AppDelegate.swift) extracts active session cookies via `WKWebsiteDataStore.default().httpCookieStore` and passes them in HTTP request headers.

---

## 💬 Nexconn Chat Experience & Customization

The native messaging engine in [`lib/native_chat.dart`](lib/native_chat.dart) delivers:

- **Smart Message Bubbles:** Outgoing messages styled with coral-to-rose gradients, incoming messages styled with sleek elevated surface cards.
- **In-Chat Quoted Replies:** Quoted message preview cards displayed seamlessly in the chat timeline.
- **Live Reactions:** 10 one-tap emoji reactions (`👍`, `❤️`, `🔥`, `🎉`, `🚀`, `👏`, `💡`, `⚠️`, `👀`, `✅`) with real-time counters.
- **Attachment Studio:** Upload camera photos, gallery media, screen recordings, and documents (`PDF`, `DOCX`, `TXT`, `ZIP`, `CSV`).
- **Starter Sticker Packs:** 22+ curated stickers across *Engineering*, *Team Vibes*, and *Status*.
- **Live Group Roster:** Tapping the chat header opens real-time member rosters, role badges (`Owner`, `Admin`, `Member`), direct invite actions, and issue creation.
- **Theme & Wallpaper Personalization:** 4 chat backgrounds (*Aurora Glow*, *Midnight Space*, *Technical Slate*, and *Warm Paper*) persisted in memory and settings.

---

## 🧪 Automated Test Suite & Layout Verification

The test suite in [`test/widget_test.dart`](test/widget_test.dart) validates both functionality and responsive ergonomics across varied device dimensions:

```bash
flutter analyze
flutter test
```

### Verified Test Cases (12/12 Passing):
1. `home exposes conversations and resolution workflows`
2. `signed out opens native sign-in and account creation asks for a username`
3. `sign-up rejects a username with symbols`
4. `only official workspace conversation URLs can request a native session`
5. `Apex AI screen renders native interface and sends message`
6. `User discovery screen displays member search and actions`
7. `Profile screen displays editable profile attributes`
8. `Resolution detail screen renders progress stepper, tasks and evidence`
9. `Workspace management screen displays environments and create action`
10. `Responsive small width (360dp) renders Home without overflow`
11. `Responsive standard width (390dp) renders ResolutionDetailScreen without overflow`
12. `Starter stickers list is populated and categorised`
