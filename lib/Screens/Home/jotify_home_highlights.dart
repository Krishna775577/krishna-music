// Jotify Home shortcuts using the user's existing library and listening
// history. No remote tracking or proprietary Spotify services.
import 'package:blackhole/Screens/Library/liked.dart';
import 'package:blackhole/Screens/Library/listening_insights.dart';
import 'package:blackhole/Screens/Library/jotify_smart_mixes.dart';
import 'package:blackhole/Screens/Library/spotify_library.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class JotifyHomeHighlights extends StatelessWidget {
  const JotifyHomeHighlights({super.key});

  static const _green = Color(0xFF1ED760);

  Widget _shortcut(BuildContext context, {
    required String name,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 154,
      child: Material(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Hive.box('settings');
    final cache = Hive.box('cache');
    return AnimatedBuilder(
      animation: Listenable.merge([
        settings.listenable(keys: ['jotifyPinnedPlaylists', 'playlistNames',
          'playlistDetails']),
        cache.listenable(keys: ['recentSongs']),
      ]),
      builder: (context, _) {
        final pinnedRaw = settings.get(
            'jotifyPinnedPlaylists', defaultValue: <String>[]);
        final pinned = pinnedRaw is List
            ? pinnedRaw.map((v) => v.toString()).toList()
            : <String>[];
        final existingRaw = settings.get('playlistNames',
            defaultValue: <String>['Favorite Songs']);
        final existing = existingRaw is List
            ? existingRaw.map((v) => v.toString()).toSet()
            : <String>{'Favorite Songs'};
        final detailsRaw = settings.get('playlistDetails',
            defaultValue: <String, dynamic>{});
        final details = detailsRaw is Map ? detailsRaw : <dynamic, dynamic>{};
        final recentRaw = cache.get('recentSongs', defaultValue: <dynamic>[]);
        final recent = recentRaw is List
            ? recentRaw.whereType<Map>().toList() : <Map>[];

        return Container(
          color: const Color(0xFF121212),
          padding: const EdgeInsets.only(top: 12, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text('Your quick picks',
                  style: TextStyle(
                    color: Colors.white, fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                height: 139,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _shortcut(context,
                      name: 'Liked Songs',
                      subtitle: 'Your favorites',
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFF6240B2),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LikedSongs(
                            playlistName: 'Favorite Songs',
                            showName: 'Liked Songs',
                          ))),
                    ),
                    const SizedBox(width: 10),
                    _shortcut(context,
                      name: 'Your Library',
                      subtitle: 'Folders & playlists',
                      icon: Icons.library_music_rounded,
                      color: const Color(0xFF315A44),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                              const JotifyLibraryPlus())),
                    ),
                    const SizedBox(width: 10),
                    _shortcut(context,
                      name: 'Your insights',
                      subtitle: 'Top songs & artists',
                      icon: Icons.auto_graph_rounded,
                      color: const Color(0xFF74448A),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                              const JotifyListeningInsights())),
                    ),
                    const SizedBox(width: 10),
                    _shortcut(context,
                      name: 'Made for you',
                      subtitle: 'Your mixes',
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFF8B5F2B),
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                          const JotifySmartMixes())),
                    ),
                    const SizedBox(width: 10),
                    _shortcut(context,
                      name: 'Recently played',
                      subtitle: 'Pick up the music',
                      icon: Icons.history_rounded,
                      color: const Color(0xFF455566),
                      onTap: () => Navigator.pushNamed(context, '/recent'),
                    ),
                    for (final id in pinned.where(existing.contains).take(5)) ...[
                      const SizedBox(width: 10),
                      _shortcut(context,
                        name: details[id] is Map &&
                            (details[id]['name'] ?? '').toString().isNotEmpty
                            ? details[id]['name'].toString() : id,
                        subtitle: 'Pinned playlist',
                        icon: Icons.push_pin_rounded,
                        color: const Color(0xFF2E6153),
                        onTap: () async {
                          await Hive.openBox(id);
                          if (!context.mounted) return;
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => LikedSongs(
                              playlistName: id,
                              showName: details[id] is Map
                                  ? (details[id]['name'] ?? id).toString()
                                  : id,
                            ),
                          ));
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (recent.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 19, 18, 9),
                  child: Row(children: [
                    const Expanded(child: Text('Back on repeat',
                      style: TextStyle(
                        color: Colors.white, fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    )),
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await PlayerInvoke.init(songsList: recent,
                            index: 0, shuffle: true, recommend: false);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text(
                                'Could not start the mix. Try a song instead.',
                              )),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.shuffle_rounded, size: 17),
                      label: const Text('Mix'),
                      style: TextButton.styleFrom(foregroundColor: _green),
                    ),
                  ]),
                ),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: recent.length > 6 ? 6 : recent.length,
                    itemBuilder: (context, index) {
                      final item = recent[index];
                      return SizedBox(
                        width: 210,
                        child: Material(
                          color: const Color(0xFF242424),
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () async {
                              try {
                                await PlayerInvoke.init(songsList: recent,
                                  index: index, recommend: false);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content:
                                      Text('Could not play this track')),
                                  );
                                }
                              }
                            },
                            child: Row(children: [
                              Container(
                                width: 67, height: 76,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF334B40),
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(9))),
                                child: const Icon(Icons.music_note_rounded,
                                    color: _green, size: 30),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((item['title'] ?? 'Music').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 5),
                                  Text((item['artist'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                                ],
                              )),
                              const SizedBox(width: 7),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
