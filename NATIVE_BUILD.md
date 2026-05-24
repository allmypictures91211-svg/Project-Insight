# Native Builds (iOS + Android + Linux)

This project is a web app wrapped with **Capacitor** for mobile.
The `gradlew` script, `android/app/build.gradle`, and the iOS Xcode project
are **generated on your machine** by the Capacitor CLI — they cannot be
authored inside Lovable because `gradlew` ships a binary `gradle-wrapper.jar`
and a platform-specific shell launcher.

## One-time setup on your computer

Requirements:
- Node.js 20+ and `npm` or `bun`
- **Android**: Android Studio (Hedgehog or newer) + JDK 17
- **iOS**: macOS + Xcode 15+ + CocoaPods (`sudo gem install cocoapods`)

```bash
git clone <your repo>
cd <repo>
bun install
bun run build           # produces dist/
npx cap add android     # creates android/ folder, gradlew, app/build.gradle
npx cap add ios         # creates ios/ folder, App.xcworkspace
npx cap sync            # copies dist/ into both native projects
```

After this you will have:
```
android/
  gradlew
  gradlew.bat
  app/
    build.gradle        ← Android module config
  build.gradle          ← project-level config
ios/
  App/
    App.xcworkspace
```

## Build the Android APK

```bash
npx cap open android
# In Android Studio: Build → Build Bundle(s)/APK(s) → Build APK(s)
```
Or from the command line:
```bash
cd android
./gradlew assembleRelease
# APK output: android/app/build/outputs/apk/release/app-release.apk
```

## Build the iOS IPA (macOS only)

```bash
npx cap open ios
# In Xcode: Product → Archive → Distribute App
```

## Linux

Capacitor does not target Linux. The app is already a PWA — Linux users
open the published URL in Chrome/Edge and click **Install app** from the
address bar. Same codebase, no extra build.

If you need a true Linux desktop binary later, wrap the PWA with Electron
or Tauri in a separate folder; that is a different project setup.

## Updating the native apps after web changes

```bash
bun run build
npx cap sync
```
Then rebuild from Android Studio / Xcode.
