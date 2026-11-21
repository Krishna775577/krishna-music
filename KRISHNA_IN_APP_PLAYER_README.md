# Krishna Music — Saavn audio + in-app YouTube video

## Architecture

- Saavn and local/offline tracks: existing `just_audio`/audio service path **unchanged**.
- YouTube and YtMusic: use `youtube_player_iframe: 4.0.4` to render the actual official YouTube video **inside** Krishna Music.
- The in-app player deliberately does not extract YouTube audio, hide the video, stream in the background, or download YouTube audio.

## Changes

- In-app dark YouTube player with visible embedded video, play/pause, previous/next, and an Up next queue.
- Opening a YouTube or YtMusic search result builds its queue from search results.
- Playlist/artist song taps pass the full queue; the playlist's Play and Shuffle buttons also use the in-app player.
- When a video ends after playback, the next queued entry is loaded automatically (subject to YouTube autoplay restrictions).
- Player shows buffering, a delayed connection hint, and an in-app Retry button. Playlist/artist requests have bounded loading and Retry rather than hanging indefinitely.
- Main audio player continues to route Saavn to `just_audio` while video entries route to the embedded screen.

## Known limitations

- Some YouTube videos prohibit embedding or restrict playback by location/account/age. The in-app player cannot override these conditions.
- Playback still requires a user gesture where YouTube or Android WebView autoplay rules demand it.
- This is not background or audio-only YouTube playback. Lock-screen/notification media transport controls for YouTube remain a separate, unsupported feature.
- YouTube and YtMusic search results may fail intermittently because the app's search APIs are unofficial; this patch is focused on playback and UI routing.
- Builds and phone playback have **not** been verified in this environment. Run the GitHub Actions Android workflow and test on a real phone.

## Test sequence

1. Run `.github/workflows/krishna-build.yml` on GitHub Actions or `flutter pub get && flutter build apk --debug` locally.
2. Test Saavn song search/play/pause/next: should continue using its existing audio player.
3. Search a playable YouTube video. Tap the result; verify that video renders inside Krishna Music and can be played.
4. Open 2+ YouTube results via a list. Test Next, Previous, Up next, automatic advance, and pause/play.
5. Test a YtMusic result with a valid 11-character video ID. It should use the same embedded player.
6. Toggle Wi-Fi off/on to see bounded feedback and Retry; verify playlist/artist pages don't spin forever.
7. Confirm no `Open in YouTube` primary action is shown on the in-app player page.

## Attribution

Retain the original BlackHole project LICENSE, credits and copyright notices. The YouTube iframe player package has its own BSD-2-Clause license.
