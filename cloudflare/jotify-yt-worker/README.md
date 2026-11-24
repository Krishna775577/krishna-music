# Jotify shared YouTube API (no Render, no per-user keys)

The Android app uses **native Flutter** and discovers this Worker's public HTTPS
base URL from the repository's `jotify-config.json`. All users share one
owner-managed YouTube Data API v3 credential. The secret is never embedded in
an APK or committed to GitHub.

## One-time owner setup

1. Create or use a Cloudflare account. In Google Cloud, enable **YouTube Data
   API v3** and create a **new API key** restricted to only that API. Do not
   reuse a key that was pasted into a chat or checked into source. Server
   requests from Cloudflare may not have stable outbound IPs, so API
   restrictions are especially important.
2. In GitHub `Krishna775577/krishna-music` -> **Settings -> Secrets and
   variables -> Actions**, add repository **secrets**:
   `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`. The Cloudflare token
   should be limited to Workers editing in the intended Cloudflare account.
   Never post either secret in chat or commit it to source.
3. GitHub **Actions -> Deploy shared Jotify YouTube Worker -> Run workflow**.
   Confirm the deploy succeeded and copy the exact `https://...workers.dev`
   Worker URL displayed in its output or in Cloudflare dashboard.
4. Cloudflare **Workers & Pages -> jotify-youtube-gateway -> Settings ->
   Variables and Secrets -> Add -> Secret**: name `YOUTUBE_API_KEY`, value
   your new Google API key. Deploy/save the secret. (Alternatively locally:
   `npx wrangler secret put YOUTUBE_API_KEY` from this directory.)
5. Verify `https://YOUR_WORKER/health` returns
   `{"status":"ok", ... "configured":true}`. Do not share the key.
6. Edit the public GitHub file `jotify-config.json`:
   `{"version":1,"youtubeApiBase":"https://YOUR_WORKER.workers.dev"}`.
   This file contains ONLY the public Worker URL, never a key.
7. In Jotify Android YT search, type a song. Users now search and play without
   an API key prompt. Already-installed builds load the owner config at search
   time and don't need to be rebuilt just to update the Worker URL.

### API routes

- `GET /health` -> status/configured
- `GET /api/yt/search?kind=song&q=Radhe%20Radhe`
- `GET /api/yt/search?kind=playlist&q=Krishna`
- `GET /api/yt/playlist?list=PUBLIC_PLAYLIST_ID`

## Operations and security

- This is a **public gateway**. It does not authenticate individual users.
  Cloudflare rate limiting is approximate, not a strict daily Google quota cap.
  Monitor usage, configure Cloudflare WAF, and request extra Google API quota
  if needed. YouTube's documented default search bucket is 100 search.list
  requests per day; cache repeated queries where possible.
- Each request uses only official YouTube Data API metadata. Actual video
  playback remains inside the official embedded YouTube player and is subject
  to embedding/visibility restrictions; there is no audio extraction or
  hidden/screen-lock YouTube playback.
- If the Worker secret is absent the API returns HTTP 503. If quota is exhausted
  it returns a friendly error, not a credential.
- Source changes in this Android repo **do not alter** the separate Render
  website. The Android UI stays local; it needs internet only for online music
  features and the public config lookup.
