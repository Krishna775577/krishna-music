KRISHNA MUSIC — CONSOLIDATED AUDIT / BUILD NOTES (2026-11-21)

SCOPE AND HONEST STATUS
Original user-uploaded BlackHole app files were inventoried and combined with
all locally available earlier patches. This is a STATIC CODE audit; no Android
SDK, Flutter SDK or live phone streaming test is available in this environment.
A successful GitHub Actions build and manual device tests are still REQUIRED.
This package does NOT guarantee that YouTube will allow embedded playback or
that undocumented music streaming endpoints will remain available.

CURRENT ERROR FROM GITHUB SCREENSHOT
  Project ':receive_sharing_intent' uses Kotlin Gradle plugin 1.4.31.
  Android Gradle Plugin 7.4.2 requires >=1.5.20.
  Fix: pin receive_sharing_intent at 1.5.4, which updated Android build tooling
  and keeps the pre-1.6 static sharing API used by this project. The current
  version constraint ^1.4.5 plus an old lock kept older Kotlin build tooling.

CONSOLIDATED FIXES INCLUDED
  * Android root build.gradle corrected (AGP 7.4.2, Kotlin 1.8.22)
  * Android app build.gradle with compileSdk 34; min/target SDK preserved
  * Gradle wrapper 7.6.1 (Java 11 workflow)
  * 4.0.4 embedded YouTube iframe player (for Dart 3.3)
  * YouTube + YtMusic navigation via embedded video (not extracted audio-only)
  * Prior search, YouTube home, Saavn error state and miniplayer layout fixes
  * Latest player queue and audio-source error guards from available patches
  * Removed stale home_screen.fetched reference from settings
  * Exact pin of receive_sharing_intent: 1.5.4
  * Original author notices and LICENSE retained

IMPORTANT: THE EMBEDDED PLAYER
YouTube iframe can play videos where embedding is supported. It is not a legal
or technical replacement for separate background audio-only streaming,
YouTube Music Premium, or unrestricted YouTube content. A video may be blocked
or unavailable regardless of app code. Saavn web API is unofficial, too.

TO USE THE PATCH ZIP IN EXISTING krishna-music REPOSITORY
  1. Delete the OLD krishna-music-source-ready.zip from repo root; commit.
  2. Upload the NEW krishna-music-source-ready.zip in repo root; commit.
  3. Actions -> Import ZIP and Build Android APK -> Run workflow (fresh run).
  4. Confirm "Import optional ZIP" step prints "Found ZIP overlay".
  5. "Get Dart packages" should resolve receive_sharing_intent 1.5.4.
  6. A green build artifact is necessary before installing new APK.

FULL SOURCE ZIP
If creating a new repository, upload the EXTRACTED CONTENTS of
Krishna-Music-Consolidated-Full-Source.zip to the repo root. Uploading the ZIP
without extracting will not make GitHub Actions see the Flutter project.

LIMITATIONS TO TEST IN A REAL APK
  - Saavn first-try playback; seek/pause/resume/next and notifications
  - YouTube search, iframe playback, embed-restricted videos and fallback
  - YtMusic search, player routing, empty/error states, retry/timeouts
  - Home, navigation, permissions, downloads, locale, sharing, app restart
  - Profile/release performance on physical Android hardware
  - Full flutter pub get, flutter analyze, Gradle compile and runtime logging

This code is derived from BlackHole, with original source license retained.
