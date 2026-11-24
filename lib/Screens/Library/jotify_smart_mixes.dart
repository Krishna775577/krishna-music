// Jotify Smart Mixes: transparent, on-device playlists built from listening
// history already saved by Jotify. This is not Spotify's licensed discovery
// catalog or AI DJ and does not use a third-party recommendation service.
import 'package:blackhole/Services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class JotifySmartMixes extends StatefulWidget {
  const JotifySmartMixes({super.key});

  @override
  State<JotifySmartMixes> createState() => _JotifySmartMixesState();
}

class _JotifySmartMixesState extends State<JotifySmartMixes> {
  static const green = Color(0xFF1ED760);
  final Box _cache = Hive.box('cache');
  final Box _stats = Hive.box('stats');

  List<Map> _history() {
    final raw = _cache.get('recentSongs', defaultValue: <dynamic>[]);
    if (raw is! List) return <Map>[];
    final seen = <String>{};
    final out = <Map>[];
    for (final song in raw.whereType<Map>()) {
      final id = (song['id'] ?? '').toString();
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(song);
    }
    return out;
  }

  int _plays(Map song) {
    final value = _stats.get((song['id'] ?? '').toString());
    if (value is Map && value['playCount'] is num) {
      return (value['playCount'] as num).toInt();
    }
    return 0;
  }

  int _lastPlayed(Map song) {
    final value = _stats.get((song['id'] ?? '').toString());
    if (value is Map && value['lastPlayed'] is num) {
      return (value['lastPlayed'] as num).toInt();
    }
    return 0;
  }

  Future<void> _play(List<Map> tracks, {bool shuffle = false}) async {
    if (tracks.isEmpty) return;
    try {
      await PlayerInvoke.init(
        songsList: tracks,
        index: 0,
        shuffle: shuffle,
        recommend: false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'This mix could not play. Try another track.',
        )),
      );
    }
  }

  Widget _mixCard({
    required String title,
    required String description,
    required IconData icon,
    required List<Map> tracks,
    required Color background,
    bool shuffle = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: LinearGradient(colors: [
          background, const Color(0xFF1A1C1B),
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(
            color: Colors.white, fontSize: 23,
            fontWeight: FontWeight.w900,
          )),
          const SizedBox(height: 7),
          Text(description, style: const TextStyle(
            color: Colors.white70, height: 1.4,
          )),
          const SizedBox(height: 12),
          Text('${tracks.length} tracks from your recent history',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: tracks.isEmpty ? null :
                () => _play(tracks, shuffle: shuffle),
            icon: Icon(shuffle ? Icons.shuffle_rounded :
                Icons.play_arrow_rounded),
            label: Text(shuffle ? 'Shuffle mix' : 'Play mix'),
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: const Text('Made for you',
          style: TextStyle(fontWeight: FontWeight.w800)),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF101010),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _cache.listenable(keys: ['recentSongs']),
          _stats.listenable(),
        ]),
        builder: (context, _) {
          final recent = _history();
          final onRepeat = List<Map>.from(recent)..sort(
              (a, b) => _plays(b).compareTo(_plays(a)));
          final rediscover = List<Map>.from(recent)..sort(
              (a, b) => _lastPlayed(a).compareTo(_lastPlayed(b)));
          final freshMix = List<Map>.from(recent)..shuffle();
          return ListView(
            padding: const EdgeInsets.fromLTRB(17, 12, 17, 65),
            children: [
              const Text('Your mixes, your listening.',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 22)),
              const SizedBox(height: 5),
              const Text('Built locally from the music you played. '
                  'These picks update as you listen.',
                  style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 22),
              _mixCard(
                title: 'On Repeat',
                description: 'Your most-played tracks from recent history.',
                icon: Icons.repeat_rounded,
                tracks: onRepeat.take(25).toList(),
                background: const Color(0xFF2B5B49),
              ),
              _mixCard(
                title: 'Rediscover',
                description: 'Revisit tracks you have not played lately.',
                icon: Icons.history_toggle_off_rounded,
                tracks: rediscover.take(25).toList(),
                background: const Color(0xFF564278),
              ),
              _mixCard(
                title: 'Your Daily Mix',
                description: 'A shuffled mix of songs you recently enjoyed.',
                icon: Icons.auto_awesome_rounded,
                tracks: freshMix.take(25).toList(),
                background: const Color(0xFF75502D),
                shuffle: true,
              ),
              const Text('Mixes use your existing recent-song cache (up to '
                  '30 tracks) and saved play counts, not an external '
                  'recommendation engine. Songs that no longer stream may '
                  'not play.',
                  style: TextStyle(
                    color: Colors.white38, fontSize: 11, height: 1.45)),
            ],
          );
        },
      ),
    );
  }
}
