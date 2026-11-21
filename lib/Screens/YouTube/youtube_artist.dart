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

import 'package:blackhole/CustomWidgets/bouncy_sliver_scroll_view.dart';
import 'package:blackhole/CustomWidgets/copy_clipboard.dart';
import 'package:blackhole/CustomWidgets/gradient_containers.dart';
import 'package:blackhole/CustomWidgets/image_card.dart';
import 'package:blackhole/CustomWidgets/song_tile_trailing_menu.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:blackhole/Services/yt_music.dart';
import 'package:blackhole/Services/youtube_embed_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logging/logging.dart';

class YouTubeArtist extends StatefulWidget {
  final String artistId;

  const YouTubeArtist({
    super.key,
    required this.artistId,
  });

  @override
  _YouTubeArtistState createState() => _YouTubeArtistState();
}

class _YouTubeArtistState extends State<YouTubeArtist> {
  bool status = false;
  Map<String, dynamic> data = {};
  bool fetched = false;
  bool done = true;
  final ScrollController _scrollController = ScrollController();
  String artistName = '';
  String artistSubtitle = '';
  String artistImage = '';
  List<Map> searchedList = [];

  String? loadError;

  @override
  void initState() {
    super.initState();
    _fetchArtist();
  }

  Future<void> _fetchArtist() async {
    if (!mounted) return;
    setState(() { fetched = false; loadError = null; });
    try {
      final Map response = await YtMusicService()
          .getArtistDetails(widget.artistId)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        data = Map<String, dynamic>.from(response);
        searchedList = (response['songs'] as List?)?.whereType<Map>().toList() ?? <Map>[];
        artistName = (response['name'] ?? '').toString();
        artistSubtitle = (response['subtitle'] ?? '').toString();
        final images = response['images'];
        artistImage = images is List && images.isNotEmpty
            ? images.last.toString() : '';
        fetched = true;
      });
    } catch (error, stack) {
      Logger.root.warning('YouTube artist details failed', error, stack);
      if (mounted) setState(() {
        fetched = true;
        loadError = 'Could not load this artist. Please retry.';
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext cntxt) {
    return GradientContainer(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            if (!fetched)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (loadError != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loadError!, textAlign: TextAlign.center),
                    TextButton.icon(
                      onPressed: _fetchArtist,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              BouncyImageSliverScrollView(
                scrollController: _scrollController,
                title: artistName,
                imageUrl: artistImage,
                fromYt: true,
                sliverList: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      if (searchedList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 20.0,
                            top: 5.0,
                            bottom: 5.0,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.songs,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.0,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ...searchedList.map(
                        (Map entry) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              left: 5.0,
                            ),
                            child: ListTile(
                              leading: imageCard(
                                imageUrl: entry['image'].toString(),
                              ),
                              title: Text(
                                entry['title'].toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onLongPress: () {
                                copyToClipboard(
                                  context: context,
                                  text: entry['title'].toString(),
                                );
                              },
                              subtitle: entry['subtitle'] == ''
                                  ? null
                                  : Text(
                                      entry['subtitle'].toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () async {
                                await YouTubeEmbedNavigation.openFromContext(
                                  context, entry,
                                  queue: searchedList,
                                  initialIndex: searchedList.indexOf(entry),
                                );
                                // for (var i = 0;
                                //     i < searchedList.length;
                                //     i++) {
                                //   YouTubeServices.instance
                                //       .formatVideo(
                                //     video: searchedList[i],
                                //     quality: Hive.box('settings')
                                //         .get(
                                //           'ytQuality',
                                //           defaultValue: 'Low',
                                //         )
                                //         .toString(),
                                //   )
                                //       .then((songMap) {
                                //     final MediaItem mediaItem =
                                //         MediaItemConverter.mapToMediaItem(
                                //       songMap!,
                                //     );
                                //     addToNowPlaying(
                                //       context: context,
                                //       mediaItem: mediaItem,
                                //       showNotification: false,
                                //     );
                                //   });
                                // }
                              },
                              trailing: YtSongTileTrailingMenu(data: entry),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            if (!done)
              Center(
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).width / 2,
                  width: MediaQuery.sizeOf(context).width / 2,
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GradientContainer(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.useHome,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.secondary,
                              ),
                              strokeWidth: 5,
                            ),
                            Text(
                              AppLocalizations.of(context)!.fetchingStream,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
