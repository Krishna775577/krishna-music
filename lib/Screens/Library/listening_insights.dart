// Jotify Listening Insights: real local listening counters, not invented
// annual statistics or a remote recommendation service.
import 'package:blackhole/Services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class JotifyListeningInsights extends StatelessWidget {
  const JotifyListeningInsights({super.key});

  static const Color _accent = Color(0xFF1ED760);

  List<Map<String, dynamic>> _tracks(Box stats) {
    final entries = <Map<String, dynamic>>[];
    for (final key in stats.keys) {
      if (key.toString() == 'mostPlayed') continue;
      final value = stats.get(key);
      if (value is! Map || value['playCount'] is! num) continue;
      final plays = (value['playCount'] as num).toInt();
      if (plays <= 0) continue;
      entries.add({
        'title': (value['title'] ?? 'Unknown song').toString(),
        'artist': (value['artist'] ?? 'Unknown artist').toString(),
        'playCount': plays,
        'lastPlayed': (value['lastPlayed'] is num)
            ? (value['lastPlayed'] as num).toInt() : 0,
      });
    }
    entries.sort((a, b) =>
        (b['playCount'] as int).compareTo(a['playCount'] as int));
    return entries;
  }

  List<Map<String, dynamic>> _recent(Box cache) {
    final raw = cache.get('recentSongs', defaultValue: <dynamic>[]);
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((item) {
      final map = <String, dynamic>{};
      for (final entry in item.entries) {
        map[entry.key.toString()] = entry.value;
      }
      return map;
    }).where((row) => row['id'] != null).toList();
  }

  Widget _metric(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF212121),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _accent, size: 22),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(color: Colors.white,
                fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(
                color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _ranked(String title, List<MapEntry<String, int>> ranking,
      {bool isArtist = false}) {
    final maximum = ranking.isEmpty ? 1 : ranking.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
          child: Text(title, style: const TextStyle(
            color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800,
          )),
        ),
        if (ranking.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Your listening stats will appear as you play music.',
                style: TextStyle(color: Colors.white60)),
          ),
        for (var i = 0; i < ranking.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                SizedBox(width: 26, child: Text('${i + 1}',
                    style: const TextStyle(color: Colors.white54,
                        fontWeight: FontWeight.w800))),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isArtist ? const Color(0xFF23452D) :
                        const Color(0xFF35314E),
                  ),
                  child: Icon(isArtist ? Icons.person_rounded :
                      Icons.music_note_rounded, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(ranking[i].key,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Text('${ranking[i].value} plays',
                          style: const TextStyle(color: Colors.white54,
                              fontSize: 11)),
                    ]),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ranking[i].value / maximum,
                        minHeight: 5,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(_accent),
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = Hive.box('stats');
    final cache = Hive.box('cache');
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: const Text('Jotify Listening Insights',
          style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([stats.listenable(), cache.listenable()]),
        builder: (context, _) {
          final records = _tracks(stats);
          final recent = _recent(cache);
          final playCount = records.fold<int>(
              0, (sum, track) => sum + (track['playCount'] as int));
          final artistPlays = <String, int>{};
          for (final song in records) {
            final name = (song['artist'] as String).trim();
            if (name.isEmpty) continue;
            artistPlays.update(name,
                (count) => count + (song['playCount'] as int),
                ifAbsent: () => song['playCount'] as int);
          }
          final artists = artistPlays.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final songs = records.take(8).map((item) => MapEntry(
              item['title'] as String, item['playCount'] as int)).toList();
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 70),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFF245737), Color(0xFF122219),
                  ]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: _accent, size: 30),
                    SizedBox(height: 10),
                    Text('Your music story',
                        style: TextStyle(color: Colors.white,
                          fontSize: 28, fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text('Your real, on-device listening history. '
                        'No account or tracking server required.',
                        style: TextStyle(color: Colors.white70, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                _metric('Recorded plays', '$playCount',
                    Icons.graphic_eq_rounded),
                const SizedBox(width: 10),
                _metric('Unique songs', '${records.length}',
                    Icons.library_music_rounded),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _metric('Artists heard', '${artists.length}',
                    Icons.people_rounded),
                const SizedBox(width: 10),
                _metric('Recent tracks', '${recent.length}',
                    Icons.history_rounded),
              ]),
              _ranked('Your top songs', songs),
              _ranked('Your top artists', artists.take(8).toList(),
                  isArtist: true),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 22, 4, 10),
                child: Text('Keep listening',
                  style: TextStyle(color: Colors.white,
                      fontSize: 21, fontWeight: FontWeight.w800)),
              ),
              if (recent.isEmpty)
                const Text('Play your favorite songs to build a mix.',
                    style: TextStyle(color: Colors.white60))
              else ...[
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await PlayerInvoke.init(
                        songsList: recent, index: 0, shuffle: true,
                        recommend: false,
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(
                              'Could not play this mix. Try a different track.')),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.black, backgroundColor: _accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Shuffle my recently played'),
                ),
                const SizedBox(height: 6),
                ...recent.take(8).map((song) {
                  final title = (song['title'] ?? 'Unknown song').toString();
                  final artist = (song['artist'] ?? '').toString();
                  final index = recent.indexOf(song);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF292929),
                      child: Icon(Icons.play_arrow_rounded,
                          color: Colors.white),
                    ),
                    title: Text(title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(artist,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60)),
                    onTap: () async {
                      try {
                        await PlayerInvoke.init(
                          songsList: recent, index: index,
                          recommend: false,
                        );
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content:
                                Text('This track could not play.')),
                          );
                        }
                      }
                    },
                  );
                }),
              ],
              const SizedBox(height: 16),
              const Text(
                'These counts reflect plays already recorded by Jotify. '
                'They are not a complete annual Wrapped report. '
                'For exact yearly minutes and history, future playback sessions '
                'need timestamped event tracking.',
                style: TextStyle(color: Colors.white38, fontSize: 11,
                    height: 1.45),
              ),
            ],
          );
        },
      ),
    );
  }
}
