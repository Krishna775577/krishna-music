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

import 'dart:async';
import 'dart:io';

import 'package:blackhole/APIs/api.dart';
import 'package:blackhole/CustomWidgets/download_button.dart';
import 'package:blackhole/CustomWidgets/empty_screen.dart';
import 'package:blackhole/CustomWidgets/gradient_containers.dart';
import 'package:blackhole/CustomWidgets/image_card.dart';
import 'package:blackhole/CustomWidgets/like_button.dart';
import 'package:blackhole/CustomWidgets/media_tile.dart';
import 'package:blackhole/CustomWidgets/search_bar.dart' as searchbar;
import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:blackhole/CustomWidgets/song_tile_trailing_menu.dart';
import 'package:blackhole/Helpers/extensions.dart';
import 'package:blackhole/Screens/Common/song_list.dart';
import 'package:blackhole/Screens/Common/song_list_view.dart';
import 'package:blackhole/Screens/Search/albums.dart';
import 'package:blackhole/Screens/Search/artists.dart';
import 'package:blackhole/Screens/YouTube/youtube_artist.dart';
import 'package:blackhole/Screens/YouTube/youtube_playlist.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:blackhole/Services/youtube_embed_navigation.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:blackhole/Services/yt_music.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchPage extends StatefulWidget {
  final String query;
  final bool fromHome;
  final bool fromDirectSearch;
  final String? searchType;
  final bool autofocus;
  const SearchPage({
    super.key,
    required this.query,
    this.fromHome = false,
    this.fromDirectSearch = false,
    this.searchType,
    this.autofocus = false,
  });

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String query = '';
  bool fetchResultCalled = false;
  bool fetched = false;
  bool alertShown = false;
  String? searchError;
  int _searchRequestId = 0;
  // bool albumFetched = false;
  bool? fromHome;
  List<Map<dynamic, dynamic>> searchedList = [];
  String searchType =
      Hive.box('settings').get('searchType', defaultValue: 'saavn').toString();
  List searchHistory =
      Hive.box('settings').get('search', defaultValue: []) as List;
  // bool showHistory =
  //     Hive.box('settings').get('showHistory', defaultValue: true) as bool;
  bool liveSearch =
      Hive.box('settings').get('liveSearch', defaultValue: true) as bool;
  final ValueNotifier<List<String>> topSearch = ValueNotifier<List<String>>(
    [],
  );

  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    _controller.text = widget.query;
    if (widget.searchType != null) {
      searchType = widget.searchType!;
    }
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Cache successful YouTube results briefly so going back to the same
  // search does not require another flaky network request.
  static final Map<String, List<Map>> _youtubeSearchCache = {};
  static final Map<String, DateTime> _youtubeCacheTime = {};

  // The unofficial YouTube search endpoint can intermittently return no
  // results. Retry a small number of times instead of making the user tap
  // Retry. No retry can guarantee success if YouTube blocks the client.
  Future<List<Map>> _fetchYouTubeWithRetry(String searchQuery) async {
    final String cacheKey = searchQuery.trim().toLowerCase();
    final DateTime? savedAt = _youtubeCacheTime[cacheKey];
    if (savedAt != null &&
        DateTime.now().difference(savedAt) < const Duration(minutes: 10) &&
        _youtubeSearchCache.containsKey(cacheKey)) {
      return _youtubeSearchCache[cacheKey]!;
    }

    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final List<Map> sections = await YouTubeServices.instance
            .fetchSearchResults(searchQuery)
            .timeout(const Duration(seconds: 9));
        final bool hasVideos = sections.any((section) {
          final items = section['items'];
          return items is List && items.isNotEmpty;
        });
        if (hasVideos) {
          _youtubeSearchCache[cacheKey] = sections;
          _youtubeCacheTime[cacheKey] = DateTime.now();
          return sections;
        }
        Logger.root.warning(
          'YouTube search returned no videos (attempt $attempt/$maxAttempts)',
        );
      } on TimeoutException catch (error, stack) {
        Logger.root.warning(
          'YouTube search timeout (attempt $attempt/$maxAttempts)',
          error,
          stack,
        );
      } catch (error, stack) {
        Logger.root.warning(
          'YouTube search error (attempt $attempt/$maxAttempts)',
          error,
          stack,
        );
      }
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 800 * attempt));
      }
    }
    return <Map>[];
  }

  bool _openingYoutubeSong = false;

  Future<void> _playYoutubeItem(Map item, {required bool preferYtMusic}) async {
    if (_openingYoutubeSong || !mounted) return;
    _openingYoutubeSong = true;
    try {
      // Both YtMusic and YouTube search results supply a video ID.
      // Do not call getSongData/formatVideoFromId here: signed direct stream
      // URLs were stalling at 00:00 even though metadata loaded correctly.
      await YouTubeEmbedNavigation.openFromContext(context, item);
    } catch (error, stack) {
      Logger.root.warning('Could not open embedded YouTube player', error, stack);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not open YouTube player')),
        );
      }
    } finally {
      _openingYoutubeSong = false;
    }
  }

  // Search requests can fail or hang when YouTube changes its endpoints.
  // Always finish the loading state and ignore outdated responses.
  Future<void> fetchResults() async {
    final int requestId = ++_searchRequestId;
    final String requestedType = searchType;
    final String requestedQuery =
        (query.isEmpty ? widget.query : query).trim();

    Logger.root.info('Searching $requestedType for $requestedQuery');

    List<Map<dynamic, dynamic>> results = [];
    String? failure;

    try {
      if (requestedQuery.isEmpty) {
        failure = 'Enter a song, artist, or video to search.';
      } else {
        switch (requestedType) {
          case 'ytm':
            // The unofficial YouTube Music parser sometimes returns a response
            // without the old English 'Songs' section. Never use firstWhere
            // without orElse; it used to leave the spinner on forever.
            try {
              final List<Map> ytmResults = await YtMusicService()
                  .search(requestedQuery)
                  .timeout(const Duration(seconds: 14));
              for (final section in ytmResults) {
                if (section['title'] == 'Songs') {
                  section['allowViewAll'] = true;
                }
              }
              results = ytmResults
                  .map((section) => Map<dynamic, dynamic>.from(section))
                  .toList();
            } catch (error, stack) {
              Logger.root.warning('YtMusic search failed', error, stack);
            }

            final bool hasYtmItems = results.any((section) {
              final items = section['items'];
              return items is List && items.isNotEmpty;
            });

            if (!hasYtmItems) {
              // Fallback is clearly labelled; it is YouTube video search,
              // NOT genuine YouTube Music search results.
              final List<Map> ytResults =
                  await _fetchYouTubeWithRetry(requestedQuery);
              results = ytResults
                  .map((section) => <dynamic, dynamic>{
                        ...section,
                        'title': 'YouTube videos (fallback)',
                        'allowViewAll': false,
                      })
                  .toList();
            }
            break;

          case 'yt':
            final List<Map> ytResults =
                await _fetchYouTubeWithRetry(requestedQuery);
            results = ytResults
                .map((section) => Map<dynamic, dynamic>.from(section))
                .toList();
            break;

          default:
            final List<Map<dynamic, dynamic>> saavnResults = await SaavnAPI()
                .fetchSearchResults(requestedQuery)
                .timeout(const Duration(seconds: 18));
            for (final section in saavnResults) {
              if (section['title'] != 'Top Result') {
                section['allowViewAll'] = true;
              }
            }
            results = saavnResults;
        }

        if ((requestedType == 'yt' || requestedType == 'ytm') &&
            !results.any((section) {
              final items = section['items'];
              return items is List && items.isNotEmpty;
            })) {
          results = [];
          failure = 'No YouTube results were returned. The service may be '
              'temporarily unavailable. Please try again.';
        }
      }
    } on TimeoutException catch (error, stack) {
      Logger.root.warning('Search timed out: $requestedType', error, stack);
      failure = 'Search timed out. Check your connection and tap Retry.';
    } catch (error, stack) {
      Logger.root.warning('Search failed: $requestedType', error, stack);
      failure = 'Could not load search results. Tap Retry to try again.';
    }

    if (!mounted || requestId != _searchRequestId ||
        requestedType != searchType) {
      return;
    }

    setState(() {
      searchedList = results;
      searchError = failure;
      fetched = true;
    });
  }

  Widget searchFailure(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 42),
            const SizedBox(height: 12),
            Text(
              searchError ?? 'No results found.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              onPressed: () {
                setState(() {
                  ++_searchRequestId;
                  fetched = false;
                  fetchResultCalled = false;
                  searchError = null;
                  searchedList = [];
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> getTrendingSearch() async {
    topSearch.value = await SaavnAPI().getTopSearches();
  }

  void addToHistory(String title) {
    final tempquery = title.trim();
    if (tempquery == '') {
      return;
    }
    final idx = searchHistory.indexOf(tempquery);
    if (idx != -1) {
      searchHistory.removeAt(idx);
    }
    searchHistory.insert(
      0,
      tempquery,
    );
    if (searchHistory.length > 10) {
      searchHistory = searchHistory.sublist(0, 10);
    }
    Hive.box('settings').put(
      'search',
      searchHistory,
    );
  }

  Widget nothingFound(BuildContext context) {
    if (!alertShown) {
      ShowSnackBar().showSnackBar(
        context,
        AppLocalizations.of(context)!.useVpn,
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          textColor: Theme.of(context).colorScheme.secondary,
          label: AppLocalizations.of(context)!.useProxy,
          onPressed: () {
            setState(() {
              Hive.box('settings').put('useProxy', true);
              fetched = false;
              fetchResultCalled = false;
              searchedList = [];
            });
          },
        ),
      );
      alertShown = true;
    }
    return emptyScreen(
      context,
      0,
      ':( ',
      100,
      AppLocalizations.of(context)!.sorry,
      60,
      AppLocalizations.of(context)!.resultsNotFound,
      20,
    );
  }

  @override
  Widget build(BuildContext context) {
    fromHome ??= widget.fromHome;
    if (!fetchResultCalled) {
      fetchResultCalled = true;
      fromHome! ? getTrendingSearch() : fetchResults();
    }
    return GradientContainer(
      child: SafeArea(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: searchbar.SearchBar(
            controller: _controller,
            liveSearch: liveSearch,
            autofocus: widget.autofocus,
            hintText: AppLocalizations.of(context)!.searchText,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if ((fromHome ?? false) || widget.fromDirectSearch) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    fromHome = true;
                    _controller.text = '';
                  });
                }
              },
            ),
            body: (fromHome!)
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 5.0,
                    ),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 65,
                        ),
                        Align(
                          alignment: Alignment.topLeft,
                          child: Wrap(
                            children: List<Widget>.generate(
                              searchHistory.length,
                              (int index) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.0,
                                    vertical: (Platform.isWindows ||
                                            Platform.isLinux ||
                                            Platform.isMacOS)
                                        ? 5.0
                                        : 0.0,
                                  ),
                                  child: GestureDetector(
                                    child: Chip(
                                      label: Text(
                                        searchHistory[index].toString(),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      onDeleted: () {
                                        setState(() {
                                          searchHistory.removeAt(index);
                                          Hive.box('settings').put(
                                            'search',
                                            searchHistory,
                                          );
                                        });
                                      },
                                    ),
                                    onTap: () {
                                      setState(
                                        () {
                                          fetched = false;
                                          query = searchHistory
                                              .removeAt(index)
                                              .toString()
                                              .trim();
                                          addToHistory(query);
                                          _controller.text = query;
                                          _controller.selection =
                                              TextSelection.fromPosition(
                                            TextPosition(
                                              offset: query.length,
                                            ),
                                          );
                                          fetchResultCalled = false;
                                          fromHome = false;
                                          searchedList = [];
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        ValueListenableBuilder(
                          valueListenable: topSearch,
                          builder: (
                            BuildContext context,
                            List<String> value,
                            Widget? child,
                          ) {
                            if (value.isEmpty) return const SizedBox();
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!
                                            .trendingSearch,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Wrap(
                                    children: List<Widget>.generate(
                                      value.length,
                                      (int index) {
                                        return Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 5.0,
                                            vertical: (Platform.isWindows ||
                                                    Platform.isLinux ||
                                                    Platform.isMacOS)
                                                ? 5.0
                                                : 0.0,
                                          ),
                                          child: ChoiceChip(
                                            label: Text(value[index]),
                                            selectedColor: Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withOpacity(0.2),
                                            labelStyle: TextStyle(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge!
                                                  .color,
                                              fontWeight: FontWeight.normal,
                                            ),
                                            selected: false,
                                            onSelected: (bool selected) {
                                              if (selected) {
                                                setState(
                                                  () {
                                                    fetched = false;
                                                    query = value[index].trim();
                                                    _controller.text = query;
                                                    _controller.selection =
                                                        TextSelection
                                                            .fromPosition(
                                                      TextPosition(
                                                        offset: query.length,
                                                      ),
                                                    );
                                                    addToHistory(query);
                                                    fetchResultCalled = false;
                                                    fromHome = false;
                                                    searchedList = [];
                                                  },
                                                );
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 70,
                          left: 15,
                        ),
                        child: (query.isEmpty && widget.query.isEmpty)
                            ? null
                            : Row(
                                children: getChoices(context, [
                                  {'label': 'Saavn', 'key': 'saavn'},
                                  {'label': 'YtMusic', 'key': 'ytm'},
                                  {'label': 'YouTube', 'key': 'yt'},
                                ]),
                              ),
                      ),
                      Expanded(
                        child: !fetched
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    if (searchType == 'yt' || searchType == 'ytm')
                                      const Padding(
                                        padding: EdgeInsets.only(top: 14),
                                        child: Text(
                                          'Searching... Automatically retrying if needed',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : (searchedList.isEmpty)
                                ? (searchError != null
                                    ? searchFailure(context)
                                    : nothingFound(context))
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5.0,
                                    ),
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      children: searchedList.map(
                                        (Map section) {
                                          final String title =
                                              section['title'].toString();
                                          final List? items =
                                              section['items'] as List?;

                                          if (items == null || items.isEmpty) {
                                            return const SizedBox();
                                          }
                                          return Column(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 17,
                                                  right: 15,
                                                  top: 15,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      title,
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondary,
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    if (section[
                                                            'allowViewAll'] ==
                                                        true)
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          GestureDetector(
                                                            onTap:
                                                                searchType !=
                                                                        'saavn'
                                                                    ? () {
                                                                        Navigator
                                                                            .push(
                                                                          context,
                                                                          PageRouteBuilder(
                                                                            opaque:
                                                                                false,
                                                                            pageBuilder: (
                                                                              _,
                                                                              __,
                                                                              ___,
                                                                            ) =>
                                                                                SongsListViewPage(
                                                                              onTap: (index, listItems) async {
                                                                                await _playYoutubeItem(
                                                                                  listItems[index] as Map,
                                                                                  preferYtMusic: true,
                                                                                );
                                                                              },
                                                                              title: title,
                                                                              subtitle: '\nShowing Search Results for',
                                                                              secondarySubtitle: '"${(query == '' ? widget.query : query).capitalize()}"',
                                                                              listItemsTitle: title,
                                                                              loadFunction: () {
                                                                                return YtMusicService().searchSongs(
                                                                                  query == '' ? widget.query : query,
                                                                                );
                                                                              },
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }
                                                                    : () {
                                                                        if (title == 'Albums' ||
                                                                            title ==
                                                                                'Playlists' ||
                                                                            title ==
                                                                                'Artists') {
                                                                          Navigator
                                                                              .push(
                                                                            context,
                                                                            PageRouteBuilder(
                                                                              opaque: false,
                                                                              pageBuilder: (
                                                                                _,
                                                                                __,
                                                                                ___,
                                                                              ) =>
                                                                                  AlbumSearchPage(
                                                                                query: query == '' ? widget.query : query,
                                                                                type: title,
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }
                                                                        if (title ==
                                                                            'Songs') {
                                                                          Navigator
                                                                              .push(
                                                                            context,
                                                                            PageRouteBuilder(
                                                                              opaque: false,
                                                                              pageBuilder: (
                                                                                _,
                                                                                __,
                                                                                ___,
                                                                              ) =>
                                                                                  SongsListPage(
                                                                                listItem: {
                                                                                  'id': query == '' ? widget.query : query,
                                                                                  'title': title,
                                                                                  'type': 'songs',
                                                                                },
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }
                                                                      },
                                                            child: Row(
                                                              children: [
                                                                Text(
                                                                  AppLocalizations
                                                                          .of(
                                                                    context,
                                                                  )!
                                                                      .viewAll,
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme
                                                                            .of(
                                                                      context,
                                                                    )
                                                                        .textTheme
                                                                        .bodySmall!
                                                                        .color,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                  ),
                                                                ),
                                                                Icon(
                                                                  Icons
                                                                      .chevron_right_rounded,
                                                                  color: Theme
                                                                          .of(
                                                                    context,
                                                                  )
                                                                      .textTheme
                                                                      .bodySmall!
                                                                      .color,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              ListView.builder(
                                                itemCount: items.length,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                shrinkWrap: true,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                ),
                                                itemBuilder: (context, index) {
                                                  final int count = items[index]
                                                          ['count'] as int? ??
                                                      0;
                                                  final itemType = items[index]
                                                              ['type']
                                                          ?.toString()
                                                          .toLowerCase() ??
                                                      'video';
                                                  String countText = '';
                                                  if (count >= 1) {
                                                    count > 1
                                                        ? countText =
                                                            '$count ${AppLocalizations.of(context)!.songs}'
                                                        : countText =
                                                            '$count ${AppLocalizations.of(context)!.song}';
                                                  }
                                                  return MediaTile(
                                                    title: items[index]['title']
                                                        .toString(),
                                                    subtitle: countText != ''
                                                        ? '$countText\n${items[index]["subtitle"]}'
                                                        : items[index]
                                                                ['subtitle']
                                                            .toString(),
                                                    isThreeLine:
                                                        countText != '',
                                                    leadingWidget: imageCard(
                                                      borderRadius:
                                                          title == 'Artists' ||
                                                                  itemType ==
                                                                      'artist'
                                                              ? 50.0
                                                              : 7.0,
                                                      placeholderImage:
                                                          AssetImage(
                                                        title == 'Artists' ||
                                                                itemType ==
                                                                    'artist'
                                                            ? 'assets/artist.png'
                                                            : title == 'Songs'
                                                                ? 'assets/cover.jpg'
                                                                : 'assets/album.png',
                                                      ),
                                                      imageUrl: items[index]
                                                              ['image']
                                                          .toString(),
                                                    ),
                                                    trailingWidget: searchType !=
                                                            'saavn'
                                                        ? ((itemType ==
                                                                    'song' ||
                                                                itemType ==
                                                                    'video')
                                                            ? YtSongTileTrailingMenu(
                                                                data:
                                                                    items[index]
                                                                        as Map,
                                                              )
                                                            : null)
                                                        : title != 'Albums'
                                                            ? title == 'Songs'
                                                                ? Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      DownloadButton(
                                                                        data: items[index]
                                                                            as Map,
                                                                        icon:
                                                                            'download',
                                                                      ),
                                                                      LikeButton(
                                                                        mediaItem:
                                                                            null,
                                                                        data: items[index]
                                                                            as Map,
                                                                      ),
                                                                      SongTileTrailingMenu(
                                                                        data: items[index]
                                                                            as Map,
                                                                      ),
                                                                    ],
                                                                  )
                                                                : null
                                                            : AlbumDownloadButton(
                                                                albumName: items[
                                                                            index]
                                                                        [
                                                                        'title']
                                                                    .toString(),
                                                                albumId: items[
                                                                            index]
                                                                        ['id']
                                                                    .toString(),
                                                              ),
                                                    onTap: searchType != 'saavn'
                                                        ? () async {
                                                            if (itemType ==
                                                                'artist') {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (context) =>
                                                                          YouTubeArtist(
                                                                    artistId: items[index]
                                                                            [
                                                                            'id']
                                                                        .toString(),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                            if (itemType ==
                                                                    'playlist' ||
                                                                itemType ==
                                                                    'album' ||
                                                                itemType ==
                                                                    'single') {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (context) =>
                                                                          YouTubePlaylist(
                                                                    playlistId: items[index]
                                                                            [
                                                                            'id']
                                                                        .toString(),
                                                                    type: itemType ==
                                                                                'album' ||
                                                                            itemType ==
                                                                                'single'
                                                                        ? 'album'
                                                                        : 'playlist',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                            if (itemType ==
                                                                    'song' ||
                                                                itemType ==
                                                                    'video') {
                                                              await _playYoutubeItem(
                                                                items[index] as Map,
                                                                preferYtMusic: itemType == 'song',
                                                              );
                                                            }
                                                          }
                                                        : () {
                                                            if (title ==
                                                                'Songs') {
                                                              PlayerInvoke.init(
                                                                songsList: [
                                                                  items[index],
                                                                ],
                                                                index: 0,
                                                                isOffline:
                                                                    false,
                                                              );
                                                            } else {
                                                              Navigator.push(
                                                                context,
                                                                PageRouteBuilder(
                                                                  opaque: false,
                                                                  pageBuilder: (
                                                                    _,
                                                                    __,
                                                                    ___,
                                                                  ) =>
                                                                      title == 'Artists' ||
                                                                              (title == 'Top Result' && items[0]['type'] == 'artist')
                                                                          ? ArtistSearchPage(
                                                                              data: items[index] as Map,
                                                                            )
                                                                          : SongsListPage(
                                                                              listItem: items[index] as Map,
                                                                            ),
                                                                ),
                                                              );
                                                            }
                                                          },
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      ).toList(),
                                    ),
                                  ),
                      ),
                    ],
                  ),
            onSubmitted: (String submittedQuery) {
              setState(
                () {
                  fetched = false;
                  fromHome = false;
                  fetchResultCalled = false;
                  query = submittedQuery;
                  _controller.text = submittedQuery;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(
                      offset: query.length,
                    ),
                  );
                  ++_searchRequestId;
                  searchError = null;
                  searchedList = [];
                },
              );
            },
            onQueryChanged: (changedQuery) {
              return YouTubeServices.instance
                  .getSearchSuggestions(query: changedQuery);
            },
          ),
        ),
      ),
    );
  }

  List<Widget> getChoices(
    BuildContext context,
    List<Map<String, String>> choices,
  ) {
    return choices.map((Map<String, String> element) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: ChoiceChip(
          label: Text(element['label']!),
          selectedColor:
              Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          labelStyle: TextStyle(
            color: searchType == element['key']
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).textTheme.bodyLarge!.color,
            fontWeight: searchType == element['key']
                ? FontWeight.w600
                : FontWeight.normal,
          ),
          selected: searchType == element['key'],
          onSelected: (bool selected) {
            if (selected) {
              ++_searchRequestId;
              searchType = element['key']!;
              fetched = false;
              searchError = null;
              searchedList = [];
              fetchResultCalled = false;
              Hive.box('settings').put('searchType', element['key']);
              if (element['key'] == 'ytm' || element['key'] == 'yt') {
                Hive.box('settings')
                    .put('searchYtMusic', element['key'] == 'ytm');
              }
              setState(() {});
            }
          },
        ),
      );
    }).toList();
  }
}
