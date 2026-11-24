/*
 * Route YouTube and YouTube Music video entries to the supported in-app
 * embedded YouTube player; Saavn/local music remains on just_audio.
 */
import 'package:blackhole/Screens/YouTube/official_youtube_player.dart';
import 'package:blackhole/Services/jotify_native_youtube_overlay.dart';
import 'package:flutter/material.dart';

class YouTubeEmbedNavigation {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static String? videoIdFrom(Map<dynamic, dynamic> item) {
    for (final field in <String>['videoId', 'video_id', 'id']) {
      final String candidate = (item[field] ?? '').toString().trim();
      if (_id.hasMatch(candidate)) return candidate;
    }
    for (final field in <String>['perma_url', 'permaUrl', 'url']) {
      final String raw = (item[field] ?? '').toString().trim();
      final Uri? uri = Uri.tryParse(raw);
      if (uri == null) continue;
      final String host = uri.host.toLowerCase();
      if (!(host == 'youtube.com' || host.endsWith('.youtube.com') ||
          host == 'youtu.be')) continue;
      final String candidate = host == 'youtu.be'
          ? (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '')
          : (uri.queryParameters['v'] ??
              (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : ''));
      if (_id.hasMatch(candidate)) return candidate;
    }
    return null;
  }

  static KrishnaYoutubeTrack? _trackFrom(Map item) {
    final id = videoIdFrom(item);
    if (id == null) return null;
    return KrishnaYoutubeTrack(
      videoId: id,
      title: (item['title'] ?? 'YouTube video').toString(),
      artist: (item['artist'] ?? item['subtitle'] ?? '').toString(),
    );
  }

  static Future<void> openFromContext(
    BuildContext context,
    Map<dynamic, dynamic> item, {
    List? queue,
    int? initialIndex,
  }) async {
    final selected = _trackFrom(item);
    if (selected == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('YouTube video ID not available')),
      );
      return;
    }
    final List<KrishnaYoutubeTrack> tracks = <KrishnaYoutubeTrack>[];
    int selectedIndex = 0;
    if (queue != null) {
      for (int i = 0; i < queue.length; i++) {
        final entry = queue[i];
        if (entry is! Map) continue;
        final candidate = _trackFrom(entry);
        if (candidate == null) continue;
        if (initialIndex == i) selectedIndex = tracks.length;
        tracks.add(candidate);
      }
    }
    if (tracks.isEmpty ||
        !tracks.any((element) => element.videoId == selected.videoId)) {
      tracks.insert(0, selected);
      selectedIndex = 0;
    } else if (initialIndex == null ||
        tracks[selectedIndex].videoId != selected.videoId) {
      selectedIndex = tracks.indexWhere(
        (element) => element.videoId == selected.videoId,
      );
    }
    // V11: Insert persistent, VISIBLE official YouTube player in the root
    // overlay. Switching to Home does not destroy the WebView/player state.
    JotifyNativeYTOverlay.show(context, tracks, selectedIndex);
  }

  static Future<void> openGlobal(
    Map<dynamic, dynamic> item, {
    List? queue,
    int? initialIndex,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await openFromContext(
      context,
      item,
      queue: queue,
      initialIndex: initialIndex,
    );
  }

  static bool isYoutubeSong(Map<dynamic, dynamic> item) {
    final String genre = (item['genre'] ?? '').toString().toLowerCase();
    final String language = (item['language'] ?? '').toString().toLowerCase();
    final String source = (item['source'] ?? '').toString().toLowerCase();
    return genre == 'youtube' || language == 'youtube' ||
        source == 'youtube' || source == 'ytmusic';
  }
}
