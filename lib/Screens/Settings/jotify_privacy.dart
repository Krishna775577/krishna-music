// Spotify-inspired privacy controls backed by Jotify's existing Hive boxes.
// Private Session stops future listening-history writes; it never silently
// deletes the user's existing music or playlists.
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class JotifyPrivacyPage extends StatelessWidget {
  const JotifyPrivacyPage({super.key});

  static const _accent = Color(0xFF1ED760);

  Future<void> _clearRecent(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear recent listening?'),
        content: const Text(
          'Your recently played list will be cleared. '
          'This does not delete downloaded songs or playlists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Hive.box('cache').put('recentSongs', <dynamic>[]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recently played history cleared')),
      );
    }
  }

  Future<void> _clearStats(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset your listening statistics?'),
        content: const Text(
          'This clears stored play counts and top artists/songs. '
          'It cannot be undone. Your playlists and music files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset statistics'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Hive.box('stats').clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listening statistics reset')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Hive.box('settings');
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Privacy & listening history',
          style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 50),
        children: [
          ValueListenableBuilder(
            valueListenable: settings.listenable(
                keys: ['jotifyPrivateSession']),
            builder: (context, Box box, _) {
              final enabled = box.get('jotifyPrivateSession',
                  defaultValue: false) == true;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: _accent,
                  title: const Text('Private Session',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700)),
                  subtitle: Text(enabled
                    ? 'ON: new listening activity stays out of your history.'
                    : 'OFF: Jotify tracks plays locally to personalize mixes.',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
                  secondary: Icon(
                    enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: _accent,
                  ),
                  value: enabled,
                  onChanged: (value) =>
                      box.put('jotifyPrivateSession', value),
                ),
              );
            },
          ),
          const SizedBox(height: 13),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Private Session pauses future play-count and recently-played '
              'updates on this device. Existing stats and playlists remain. '
              'It does not make remote music requests anonymous.',
              style: TextStyle(
                color: Colors.white54, fontSize: 12, height: 1.45),
            ),
          ),
          const SizedBox(height: 25),
          const Text('Your data on this device',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 19)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.history_rounded,
                color: Colors.white70),
            title: const Text('Clear recently played',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Keep your songs and playlists',
                style: TextStyle(color: Colors.white54)),
            onTap: () => _clearRecent(context),
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded,
                color: Colors.white70),
            title: const Text('Reset listening statistics',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Clear top songs and artists only',
                style: TextStyle(color: Colors.white54)),
            onTap: () => _clearStats(context),
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 14),
          const Text(
            'Jotify stores these preferences and listening counts in your '
            'local app data. Removing the app may erase this data unless '
            'you back it up first.',
            style: TextStyle(color: Colors.white38, fontSize: 12,
                height: 1.45),
          ),
        ],
      ),
    );
  }
}
