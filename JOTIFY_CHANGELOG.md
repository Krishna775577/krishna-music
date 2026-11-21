# Jotify — Saavn Search and Branding Update

## Updated
- Jotify visible branding in Android, iOS, desktop title, Flutter title, translations and app icon.
- Uses the exact logo image supplied by the app owner, cropped and resized for launcher artwork.
- Saavn search preview expanded from 5 song suggestions to up to 24, and has direct-search fallback if autocomplete fails.
- For **Khama Ray Khama**, merges catalog results for `Khama` and `Khamma` alternate spellings with unique song IDs.
- “View All” scroll uses page-by-page expansion, stable de-duplication, and stops when no more new results are returned.
- Existing Saavn audio player and YouTube/YtMusic implementations were not changed.

## Install
The overlay ZIP is for the existing GitHub workflow: upload it as `krishna-music-source-ready.zip` to the repository root, commit, then run the *Import ZIP and Build Android APK* workflow.
The full ZIP is the complete source without a wrapper directory, for manual extraction into a separate repository.

## Important limitations
- Saavn's unofficial catalog search cannot guarantee every recording of a song, or records not indexed under the tested keywords.
- Build and phone playback must be tested in GitHub Actions and Android; this delivery was statically validated but not compiled with Flutter.
- The internal Dart `blackhole` package name, Android package id, old database paths and upstream license/source attributions are intentionally preserved for app stability, existing installation and license compliance. These are not the displayed app name.
- The original project's update check has been disabled; you can distribute Jotify updates through your own GitHub Releases.
