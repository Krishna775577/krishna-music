import 'package:flutter_test/flutter_test.dart';
import 'package:blackhole/Services/youtube_embed_navigation.dart';

void main() {
  group('YouTube video ID parsing', () {
    test('accepts a direct 11-character video ID', () {
      expect(
        YouTubeEmbedNavigation.videoIdFrom(<String, String>{
          'videoId': 'dQw4w9WgXcQ',
        }),
        'dQw4w9WgXcQ',
      );
    });

    test('accepts supported YouTube share URLs', () {
      expect(
        YouTubeEmbedNavigation.videoIdFrom(<String, String>{
          'url': 'https://youtu.be/dQw4w9WgXcQ',
        }),
        'dQw4w9WgXcQ',
      );
    });

    test('rejects invalid and non-YouTube URLs', () {
      expect(
        YouTubeEmbedNavigation.videoIdFrom(<String, String>{
          'url': 'https://example.com/watch?v=dQw4w9WgXcQ',
        }),
        isNull,
      );
    });
  });
}
