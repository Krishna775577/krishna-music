// Jotify V11 native YouTube watch/visible mini-player.
// Uses the official iframe plugin. No Render, extraction or hidden playback.
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:blackhole/Screens/YouTube/official_youtube_player.dart';

class JotifyNativeYTOverlay {
  static OverlayEntry? _entry;
  static final ValueNotifier<_WatchRequest?> _current = ValueNotifier(null);
  static final RegExp _videoId = RegExp(r'^[a-zA-Z0-9_-]{11}$');

  static void show(BuildContext context, List<KrishnaYoutubeTrack> tracks, int index) {
    final queue = tracks.where((t) => _videoId.hasMatch(t.videoId)).toList();
    if (queue.isEmpty) return;
    final i = index.clamp(0, queue.length-1).toInt();
    _current.value = _WatchRequest(queue, i);
    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => const _WatchOverlay());
      Overlay.of(context, rootOverlay: true).insert(_entry!);
    }
  }

  static void close() {
    _current.value = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }
}

class _WatchRequest {
  final List<KrishnaYoutubeTrack> tracks;
  final int index;
  const _WatchRequest(this.tracks, this.index);
}

class _WatchOverlay extends StatefulWidget {
  const _WatchOverlay();

  @override
  State<_WatchOverlay> createState() => _WatchOverlayState();
}

class _WatchOverlayState extends State<_WatchOverlay> {
  late YoutubePlayerController controller;
  late _WatchRequest request;
  bool expanded = true;

  KrishnaYoutubeTrack get track => request.tracks[request.index];

  @override
  void initState() {
    super.initState();
    request = JotifyNativeYTOverlay._current.value!;
    controller = YoutubePlayerController.fromVideoId(
      videoId: track.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true, showFullscreenButton: true, mute: false,
        loop: false, playsInline: true,
      ),
    );
    JotifyNativeYTOverlay._current.addListener(_onChange);
  }

  void _onChange() {
    final next = JotifyNativeYTOverlay._current.value;
    if(next == null || !mounted) return;
    if (next.tracks[next.index].videoId != track.videoId) {
      // Triggered by a user selecting a song or an Up Next video.
      controller.loadVideoById(videoId: next.tracks[next.index].videoId);
    }
    setState(() {request = next; expanded = true;});
  }

  void _change(int i) {
    if(i < 0 || i >= request.tracks.length) return;
    JotifyNativeYTOverlay._current.value = _WatchRequest(request.tracks, i);
  }

  @override
  void dispose() {
    JotifyNativeYTOverlay._current.removeListener(_onChange);
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 24).clamp(200.0, 360.0).toDouble();
    const green = Color(0xFF30E398);
    return YoutubePlayerScaffold(
      controller: controller,
      aspectRatio: 16/9,
      builder: (context, player) => Stack(children: [
        if(expanded)
          Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(.94))),
        Positioned(
          left: expanded ? 0 : null,
          right: expanded ? 0 : 12,
          top: expanded ? 0 : null,
          bottom: expanded ? 0 : 92,
          width: expanded ? null : width,
          child: Material(
            color: const Color(0xFF141B17),
            elevation: 18,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(expanded ? 0 : 13),
            child: Column(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Container(
                  height: 44, color: const Color(0xFF1C2B21),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(children: [
                    const Icon(Icons.smart_display_rounded,color:Colors.redAccent),
                    const SizedBox(width:8),
                    Expanded(child: Text(track.title,
                      maxLines:1,overflow:TextOverflow.ellipsis,
                      style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700))),
                    IconButton(
                      tooltip: expanded ? 'Minimize to Home' : 'Open video',
                      icon:Icon(expanded ? Icons.picture_in_picture_alt_rounded : Icons.open_in_full_rounded),
                      color:green,
                      onPressed:()=>setState(()=>expanded=!expanded),
                    ),
                    IconButton(
                      tooltip:'Stop video',
                      icon:const Icon(Icons.close_rounded),color:Colors.white70,
                      onPressed:JotifyNativeYTOverlay.close,
                    ),
                  ]),
                ),
                AspectRatio(aspectRatio:16/9,child:player),
                if(expanded)
                  Expanded(child: ListView(
                    padding:const EdgeInsets.all(18),
                    children:[
                      Text(track.title,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.bold)),
                      const SizedBox(height:6),
                      Text(track.artist,style:const TextStyle(color:Colors.white70)),
                      const SizedBox(height:20),
                      const Text('Up next',style:TextStyle(color:green,fontSize:17,fontWeight:FontWeight.bold)),
                      for(var i=0;i<request.tracks.length;i++)
                        ListTile(
                          selected:request.index==i,
                          title:Text(request.tracks[i].title,
                            maxLines:2,overflow:TextOverflow.ellipsis,
                            style:const TextStyle(color:Colors.white)),
                          subtitle:Text(request.tracks[i].artist,style:const TextStyle(color:Colors.white54)),
                          leading:Icon(i==request.index?Icons.equalizer_rounded:Icons.play_arrow,color:green),
                          onTap:()=>_change(i),
                        ),
                      const SizedBox(height:16),
                      const Text('Official YouTube player. Screen-lock audio/background-only YouTube playback is unavailable.',
                        style:TextStyle(color:Colors.white54,fontSize:12)),
                    ],
                  )),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
