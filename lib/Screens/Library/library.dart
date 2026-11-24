/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2023, Ankit Sangwan
 */

import 'dart:io';

import 'package:blackhole/CustomWidgets/drawer.dart';
import 'package:blackhole/Screens/Library/liked.dart';
import 'package:blackhole/Screens/LocalMusic/downed_songs.dart';
import 'package:blackhole/Screens/LocalMusic/downed_songs_desktop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool rotated = MediaQuery.sizeOf(context).height < screenWidth;
    return Container(
      color: const Color(0xFF121212),
      child: ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        AppBar(
          title: Text(
            AppLocalizations.of(context)!.library,
            style: TextStyle(
              color: Theme.of(context).iconTheme.color,
            ),
          ),
          centerTitle: false,
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: rotated ? null : homeDrawer(context: context),
          actions: [
            IconButton(
              tooltip: 'Create playlist',
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () => Navigator.pushNamed(context, '/playlists'),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Text('Your music, your way',
            style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14)),
        ),
        LibraryTile(
          title: AppLocalizations.of(context)!.nowPlaying,
          icon: Icons.queue_music_rounded,
          onTap: () {
            Navigator.pushNamed(context, '/nowplaying');
          },
        ),
        LibraryTile(
          title: AppLocalizations.of(context)!.lastSession,
          icon: Icons.history_rounded,
          onTap: () {
            Navigator.pushNamed(context, '/recent');
          },
        ),
        LibraryTile(
          title: AppLocalizations.of(context)!.favorites,
          icon: Icons.favorite_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LikedSongs(
                  playlistName: 'Favorite Songs',
                  showName: AppLocalizations.of(context)!.favSongs,
                ),
              ),
            );
          },
        ),
        LibraryTile(
          title: AppLocalizations.of(context)!.myMusic,
          icon: MdiIcons.folderMusic,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                        ? const DownloadedSongsDesktop()
                        : const DownloadedSongs(
                            showPlaylists: true,
                          ),
              ),
            );
          },
        ),
        LibraryTile(
          title: AppLocalizations.of(context)!.downs,
          icon: Icons.download_done_rounded,
          onTap: () {
            Navigator.pushNamed(context, '/downloads');
          },
        ),
        LibraryTile(
          title: AppLocalizations.of(context)!.playlists,
          icon: Icons.playlist_play_rounded,
          onTap: () {
            Navigator.pushNamed(context, '/playlists');
          },
        ),
        LibraryTile(
          title: AppLocalizations.of(context)!.stats,
          icon: Icons.auto_graph_rounded,
          onTap: () {
            Navigator.pushNamed(context, '/stats');
          },
        ),
      ],
    ),
    );
  }
}

class LibraryTile extends StatelessWidget {
  const LibraryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Text(title, style: const TextStyle(
        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!,
        style: const TextStyle(color: Color(0xFFB3B3B3))),
      leading: Container(
        height: 52, width: 52,
        decoration: BoxDecoration(
          color: icon == Icons.favorite_rounded
              ? const Color(0xFF5038A0) : const Color(0xFF282828),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: Colors.white, size: 27),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
        color: Color(0xFFB3B3B3)),
      onTap: onTap,
    );
  }
}
