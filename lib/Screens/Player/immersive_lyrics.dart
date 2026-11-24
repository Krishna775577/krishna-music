// Jotify immersive synced lyrics.
// Keeps the existing lyrics sources and audio player intact. Inspired by
// modern full-screen music lyrics, without copying another app's assets.
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:blackhole/Helpers/lyrics.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:flutter/material.dart';

class ImmersiveLyricsPage extends StatelessWidget {
  final AudioPlayerHandler audioHandler;
  final ValueListenable<List<Color?>?> albumColors;
  final bool getLyricsOnline;

  const ImmersiveLyricsPage({
    super.key,
    required this.audioHandler,
    required this.albumColors,
    required this.getLyricsOnline,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Color?>?>(
      valueListenable: albumColors,
      builder: (context, colors, _) {
        final mainColor = Color.lerp(
          colors != null && colors.isNotEmpty
              ? colors.first ?? const Color(0xFF384E68)
              : const Color(0xFF384E68),
          Colors.black,
          0.34,
        )!;
        final bottomColor = Color.lerp(
          colors != null && colors.length > 1
              ? colors[1] ?? const Color(0xFF17142D)
              : const Color(0xFF17142D),
          Colors.black,
          0.67,
        )!;
        return Scaffold(
          backgroundColor: Colors.black,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [mainColor, bottomColor, const Color(0xFF090C12)],
                stops: const [0, .53, 1],
              ),
            ),
            child: SafeArea(
              child: StreamBuilder<MediaItem?>(
                stream: audioHandler.mediaItem,
                initialData: audioHandler.mediaItem.value,
                builder: (context, snapshot) {
                  final item = snapshot.data;
                  if (item == null) {
                    return const Center(
                      child: Text('Choose a song to see lyrics',
                          style: TextStyle(color: Colors.white)),
                    );
                  }
                  return Column(
                    children: [
                      _header(context, item),
                      Expanded(
                        child: _LyricsForSong(
                          key: ValueKey<String>(
                              '${item.id}:${item.extras?['url'] ?? ''}'),
                          mediaItem: item,
                          audioHandler: audioHandler,
                          getLyricsOnline: getLyricsOnline,
                        ),
                      ),
                      _transport(context),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, MediaItem item) {
    final uri = item.artUri?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to player',
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 32),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Container(
            width: 42, height: 42,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white12,
            ),
            child: uri.startsWith('http')
                ? Image.network(uri, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.music_note, color: Colors.white))
                : const Icon(Icons.music_note, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(item.artist ?? 'Jotify',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70,
                        fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.lyrics_rounded, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _transport(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 14),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq_rounded,
              color: Colors.white70, size: 19),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('JOTIFY  •  LYRICS',
                style: TextStyle(
                    letterSpacing: 1.2, color: Colors.white70,
                    fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            initialData: audioHandler.playbackState.value,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return IconButton(
                tooltip: playing ? 'Pause' : 'Play',
                onPressed: () {
                  if (playing) {
                    audioHandler.pause();
                  } else {
                    audioHandler.play();
                  }
                },
                icon: Icon(
                  playing ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: Colors.white, size: 41,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LyricLine {
  final int startMs;
  final String text;
  const _LyricLine(this.startMs, this.text);
}

class _LyricsForSong extends StatefulWidget {
  final MediaItem mediaItem;
  final AudioPlayerHandler audioHandler;
  final bool getLyricsOnline;

  const _LyricsForSong({
    super.key,
    required this.mediaItem,
    required this.audioHandler,
    required this.getLyricsOnline,
  });

  @override
  State<_LyricsForSong> createState() => _LyricsForSongState();
}

class _LyricsForSongState extends State<_LyricsForSong> {
  static const double _rowHeight = 94;
  final ScrollController _scrollController = ScrollController();
  List<_LyricLine> _timed = const [];
  String _plain = '';
  String _source = '';
  String? _error;
  bool _loading = true;
  int _lastCentered = -1;
  DateTime _manualScrollUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _lastCentered = -1;
      _timed = const [];
      _plain = '';
    });
    try {
      final song = widget.mediaItem;
      final uri = (song.extras?['url'] ?? '').toString();
      final offline = !uri.startsWith('http');
      String raw = '';
      String source = '';

      if (offline) {
        raw = await Lyrics.getOffLyrics(uri);
        if (raw.trim().isNotEmpty) source = 'Local audio tags';
      }
      if (raw.trim().isEmpty && (!offline || widget.getLyricsOnline)) {
        final result = await Lyrics.getLyrics(
          id: song.id,
          saavnHas: song.extras?['has_lyrics'] == 'true',
          title: song.title,
          artist: song.artist ?? '',
        );
        raw = (result['lyrics'] ?? '').toString();
        source = (result['source'] ?? '').toString();
      }
      final timed = _parseLrc(raw);
      if (!mounted) return;
      setState(() {
        _timed = timed;
        _plain = raw
            .split('\n')
            .where((line) =>
                !RegExp(r'^\s*\[(?:ar|al|ti|by|offset):',
                    caseSensitive: false).hasMatch(line))
            .join('\n').trim();
        _source = source;
        _loading = false;
        if (raw.trim().isEmpty) {
          _error = offline && !widget.getLyricsOnline
              ? 'No local lyrics found. Enable online lyrics in Settings.'
              : 'Lyrics are not available for this track.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load lyrics. Check your connection and retry.';
      });
    }
  }

  List<_LyricLine> _parseLrc(String raw) {
    final tag = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final offsetMatch = RegExp(r'\[offset:([+-]?\d+)\]',
        caseSensitive: false).firstMatch(raw);
    final offset = int.tryParse(offsetMatch?.group(1) ?? '') ?? 0;
    final lines = <_LyricLine>[];
    for (final rawLine in raw.split('\n')) {
      final matches = tag.allMatches(rawLine).toList();
      if (matches.isEmpty) continue;
      final words = rawLine.substring(matches.last.end).trim();
      for (final match in matches) {
        final minute = int.tryParse(match.group(1) ?? '') ?? 0;
        final second = int.tryParse(match.group(2) ?? '') ?? 0;
        final fraction = match.group(3) ?? '';
        final ms = fraction.isEmpty
            ? 0
            : (int.tryParse(fraction) ?? 0) *
                math.pow(10, 3 - fraction.length).toInt();
        lines.add(_LyricLine(
            math.max(0, minute * 60000 + second * 1000 + ms + offset),
            words.isEmpty ? '♪' : words));
      }
    }
    lines.sort((a, b) => a.startMs.compareTo(b.startMs));
    return lines;
  }

  int _activeLine(int positionMs) {
    if (_timed.isEmpty) return -1;
    var low = 0;
    var high = _timed.length - 1;
    var active = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (_timed[mid].startMs <= positionMs) {
        active = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return active;
  }

  void _center(int active) {
    if (active < 0 || active == _lastCentered ||
        DateTime.now().isBefore(_manualScrollUntil)) return;
    _lastCentered = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final target = (active * _rowHeight).clamp(0.0, maxScroll);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lyrics_outlined,
                  size: 54, color: Colors.white70),
              const SizedBox(height: 18),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70,
                      fontSize: 17, height: 1.4)),
              const SizedBox(height: 15),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white),
                label: const Text('Retry lyrics',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: _timed.isNotEmpty
              ? StreamBuilder<Duration>(
                  stream: AudioService.position,
                  builder: (context, snapshot) {
                    final active = _activeLine(
                        (snapshot.data ?? Duration.zero).inMilliseconds);
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        _center(active);
                        return NotificationListener<UserScrollNotification>(
                          onNotification: (event) {
                            if (event.direction != ScrollDirection.idle) {
                              _manualScrollUntil = DateTime.now().add(
                                  const Duration(seconds: 4));
                            }
                            return false;
                          },
                          child: ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0, .10, .80, 1],
                                  colors: [
                                    Colors.transparent, Colors.white,
                                    Colors.white, Colors.transparent,
                                  ],
                                ).createShader(bounds),
                            blendMode: BlendMode.dstIn,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.only(
                                top: constraints.maxHeight * .31,
                                bottom: constraints.maxHeight * .51,
                                left: 26, right: 24,
                              ),
                              itemExtent: _rowHeight,
                              itemCount: _timed.length,
                              itemBuilder: (context, index) {
                                final line = _timed[index];
                                final selected = index == active;
                                return Semantics(
                                  button: true,
                                  label: '${line.text}. Seek to lyric',
                                  child: InkWell(
                                    onTap: () => widget.audioHandler.seek(
                                        Duration(milliseconds: line.startMs)),
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 230),
                                      opacity: selected ? 1 : .34,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: AnimatedDefaultTextStyle(
                                          duration: const Duration(
                                              milliseconds: 230),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: selected ? 30 : 26,
                                            height: 1.14,
                                            letterSpacing: -.45,
                                            fontWeight: selected
                                                ? FontWeight.w800
                                                : FontWeight.w650,
                                          ),
                                          child: Text(line.text,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 70),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SelectableText(
                      _plain.replaceAll(
                          RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]'),
                          ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.7,
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _timed.isEmpty
                      ? 'Unsynced lyrics'
                      : 'Synced lyrics  •  Tap a line to seek',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
              ),
              if (_source.isNotEmpty)
                Flexible(
                  child: Text('Source: $_source',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60, fontSize: 10)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
