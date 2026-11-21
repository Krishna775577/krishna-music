# Krishna Music — static code audit and stability baseline

Date: 2026-11-21

## What was actually inspected

- Original uploaded BlackHole source archive (459 files total) and its **117 Dart files** under `lib/`; selected Android and workflow configurations.
- Public repository's main audio pipeline, Saavn API, YtMusic parser, YouTube services, search UI and package manifest.
- Previous patches from this chat, including YouTube home/search/stream URL fixes.
- User screenshots of UI overflow, indefinite loading, intermittent search and playback stuck at `00:00`.

**Not verified:** No Flutter/Dart SDK or Android emulator/phone test runtime was available here. No live JioSaavn or YouTube playback tests were executed. Therefore this package is **not a claim of perfect playback**, nor a fully regression-tested APK.

## Dart inventory scanned

{
  "APIs": 2,
  "CustomWidgets": 31,
  "Helpers": 28,
  "Models": 3,
  "Screens": 38,
  "Services": 9,
  "constants": 3,
  "main.dart": 1,
  "providers": 1,
  "theme": 1
}

## Critical findings

1. **Unstable external interfaces:** `lib/APIs/api.dart` uses JioSaavn's web `api.php`; `lib/Services/yt_music.dart` uses YouTube Music's internal `youtubei/v1`; `lib/Services/youtube_services.dart` extracts media stream URLs via `youtube_explode_dart`. These are not guaranteed stable streaming integrations.
2. **First-play latency:** `PlayerInvoke.setValues` previously refreshed a selected YouTube song and the next song sequentially. The proposed patch resolves both concurrently (for songs from YouTube), validates the selected URL and does not begin playback with an obviously missing stream.
3. **Silent failure:** `PlayerInvoke.init` didn't `await setValues`, allowing a caller to finish without knowing stream preparation had failed. The proposed patch awaits it and throws a specific error if the selected YouTube URL is missing.
4. **Null/parse robustness:** Offline detection accessed `mediaItem` before it necessarily existed; cached expiry parsing used `int.parse`, and audio-service error logger expected every error to have a `code` property. The patch makes these safer.
5. **Requests hanging:** Saavn transport did not have an explicit request timeout; proposed patch adds an 18-second timeout but cannot guarantee that the endpoint responds successfully.
6. **Animation diagnostics:** The current GitHub workflow builds **debug APK** (`flutter build apk --debug`), unsuitable for judging production frame smoothness. New manual QA workflow builds an **APK in profile mode** and runs analyzer/tests for diagnostics.
7. **Unsupported guarantee:** YouTube audio-only playback is subject to stream extraction and 403 failures; a robust product should offer the official YouTube embedded player for supported playback instead of relying exclusively on extracted audio links. YouTube Music's internal API likewise cannot be promised to work indefinitely.
8. **Android configuration age:** The original Android Gradle configuration targets SDK 29, uses `compileSdkVersion 33` and allows cleartext traffic. SDK/permission migration must be checked for current Android versions; do not blindly bump without testing storage, background audio and notifications.
9. **Upstream-branding/update link:** `Home/home.dart` still references the original BlackHole download/update flow. Disable/replace before releasing a renamed app; license/copyright notices should remain intact.
10. **Current app vs source snapshot:** Current GitHub edits made via earlier ZIP imports may differ from the original uploaded archive. This patch modifies only files reviewed as closely matching the current public GitHub versions. It does not overwrite YouTube home, search, YtMusic or navigation files that already received fixes.

## Package changes (4 files)

- `lib/Services/player_service.dart` — first-track stream guard; fallback attempts with bounded timeouts; await online queue setup; resolve the next track concurrently
- `lib/Services/audio_service.dart` — safe cached expiry parsing and robust error logging
- `lib/APIs/api.dart` — network request timeout, preserving previously corrected URL construction
- `.github/workflows/quality-profile.yml` — optional analyzer, widget test and profile APK build

## Limitations / validation required

1. Upload the patch as `krishna-music-source-ready.zip` and run the existing import-and-build GitHub Action. **Do not assume build succeeds until GitHub Actions confirms it.**
2. In the updated repository, run the new `Krishna Music - Quality and Profile APK` workflow to produce a profile APK, if the old Android Gradle configuration supports it.
3. On a physical phone, test **Saavn, YouTube, YtMusic** independently using at least five different tracks each, under Wi-Fi and mobile data. Record search time, first-audio time, blank/403 errors and seek/pause stability.
4. Use Flutter DevTools on profile mode to identify frame spikes. Check opening tabs, scrolling lists, switching tracks and player transitions.
5. When sources fail, capture the actual HTTP status/exception and distinguish empty search, missing stream manifest, expired URL, and playback decoder errors. Do not hide these under generic spinner text.
6. For reliable YouTube playback, consider official embedded player (`youtube_player_iframe`) where allowed, recognizing that it is not interchangeable with audio-only/background streaming.

## Major source areas inventoried

- lib/APIs
- lib/Services
- lib/Screens/Home
- lib/Screens/Search
- lib/Screens/YouTube
- lib/Screens/Player
- lib/CustomWidgets
- lib/Helpers
- android
- .github/workflows

## Selected automatic detection lists (candidates, not confirmed bugs)

- UI files using scroll/list widgets (profiling candidates): 7
- Files using `.first`, `.last` or `.single` (manual bounds review candidates): 26

**Important:** These detection counts are keyword-based heuristics, not diagnostics from `flutter analyze`.
