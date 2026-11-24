# Jotify V11 — shared YouTube API update

**What changed:** The native Android YT tab no longer asks each user for a
Google API key. It discovers an owner-managed Cloudflare Worker URL via
`jotify-config.json`, then calls that Worker for official YouTube song and
public playlist search. The Worker uses Cloudflare secret `YOUTUBE_API_KEY`.

**Owner activation is still necessary:** the initial public
`jotify-config.json` has an intentionally blank `youtubeApiBase`. The
connected GitHub integration cannot deploy into an unconnected Cloudflare
account or populate a secret on its own. Follow
[the Cloudflare setup guide](cloudflare/jotify-yt-worker/README.md).
Until that setup is finished the Android YT tab displays an owner-setup
message; there is no per-user key setup.

**Not modified:** Flutter Saavn library/player, existing user databases and
download files, Jotify Render website, YouTube embedded-player implementation.

**Version:** Jotify V11 shared-API branch. Debug builds have a separate Android
package suffix and cannot overwrite an installed production Jotify.
