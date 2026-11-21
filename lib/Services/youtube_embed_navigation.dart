/*
 * Shared navigation for YouTube and YouTube Music videos.
 * Keeps Saavn/local songs on the existing just_audio pipeline.
 */
import 'package:blackhole/Screens/YouTube/official_youtube_player.dart';
import 'package:flutter/material.dart';

class YouTubeEmbedNavigation {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static String? videoIdFrom(Map<dynamic, dynamic> item) {
    for (final field in ['videoId', 'video_id', 'id']) {
      final String candidate = (item[field] ?? '').toString().trim();
      if (_id.hasMatch(candidate)) return candidate;
    }
    for (final field in ['perma_url', 'permaUrl', 'url']) {
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

  static Future<void> openFromContext(
    BuildContext context, Map<dynamic, dynamic> item) async {
    final id = videoIdFrom(item);
    if (id == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('YouTube video ID not available')),
      );
      return;
    }
    final String title = (item['title'] ?? 'YouTube Video').toString();
    final String artist = (item['artist'] ?? item['subtitle'] ?? '').toString();
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => OfficialYouTubePlayerPage(
        videoId: id, title: title, artist: artist,
      ),
    ));
  }

  static Future<void> openGlobal(Map<dynamic, dynamic> item) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await openFromContext(context, item);
  }

  static bool isYoutubeSong(Map<dynamic, dynamic> item) {
    final String genre = (item['genre'] ?? '').toString().toLowerCase();
    final String language = (item['language'] ?? '').toString().toLowerCase();
    final String source = (item['source'] ?? '').toString().toLowerCase();
    return genre == 'youtube' || language == 'youtube' ||
        source == 'youtube' || source == 'ytmusic';
  }
}
