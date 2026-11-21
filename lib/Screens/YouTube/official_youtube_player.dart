/*
 * Krishna Music YouTube/YtMusic in-app video player.
 * BlackHole-derived software: retain original project copyright / license.
 * Uses the official embedded YouTube IFrame player. Video remains visible.
 * No extraction, hidden playback, background audio or media downloading.
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

@immutable
class KrishnaYoutubeTrack {
  final String videoId;
  final String title;
  final String artist;

  const KrishnaYoutubeTrack({
    required this.videoId,
    required this.title,
    this.artist = '',
  });
}

class OfficialYouTubePlayerPage extends StatefulWidget {
  final String videoId;
  final String title;
  final String artist;
  final List<KrishnaYoutubeTrack> queue;
  final int initialIndex;

  const OfficialYouTubePlayerPage({
    super.key,
    required this.videoId,
    required this.title,
    this.artist = '',
    this.queue = const [],
    this.initialIndex = 0,
  });

  @override
  State<OfficialYouTubePlayerPage> createState() =>
      _OfficialYouTubePlayerPageState();
}

class _OfficialYouTubePlayerPageState extends State<OfficialYouTubePlayerPage> {
  static const Color _background = Color(0xFF111111);
  static const Color _accent = Color(0xFF03D5AE);
  late YoutubePlayerController _controller;
  late List<KrishnaYoutubeTrack> _queue;
  int _index = 0;
  int _playerInstance = 0;
  bool _autoAdvanceArmed = false;
  Timer? _stallTimer;
  bool _showStallHelp = false;

  KrishnaYoutubeTrack get _current => _queue[_index];

  YoutubePlayerController _newController(String videoId) {
    return YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false, // A user tap starts YouTube playback.
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
        loop: false,
      ),
    );
  }

  void _armStallHelp() {
    _stallTimer?.cancel();
    _showStallHelp = false;
    _stallTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _showStallHelp = true);
    });
  }

  @override
  void initState() {
    super.initState();
    final List<KrishnaYoutubeTrack> safeQueue = widget.queue
        .where((entry) => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(entry.videoId))
        .toList();
    _queue = safeQueue.isEmpty
        ? <KrishnaYoutubeTrack>[
            KrishnaYoutubeTrack(
              videoId: widget.videoId,
              title: widget.title,
              artist: widget.artist,
            ),
          ]
        : safeQueue;
    _index = widget.initialIndex.clamp(0, _queue.length - 1).toInt();
    _controller = _newController(_current.videoId);
    _armStallHelp();
  }

  Future<void> _changeTrack(int newIndex) async {
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (!mounted) return;
    _armStallHelp();
    _autoAdvanceArmed = false;
    setState(() => _index = newIndex);
    // Invoked only after an explicit user action / completion of a
    // user-started playlist. Always show the embedded video player.
    await _controller.loadVideoById(videoId: _current.videoId);
  }

  void _retry() {
    _stallTimer?.cancel();
    _controller.close();
    _controller = _newController(_current.videoId);
    _playerInstance += 1;
    _armStallHelp();
    setState(() {});
  }

  void _handleEnded() {
    if (!_autoAdvanceArmed) return;
    _autoAdvanceArmed = false;
    if (_index >= _queue.length - 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _changeTrack(_index + 1);
    });
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _controller.close();
    super.dispose();
  }

  String _statusText(PlayerState state) {
    switch (state) {
      case PlayerState.buffering:
        return 'Buffering…';
      case PlayerState.playing:
        return 'Playing';
      case PlayerState.paused:
        return 'Paused';
      case PlayerState.ended:
        return 'Finished';
      default:
        return 'Tap Play on the video';
    }
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      key: ValueKey<int>(_playerInstance),
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
        return Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            backgroundColor: _background,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Krishna Music',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                player, // Visible, actual official YouTube video.
                YoutubeValueBuilder(
                  controller: _controller,
                  builder: (context, value) {
                    final bool playing =
                        value.playerState == PlayerState.playing;
                    final bool buffering =
                        value.playerState == PlayerState.buffering;
                    final bool ended = value.playerState == PlayerState.ended;
                    if (playing) _autoAdvanceArmed = true;
                    if (ended) _handleEnded();
                    final bool error =
                        value.error.toString() != 'YoutubeError.none';
                    final bool failedToStart = _showStallHelp &&
                        (!value.isReady || buffering);
                    return Column(
                      children: <Widget>[
                        if (buffering)
                          const LinearProgressIndicator(
                            minHeight: 2,
                            color: _accent,
                            backgroundColor: Color(0xFF333333),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 24, 18, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _current.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _current.artist.isEmpty
                                    ? 'YouTube video'
                                    : _current.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _statusText(value.playerState),
                                style: const TextStyle(
                                    color: _accent, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Previous video',
                              iconSize: 34,
                              color: Colors.white,
                              onPressed: _index > 0
                                  ? () => _changeTrack(_index - 1)
                                  : null,
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            const SizedBox(width: 18),
                            IconButton(
                              tooltip: playing ? 'Pause' : 'Play',
                              iconSize: 50,
                              color: _accent,
                              onPressed: value.isReady
                                  ? () => playing
                                      ? _controller.pauseVideo()
                                      : _controller.playVideo()
                                  : null,
                              icon: Icon(playing
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded),
                            ),
                            const SizedBox(width: 18),
                            IconButton(
                              tooltip: 'Next video',
                              iconSize: 34,
                              color: Colors.white,
                              onPressed: _index < _queue.length - 1
                                  ? () => _changeTrack(_index + 1)
                                  : null,
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                          ],
                        ),
                        if (error || failedToStart)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: <Widget>[
                                const Text(
                                  'Video could not start. Check connection or '
                                  'try again. Some YouTube videos cannot be embedded.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                                TextButton.icon(
                                  onPressed: _retry,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry in Krishna Music'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (_queue.length > 1) ...<Widget>[
                  const Divider(color: Color(0xFF333333), height: 24),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 6, 18, 12),
                    child: Text('Up next',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                  ...List<Widget>.generate(_queue.length, (int i) {
                    final track = _queue[i];
                    return ListTile(
                      dense: true,
                      selected: i == _index,
                      selectedColor: _accent,
                      leading: Icon(
                        i == _index
                            ? Icons.equalizer_rounded
                            : Icons.play_arrow_rounded,
                        color: i == _index ? _accent : Colors.white70,
                      ),
                      title: Text(track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54)),
                      onTap: () => _changeTrack(i),
                    );
                  }),
                ],
                const SizedBox(height: 26),
              ],
            ),
          ),
        );
      },
    );
  }
}
