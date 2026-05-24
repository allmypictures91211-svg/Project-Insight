# AGENTS.md

8K video editor — TanStack Start (SSR) + React 19 + Vite 7 web app wrapped with Capacitor for Android/iOS. A parallel native Kotlin/Compose Android app with a C++ processing engine lives in `android/`.

## Setup

```bash
npm install        # CI uses npm; bun also works (bun.lockb present)
```

Requirements for native builds: Node 22+, JDK 21, Android SDK (compileSdk 36, NDK 27.2.12479018).

## Dev Server

```bash
npm run dev        # Vite dev server (web only)
```

## Build

```bash
npm run build              # Web bundle → dist/client/ (Capacitor) + dist/server/ (Cloudflare Workers)
npm run build:dev          # Same, development mode
npm run preview            # Preview production build locally

# After web build, sync to native projects:
npm run cap:sync           # runs `bun run build && cap sync`
```

### Android APK

```bash
cd android
./gradlew assembleDebug    # debug APK → android/app/build/outputs/apk/debug/
./gradlew assembleRelease  # release APK (requires signing config)
```

## Tests

### Android unit tests

```bash
cd android && ./gradlew test
```

### Android instrumented tests

```bash
cd android && ./gradlew connectedAndroidTest   # requires connected device or emulator
```

> No web test framework is configured (no Vitest/Jest/Playwright).

## Lint & Format

Run both before committing:

```bash
npm run lint       # ESLint (TypeScript, React hooks, Prettier integration)
npm run format     # Prettier — writes in place
```

ESLint config: `eslint.config.js`. Prettier is integrated via `eslint-plugin-prettier`; no separate `.prettierrc` needed.

## CI (GitLab)

Defined in `.gitlab-ci.yml`. Two stages:

| Stage | Job | Trigger |
|---|---|---|
| `build` | `build_apk` — debug APK | every push |
| `release` | `release_apk` — signed release APK | tags matching `v*.*.*` |

CI uses `npm install` (not bun). The build pipeline:
1. `npm install`
2. `npm run build`
3. Pre-render `index.html` via the SSR server bundle (required for Capacitor — hydrateRoot needs server-rendered HTML with `$_TSR` bootstrap)
4. `npx cap sync android`
5. `./gradlew assembleDebug` / `assembleRelease`

**Required CI/CD variables for release builds** (masked, protected):
- `KEYSTORE_BASE64` — base64-encoded `.jks` keystore
- `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`

## Key Directories

```
src/
  routes/           # TanStack Router file-based routes (__root.tsx, index.tsx)
  components/
    editor/         # Video editor UI (Timeline, Viewer, Inspector, MediaPool, etc.)
    ui/             # Shared shadcn/ui primitives
  hooks/            # React hooks
  integrations/     # Supabase client + generated types
  lib/              # Utilities (cn, etc.)
  assets/           # Static assets bundled by Vite

android/
  app/src/main/
    java/app/insighteditor/   # Kotlin/Compose native app
    cpp/                      # C++17 native engine (insight_engine.so)
      engine/                 # Core processing
      effects/                # Color grading, GLSL shaders
      audio/                  # AAudio integration
      timeline/               # Timeline logic
      jni_bridge.cpp          # JNI bridge to Kotlin

supabase/           # Supabase config (schema currently empty)
public/             # Static public assets
dist/               # Build output (gitignored)
  client/           # Web bundle served by Capacitor WebView
  server/           # Cloudflare Workers SSR handler
```

## Known Issues

- **App ID mismatch**: `capacitor.config.ts` uses `app.lovable.ultimatefilmforge`; `android/app/build.gradle` uses `app.insighteditor`.
- **Dual lockfiles**: `bun.lockb` and `package-lock.json` both present. CI uses `npm`.
- **Supabase schema is empty**: `src/integrations/supabase/types.ts` has no tables yet.
- **No web tests**: Adding Vitest would require setup from scratch.
