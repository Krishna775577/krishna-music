import 'package:blackhole/CustomWidgets/drawer.dart';
import 'package:blackhole/Screens/Settings/about.dart';
import 'package:blackhole/Screens/Settings/jotify_privacy.dart';
import 'package:blackhole/Screens/Library/spotify_library.dart';
import 'package:blackhole/Screens/Library/listening_insights.dart';
import 'package:blackhole/Screens/Library/jotify_smart_mixes.dart';
import 'package:blackhole/Screens/Settings/app_ui.dart';
import 'package:blackhole/Screens/Settings/backup_and_restore.dart';
import 'package:blackhole/Screens/Settings/download.dart';
import 'package:blackhole/Screens/Settings/music_playback.dart';
import 'package:blackhole/Screens/Settings/others.dart';
import 'package:blackhole/Screens/Settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A Jotify-branded, Spotify-style settings index. Every entry opens the
/// existing functioning settings screen; no simulated or non-working toggles.
class NewSettingsPage extends StatefulWidget {
  final Function? callback;
  const NewSettingsPage({super.key, this.callback});

  @override
  State<NewSettingsPage> createState() => _NewSettingsPageState();
}

class _NewSettingsPageState extends State<NewSettingsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Hive.box('settings');
    final name = settings.get('name', defaultValue: 'Jotify listener').toString();
    final sections = settings.get('sectionsToShow',
        defaultValue: ['Home', 'Search', 'Library', 'YouTube']) as List;
    final entries = <_SettingsEntry>[
      _SettingsEntry('Playback', 'Autoplay, repeat, language and audio quality',
          Icons.play_circle_outline_rounded,
          () => MusicPlaybackPage(callback: widget.callback),
          'playback audio music quality streaming wifi autoplay repeat cache region language'),
      _SettingsEntry('Downloads and storage',
          'Download quality, folders, offline files and lyrics',
          Icons.download_for_offline_outlined, () => const DownloadPage(),
          'downloads storage offline quality location filename lyrics'),
      _SettingsEntry('Appearance', 'Theme, dark mode, accent and AMOLED',
          Icons.palette_outlined,
          () => ThemePage(callback: widget.callback),
          'appearance theme dark light color accent amoled gradient'),
      _SettingsEntry('Content and display',
          'Player layout, mini player, home sections and tabs',
          Icons.dashboard_customize_outlined,
          () => AppUIPage(callback: widget.callback),
          'content display ui player mini navigation home layout tabs'),
      _SettingsEntry('App preferences',
          'Language, equalizer, lyrics, cache and other controls',
          Icons.tune_rounded, () => const OthersPage(),
          'app preferences language equalizer lyrics proxy cache folders search'),
      _SettingsEntry('Privacy & listening history',
        'Private Session, clear recent activity and reset statistics',
        Icons.privacy_tip_outlined, () => const JotifyPrivacyPage(),
        'private session privacy history security clear listening data'),
      _SettingsEntry('Organize Your Library',
        'Playlist folders, pins and sorting',
        Icons.folder_copy_outlined, () => const JotifyLibraryPlus(),
        'library folders pin playlist organize sorting'),
      _SettingsEntry('Made for you',
        'On Repeat, Rediscover and your Daily Mix',
        Icons.auto_awesome_rounded, () => const JotifySmartMixes(),
        'daily mix repeat rediscover personalize made for you'),
      _SettingsEntry('Listening insights',
        'Your top tracks, artists and recently played mix',
        Icons.insights_outlined, () => const JotifyListeningInsights(),
        'wrapped stats most played artists listening insights'),
      _SettingsEntry('Backup and restore',
          'Save, export and recover your Jotify library',
          Icons.cloud_upload_outlined, () => const BackupAndRestorePage(),
          'backup restore export import playlists library'),
      _SettingsEntry('About Jotify', 'Version, acknowledgements and support',
          Icons.info_outline_rounded, () => const AboutPage(),
          'about app version contact support credits'),
    ];
    final visible = entries.where((e) =>
        ('${e.title} ${e.subtitle} ${e.keywords}')
            .toLowerCase().contains(_query.toLowerCase().trim())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: const Color(0xFF121212),
        leading: sections.contains('Settings')
            ? homeDrawer(context: context,
                padding: const EdgeInsets.only(left: 15))
            : null,
        title: const Text('Settings and privacy',
            style: TextStyle(fontSize: 23,
                fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search settings',
                hintStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFFB3B3B3)),
                suffixIcon: _query.isEmpty ? null : IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
                filled: true,
                fillColor: const Color(0xFF282828),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_query.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFF1ED760),
                    child: Icon(Icons.person_rounded, size: 32,
                        color: Colors.black),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Your Jotify listening preferences',
                          style: TextStyle(color: Color(0xFFB3B3B3),
                              fontSize: 12)),
                    ],
                  )),
                ],
              ),
            ),
            const _SectionLabel('Your listening'),
          ],
          ...visible.take(2).map((e) => _tile(context, e)),
          if (_query.isEmpty) const _SectionLabel('App experience'),
          ...visible.skip(2).take(3).map((e) => _tile(context, e)),
          if (_query.isEmpty) const _SectionLabel('Your data and support'),
          ...visible.skip(5).map((e) => _tile(context, e)),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: Text('No matching settings',
                  style: TextStyle(color: Color(0xFFB3B3B3)))),
            ),
          if (_query.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Text('Made for listening. Powered by Jotify.',
                  style: TextStyle(color: Color(0xFF888888),
                      fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, _SettingsEntry item) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(20, 7, 20, 7),
      leading: SizedBox(
        width: 42, height: 42,
        child: Icon(item.icon, color: Colors.white, size: 27),
      ),
      title: Text(item.title,
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700, fontSize: 16)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(item.subtitle,
            style: const TextStyle(color: Color(0xFFB3B3B3),
                fontSize: 12, height: 1.4)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Color(0xFFB3B3B3)),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => item.page())),
    );
  }
}

class _SettingsEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() page;
  final String keywords;
  const _SettingsEntry(this.title, this.subtitle, this.icon,
      this.page, this.keywords);
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 9),
    child: Text(title.toUpperCase(),
        style: const TextStyle(color: Color(0xFFB3B3B3),
            fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
  );
}
