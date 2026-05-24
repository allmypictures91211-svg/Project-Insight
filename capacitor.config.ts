import type { CapacitorConfig } from "@capacitor/cli";

/**
 * Capacitor configuration for iOS + Android wrappers.
 *
 * Linux is NOT supported by Capacitor. Linux users install the PWA from
 * the browser ("Install app") — same codebase, no extra build.
 *
 * Build flow:
 *   1. npm run build              # produces the web bundle
 *   2. npx cap sync android       # copies web assets into android/
 *   3. cd android && ./gradlew assembleDebug
 */
const config: CapacitorConfig = {
  appId: "app.insighteditor",
  appName: "Project Insight",
  // TanStack Start SSR build outputs the client bundle to dist/client/.
  // Capacitor copies this directory into the native app at `cap sync`.
  webDir: "dist/client",
  android: {
    allowMixedContent: false,
    backgroundColor: "#0b0b0f",
  },
  ios: {
    contentInset: "always",
    backgroundColor: "#0b0b0f",
  },
  server: {
    androidScheme: "https",
    iosScheme: "https",
  },
};

export default config;
