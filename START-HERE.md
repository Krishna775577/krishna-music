# Krishna Music — setup notes

This repository contains a modified copy of the BlackHole Flutter music player and a **separate** browser-based music player under `docs/index.html`.

## Source and copyright

The Android/Flutter source is based on BlackHole by Ankit Sangwan, licensed under GNU GPL v3 (see original `LICENSE` and `README.md`). All original copyright notices must be retained. Changes in this archive:
- Added an independent HTML/CSS/JavaScript web music player in `docs/`.
- Adjusted the old Android Gradle build script to allow a debug APK without a private release-signing keystore.
- Removed historic third-party CI/workflow files and generated desktop build artifacts.

The HTML music player is a basic local-file/direct-audio-URL player, **not** a port of all BlackHole features. There is no guarantee that third-party streaming services still work. An Android APK has NOT been compiled or tested by the archive creator.

## Publishing the website

On GitHub: Settings → Pages → Deploy from a branch → `main` → `/docs` → Save. Visit `https://YOUR_GITHUB_USERNAME.github.io/krishna-music/` if your repo is called `krishna-music`.

## APK

Use the separately supplied `.github/workflows/import-and-build.yml` workflow via GitHub Actions → Run workflow. This creates a *debug* APK for personal installation/testing, not a Play Store production release. For any distributed release, configure your own secure app-signing key and check permissions, dependencies and service compliance.
