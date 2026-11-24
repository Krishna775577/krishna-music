# Jotify — Spotify-style feature parity roadmap

**Scope:** The product is Jotify, an independent Flutter music application based on
the open-source BlackHole project. Do not represent it as Spotify or offer
unlicensed access to Spotify's music catalog, Premium features, artwork, branding,
podcasts or proprietary services.

**Baseline:** Branch `main` after the November 24, 2026 feature commits.
`Implemented` means source code exists, not that every feature was manually
tested on Android. Follow the GitHub Actions build plus real-device test.

## Implemented and integrated

| Feature | Source / behavior | Status |
|---|---|---|
| Dark Home quick picks | `lib/Screens/Home/jotify_home_highlights.dart` | Implemented |
| Pinned playlist shortcuts | Local Hive `jotifyPinnedPlaylists` | Implemented |
| Playlist folders | Hive `jotifyFolderNames` / `jotifyPlaylistFolders` | Implemented |
| Playlist pin/unpin | Library Plus context menu | Implemented |
| Library filter, alphabetical/recent ordering | `spotify_library.dart` | Implemented |
| On Repeat / Rediscover / Daily Mix | Last 30 locally cached recent songs and play counts | Implemented |
| Most played artists and tracks | Existing `stats` Hive box | Implemented |
| Private Session | Opt-in `jotifyPrivateSession`, prevents future stats/recent writes | Implemented |
| Clear recent history and reset stats | Explicit confirmation; never deletes music | Implemented |
| Synced LRC line lyrics | `immersive_lyrics.dart`; tap to seek, scrolling | Implemented |
| Playback queue, repeat/shuffle, sleep timer | Existing native player | Existing |
| Local music and JioSaavn | Existing app engines | Existing |
| In-app website-based YouTube | Jotify's HTTPS web player in WebView | Existing; real-device verification needed |
| App target SDK 34, scoped download location | Android app/manifest updates | Implemented |

## Not yet feature-equivalent with Spotify

| Feature | Main gap | Reason / prerequisite |
|---|---|---|
| Spotify music catalog | No license | Must have appropriate streaming rights; Spotify API alone is not a license |
| Spotify Connect / multi-device remote control | No account-linked playback sync | Secure backend, device registration and state synchronization |
| Spotify AI DJ | No proprietary AI DJ / licensed catalog | Build a distinctly Jotify original, licensed alternative |
| Official Spotify daylist / Discover Weekly | Only local recent-history mixes | Need a recommendation data pipeline with opt-in consent |
| Collaborative playlists / Jam | No cloud sharing account system | Authentication, realtime backend, conflict handling and abuse controls |
| Follow artists / friends, Blend and social feed | No social graph | User accounts, privacy and moderation |
| Podcasts / audiobooks | No licensed integrated catalog | Integrate authorized feeds/catalogs and rights |
| Word-by-word lyrics | Source primarily provides line-timed LRC | Require per-word timing data and karaoke UI |
| Crossfade and volume normalization | Not implemented | Saavn/local DSP and device regression tests; do not alter the YouTube iframe |
| Verified gapless on every device | Not tested | Audio source testing across tracks and device types |
| Proper production release distribution | No long-lived owner release signing key in CI | Create/secure one production keystore, test installation and Play Protect |
| Real-time account sync / cloud backup | Local Hive data only | Secure opt-in backend and key management |
| Accurate yearly Wrapped and total minutes | Current stats track aggregate plays and last-play timestamp only | New timestamped listening-event logging; never fabricate history |
| Offline arbitrary streaming catalog | Licensing and source restrictions | Must respect content rights, DRM and API policies |

## Release gates

1. `flutter pub get` and `flutter build apk --debug` successfully finish.
2. GitHub Actions APK audit verifies Android target API 34 and no
   `MANAGE_EXTERNAL_STORAGE` / `REQUEST_INSTALL_PACKAGES` permissions.
3. Real Android smoke test: Home, Library Plus, folders, pinned items, smart
   mixes, stats, Private Session, offline music, Saavn, lyrics, and YouTube.
4. Preserve original user data; never uninstall the previous app without an
   independent backup and a signing/upgrade compatibility check.
5. Production release must be signed with a persistent owner's release key.
   A successful debug build is not proof of Play Protect approval.
6. Honor user privacy: a Private Session must stop local listening-stat writes
   and should be clearly distinguished from anonymous network activity.

## Follow-up engineering phases

- **Next functional batch:** playlist sorting in the original playlist screen,
  polished mini-player visuals, seamless queue actions and test coverage.
- **Audio batch:** crossfade, normalization and gapless regression checks for
  Saavn/local audio, without modifying hosted YouTube playback.
- **Discovery batch:** consent-based recommendations and durable listening
  events to support useful annual Replay-style summaries.
- **Connected/social batch:** optional accounts, cloud playlists, collaborative
  playlists and cross-device sync with security/privacy review.
- **Production release batch:** stable Android package name, release signing,
  security scan, privacy policy, backup/import path and Play Protect diagnosis.

This is a transparency document, not a claim that every Spotify feature is
available or that a Spotify subscription can be replaced.
