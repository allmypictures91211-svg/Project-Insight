# Play Store Release Guide — Project Insight

## App Details

| Field | Value |
|---|---|
| Package ID | `app.insighteditor` |
| App Name | Project Insight |
| Min SDK | 26 (Android 8.0 Oreo) |
| Target SDK | 36 |
| Compile SDK | 36 |
| AGP | 8.9.3 |
| Kotlin | 2.1.21 |
| Gradle | 9.5.1 |
| NDK | 27.2.12479018 |
| ABI splits | `arm64-v8a`, `x86_64` + universal APK |

---

## 1. Generate a Release Keystore

Run once and store the keystore securely (never commit it):

```bash
keytool -genkey -v \
  -keystore insight-editor-release.jks \
  -alias insight-editor \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=Insight Editor, OU=Mobile, O=YourCompany, L=City, ST=State, C=US"
```

---

## 2. Configure Signing in build.gradle

Add to `android/app/build.gradle` inside the `android {}` block:

```groovy
signingConfigs {
    release {
        storeFile     file(System.getenv("KEYSTORE_PATH") ?: "insight-editor-release.jks")
        storePassword System.getenv("KEYSTORE_PASSWORD") ?: ""
        keyAlias      System.getenv("KEY_ALIAS")         ?: "insight-editor"
        keyPassword   System.getenv("KEY_PASSWORD")      ?: ""
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
        // ... existing minify/proguard config
    }
}
```

Set CI/CD variables in **GitLab → Settings → CI/CD → Variables** (masked + protected):

| Variable | Description |
|---|---|
| `KEYSTORE_BASE64` | Base64-encoded `.jks` file: `base64 -w0 insight-editor-release.jks` |
| `KEYSTORE_PASSWORD` | Keystore store password |
| `KEY_ALIAS` | Key alias (e.g. `insight-editor`) |
| `KEY_PASSWORD` | Key password |

The CI pipeline decodes `KEYSTORE_BASE64` to a temp file and passes the path
via `RELEASE_STORE_FILE`. See `.gitlab-ci.yml` `release_apk` job for details.

---

## 3. Build Release AAB (recommended for Play Store)

```bash
cd android
./gradlew bundleRelease
# Output: app/build/outputs/bundle/release/app-release.aab
```

## 4. Build Release APK (for direct distribution)

### Via environment variables (recommended for local builds)

```bash
cd android
export KEYSTORE_PATH="/path/to/release.keystore"
export KEYSTORE_PASSWORD="your-store-password"
export KEY_ALIAS="release_alias"
export KEY_PASSWORD="your-key-password"
./gradlew clean assembleRelease
# Output: app/build/outputs/apk/release/app-release.apk
```

### Via Gradle `-P` flags (alternative)

```bash
cd android
./gradlew clean assembleRelease \
  -Pandroid.injected.signing.store.file=/path/to/release.keystore \
  -Pandroid.injected.signing.store.password=your-store-password \
  -Pandroid.injected.signing.key.alias=release_alias \
  -Pandroid.injected.signing.key.password=your-key-password
```

### Verify the signed APK

```bash
$ANDROID_HOME/build-tools/36.0.0/apksigner verify --verbose --print-certs \
  app/build/outputs/apk/release/app-release.apk
```

The output should show `Verified using v2 scheme (Android APK Signature Scheme v2): true` and the certificate DN matching your keystore.

### ProGuard mapping file

The mapping file for crash symbolication is written to:
```
app/build/outputs/mapping/release/mapping.txt
```
Upload this to your crash reporting tool (Firebase Crashlytics, Sentry, etc.) after each release build. Without it, stack traces in production will be obfuscated.

---

## 5. Play Store Listing Requirements

### Store Listing
- **Title**: Insight Editor — Pro Video Editor
- **Short description** (80 chars): Professional video editor with color grading, effects & AI tools
- **Full description**: See `STORE_DESCRIPTION.txt`
- **Category**: Video Players & Editors
- **Content rating**: Everyone

### Required Assets
| Asset | Size |
|---|---|
| App icon | 512×512 PNG |
| Feature graphic | 1024×500 PNG |
| Phone screenshots | Min 2, max 8 (16:9 or 9:16) |
| Tablet screenshots | Recommended 7" and 10" |

### Privacy Policy
Required URL — host a privacy policy before submission.

---

## 6. Permissions Justification (Play Store declaration)

| Permission | Justification |
|---|---|
| `READ_MEDIA_VIDEO` | Import video files into projects |
| `READ_MEDIA_AUDIO` | Import audio tracks |
| `READ_MEDIA_IMAGES` | Import still images |
| `FOREGROUND_SERVICE` | Long-running video export jobs |
| `WAKE_LOCK` | Prevent sleep during export |
| `CAMERA` | Optional: record video directly |
| `RECORD_AUDIO` | Optional: record voiceover |

---

## 7. Pre-launch Checklist

### Build
- [ ] Keystore generated and backed up securely (offline + cloud)
- [ ] GitLab CI/CD variables set: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
- [ ] Git tag pushed matching `v*.*.*` to trigger `release_apk` CI job
- [ ] Release AAB / APK builds without errors or warnings
- [ ] APK signature verified with `apksigner` (v2/v3 scheme confirmed)
- [ ] ProGuard mapping file uploaded to crash reporter (`app/build/outputs/mapping/release/mapping.txt`)
- [ ] Native debug symbols uploaded to Play Console (`app/build/outputs/native-debug-symbols/`)

### Testing
- [ ] App tested on physical arm64 device (API 26 minimum)
- [ ] App tested on API 34+ device (notification permission flow)
- [ ] Export pipeline tested end-to-end (WorkManager → MediaMuxer → MediaStore)
- [ ] TalkBack accessibility pass on main screens
- [ ] No cleartext HTTP traffic (verify with Network Security Config)

### Play Store listing
- [ ] App name: "Project Insight"
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] Privacy policy URL live and accessible
- [ ] App icon 512×512 PNG (no alpha)
- [ ] Feature graphic 1024×500 PNG
- [ ] Minimum 2 phone screenshots (16:9 or 9:16)
- [ ] Content rating questionnaire completed (target: Everyone)
- [ ] Data safety form completed (declares media access, no data shared)
- [ ] Target API level ≥ 35 (required for new apps submitted after Aug 2025)
- [ ] `versionCode` is higher than any previously submitted build
- [ ] `versionName` matches the git tag (e.g. `v1.0.0` → `1.0.0`)

---

## 8. NDK / FFmpeg Note

The C++ engine (`insight_engine`) is compiled via CMake with the Android NDK.
To add FFmpeg hardware-accelerated encode/decode:

1. Add [ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit) AAR to `app/libs/`
2. Add to `build.gradle`: `implementation files('libs/ffmpeg-kit-full-6.0.aar')`
3. Link in `CMakeLists.txt`: `target_link_libraries(insight_engine ffmpegkit)`

The current build uses Android's native `MediaCodec` + `MediaMuxer` for
hardware-accelerated H.264/H.265/AV1 encode — no FFmpeg dependency required
for standard formats.
