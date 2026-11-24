// Jotify YouTube overlay: show the working first-party hosted YouTube
// experience in an Android WebView. The website uses an official visible
// YouTube embed and keeps its API key on the server; Saavn stays untouched.
import 'package:blackhole/Screens/YouTube/official_youtube_player.dart';
import 'package:blackhole/Screens/YouTube/jotify_website_youtube.dart';
import 'package:flutter/material.dart';

class JotifyNativeYTOverlay {
  static OverlayEntry? _entry;
  static final ValueNotifier<_WatchRequest?> _current =
      ValueNotifier<_WatchRequest?>(null);
  static final RegExp _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static void show(
    BuildContext context,
    List<KrishnaYoutubeTrack> tracks,
    int index,
  ) {
    final queue =
        tracks.where((track) => _videoId.hasMatch(track.videoId)).toList();
    if (queue.isEmpty) return;
    final safeIndex = index.clamp(0, queue.length - 1).toInt();
    _current.value = _WatchRequest(queue, safeIndex);
    if (_entry != null) return;
    _entry = OverlayEntry(builder: (_) => const _WatchOverlay());
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  static void close() {
    _current.value = null;
    final existing = _entry;
    _entry = null;
    existing?.remove();
    existing?.dispose();
  }
}

class _WatchRequest {
  final List<KrishnaYoutubeTrack> tracks;
  final int index;
  const _WatchRequest(this.tracks, this.index);
}

class _WatchOverlay extends StatefulWidget {
  const _WatchOverlay();

  @override
  State<_WatchOverlay> createState() => _WatchOverlayState();
}

class _WatchOverlayState extends State<_WatchOverlay> {
  late _WatchRequest request;
  static const _green = Color(0xFF1ED760);

  KrishnaYoutubeTrack get track => request.tracks[request.index];

  @override
  void initState() {
    super.initState();
    request = JotifyNativeYTOverlay._current.value!;
    JotifyNativeYTOverlay._current.addListener(_onChange);
  }

  void _onChange() {
    final next = JotifyNativeYTOverlay._current.value;
    if (next == null || !mounted) return;
    setState(() => request = next);
  }

  void _change(int index) {
    if (index < 0 || index >= request.tracks.length) return;
    JotifyNativeYTOverlay._current.value =
        _WatchRequest(request.tracks, index);
  }

  @override
  void dispose() {
    JotifyNativeYTOverlay._current.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF090E0B),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              color: const Color(0xFF141E17),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close YouTube player',
                    onPressed: JotifyNativeYTOverlay.close,
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Icon(Icons.smart_display_rounded,
                      color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close video',
                    onPressed: JotifyNativeYTOverlay.close,
                    color: Colors.white70,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: JotifyWebsiteYouTube(
                key: ValueKey<String>(track.videoId),
                videoId: track.videoId,
              ),
            ),
            if (request.tracks.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: const Color(0xFF141E17),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous video',
                      onPressed: request.index > 0
                          ? () => _change(request.index - 1)
                          : null,
                      color: _green,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Video ${request.index + 1} of ${request.tracks.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next video',
                      onPressed: request.index < request.tracks.length - 1
                          ? () => _change(request.index + 1)
                          : null,
                      color: _green,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
