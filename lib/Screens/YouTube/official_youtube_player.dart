/*
 * YouTube embedded playback integration for Krishna Music.
 * Original BlackHole-derived source remains subject to its original license.
 * This player uses the official YouTube iFrame player surface; it does not
 * extract audio or provide YouTube background/audio-only downloads.
 */
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class OfficialYouTubePlayerPage extends StatefulWidget {
  final String videoId;
  final String title;
  final String artist;

  const OfficialYouTubePlayerPage({
    super.key,
    required this.videoId,
    required this.title,
    this.artist = '',
  });

  @override
  State<OfficialYouTubePlayerPage> createState() =>
      _OfficialYouTubePlayerPageState();
}

class _OfficialYouTubePlayerPageState extends State<OfficialYouTubePlayerPage> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  Future<void> _openOfficialApp() async {
    final uri = Uri.https(
      'www.youtube.com', '/watch', <String, String>{'v': widget.videoId});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) => Scaffold(
        backgroundColor: const Color(0xFF171717),
        appBar: AppBar(
          title: const Text('Krishna Music • YouTube'),
          backgroundColor: const Color(0xFF171717),
        ),
        body: SafeArea(
          child: ListView(
            children: [
              player,
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
                child: Text(
                  widget.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.artist.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    widget.artist,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Tap Play in the YouTube player. Some videos may restrict '
                  'embedding; use the official YouTube app in that case.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _openOfficialApp,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in YouTube'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
