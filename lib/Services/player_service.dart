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

import 'package:audio_service/audio_service.dart';
import 'package:blackhole/Helpers/mediaitem_converter.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

// ignore: avoid_classes_with_only_static_members
class PlayerInvoke {
  static final AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();

  static Future<void> init({
    required List songsList,
    required int index,
    bool fromMiniplayer = false,
    bool? isOffline,
    bool recommend = true,
    bool fromDownloads = false,
    bool shuffle = false,
    String? playlistBox,
  }) async {
    final int globalIndex = index < 0 ? 0 : index;
    bool? offline = isOffline;
    final List finalList = songsList.toList();
    if (shuffle) finalList.shuffle();
    if (offline == null) {
      // Decide from the selected item, not the previous playing item.
      // There might be no previously playing item on the first launch.
      final firstItem = finalList.isEmpty ? null : finalList[globalIndex];
      if (firstItem is Map) {
        final url = firstItem['url']?.toString() ?? '';
        offline = firstItem['genre'] != 'YouTube' &&
            !url.startsWith('http');
      } else {
        offline = true;
      }
    }

    if (!fromMiniplayer) {
      if (Platform.isIOS) {
        // Don't know why but it fixes the playback issue with iOS Side
        audioHandler.stop();
      }
      if (offline) {
        fromDownloads
            ? setDownValues(finalList, globalIndex)
            : (Platform.isWindows || Platform.isLinux)
                ? setOffDesktopValues(finalList, globalIndex)
                : setOffValues(finalList, globalIndex);
      } else {
        // Propagate failed stream resolution to the caller instead of
        // letting playback initialization silently finish.
        await setValues(
          finalList,
          globalIndex,
          recommend: recommend,
          // playlistBox: playlistBox,
        );
      }
    }
  }

  static Future<MediaItem> setTags(
    SongModel response,
    Directory tempDir,
  ) async {
    String playTitle = response.title;
    playTitle == ''
        ? playTitle = response.displayNameWOExt
        : playTitle = response.title;
    String playArtist = response.artist!;
    playArtist == '<unknown>'
        ? playArtist = 'Unknown'
        : playArtist = response.artist!;

    final String playAlbum = response.album!;
    final int playDuration = response.duration ?? 180000;
    final String imagePath = '${tempDir.path}/${response.displayNameWOExt}.png';

    final MediaItem tempDict = MediaItem(
      id: response.id.toString(),
      album: playAlbum,
      duration: Duration(milliseconds: playDuration),
      title: playTitle.split('(')[0],
      artist: playArtist,
      genre: response.genre,
      artUri: Uri.file(imagePath),
      extras: {
        'url': response.data,
        'date_added': response.dateAdded,
        'date_modified': response.dateModified,
        'size': response.size,
        'year': response.getMap['year'],
      },
    );
    return tempDict;
  }

  static void setOffDesktopValues(List response, int index) {
    getTemporaryDirectory().then((tempDir) async {
      final File file = File('${tempDir.path}/cover.jpg');
      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/cover.jpg');
        await file.writeAsBytes(
          byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      }
      final List<MediaItem> queue = [];
      queue.addAll(
        response.map(
          (song) => MediaItem(
            id: song['id'].toString(),
            album: song['album'].toString(),
            artist: song['artist'].toString(),
            duration: Duration(
              seconds: int.parse(
                (song['duration'] == null || song['duration'] == 'null')
                    ? '180'
                    : song['duration'].toString(),
              ),
            ),
            title: song['title'].toString(),
            artUri: Uri.file(file.path),
            genre: song['genre'].toString(),
            extras: {
              'url': song['path'].toString(),
              'subtitle': song['subtitle'],
              'quality': song['quality'],
            },
          ),
        ),
      );
      updateNplay(queue, index);
    });
  }

  static void setOffValues(List response, int index) {
    getTemporaryDirectory().then((tempDir) async {
      final File file = File('${tempDir.path}/cover.jpg');
      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/cover.jpg');
        await file.writeAsBytes(
          byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      }
      final List<MediaItem> queue = [];
      for (int i = 0; i < response.length; i++) {
        queue.add(
          await setTags(response[i] as SongModel, tempDir),
        );
      }
      updateNplay(queue, index);
    });
  }

  static void setDownValues(List response, int index) {
    final List<MediaItem> queue = [];
    queue.addAll(
      response.map(
        (song) => MediaItemConverter.downMapToMediaItem(song as Map),
      ),
    );
    updateNplay(queue, index);
  }

  static bool _isUsableStream(Map item) {
    final url = item['url']?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return false;
    }
    final expiry = int.tryParse(item['expire_at']?.toString() ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiry == 0 || expiry > now + 60;
  }

  static void _copyStream(Map target, Map source) {
    if (!_isUsableStream(source)) return;
    target['url'] = source['url'];
    if (source['duration'] != null) {
      target['duration'] = source['duration'];
    }
    if (source['expire_at'] != null) {
      target['expire_at'] = source['expire_at'];
    }
  }

  static Future<void> refreshYtLink(Map playItem) async {
    if (_isUsableStream(playItem)) return;
    final id = playItem['id']?.toString() ?? '';
    if (id.isEmpty) return;

    // Resolve the URL before adding the selected track to the player queue.
    // YtMusic metadata and YouTube stream extraction are both fallible.
    for (final useYtm in <bool>[true, false]) {
      try {
        final data = await YouTubeServices.instance
            .refreshLink(id, useYTM: useYtm)
            .timeout(const Duration(seconds: 16));
        if (data != null && _isUsableStream(data)) {
          _copyStream(playItem, data);
          return;
        }
      } catch (error, stack) {
        Logger.root.warning('YouTube stream lookup failed ($useYtm)',
            error, stack);
      }
    }
    Logger.root.warning('No usable YouTube stream for video $id');
  }

  static Future<void> setValues(
    List response,
    int index, {
    bool recommend = true,
    // String? playlistBox,
  }) async {
    if (response.isEmpty || index < 0 || index >= response.length) {
      throw StateError('Cannot play an empty or invalid song queue');
    }
    final List<MediaItem> queue = [];
    final Map playItem = response[index] as Map;
    if (playItem['genre'] == 'YouTube') {
      final work = <Future<void>>[refreshYtLink(playItem)];
      final nextIndex = index + 1;
      if (nextIndex < response.length) {
        final next = response[nextIndex] as Map;
        if (next['genre'] == 'YouTube') {
          // Resolving both URLs concurrently is faster than sequential calls
          // and avoids silently omitting a queued track with an expired URL.
          work.add(refreshYtLink(next));
        }
      }
      await Future.wait(work);
      if (!_isUsableStream(playItem)) {
        throw StateError('YouTube did not provide a playable audio URL');
      }
    }

    queue.addAll(
      response.map(
        (song) => MediaItemConverter.mapToMediaItem(
          song as Map,
          autoplay: recommend,
          // playlistBox: playlistBox,
        ),
      ),
    );
    await updateNplay(queue, index);
  }

  static Future<void> updateNplay(List<MediaItem> queue, int index) async {
    await audioHandler.updateQueue(queue);
    await audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
    await audioHandler.customAction('skipToMediaItem', {'index': index});
    await audioHandler.play();
    final String repeatMode =
        Hive.box('settings').get('repeatMode', defaultValue: 'None').toString();
    final bool enforceRepeat =
        Hive.box('settings').get('enforceRepeat', defaultValue: false) as bool;
    if (enforceRepeat) {
      switch (repeatMode) {
        case 'None':
          audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        case 'All':
          audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        case 'One':
          audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        default:
          break;
      }
    } else {
      audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
      Hive.box('settings').put('repeatMode', 'None');
    }
  }
}
