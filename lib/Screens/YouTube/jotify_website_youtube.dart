// Jotify YT: embed the same first-party web experience used by the
// Jotify website. The actual videos stay in the official, visible YouTube
// iframe on the trusted HTTPS origin; no audio extraction or hidden playback.
import 'package:blackhole/Screens/YouTube/jotify_yt_discovery.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JotifyWebsiteYouTube extends StatefulWidget {
  final String? videoId;
  final String? playlistId;
  final String? query;

  const JotifyWebsiteYouTube({
    super.key,
    this.videoId,
    this.playlistId,
    this.query,
  });

  @override
  State<JotifyWebsiteYouTube> createState() => _JotifyWebsiteYouTubeState();
}

class _JotifyWebsiteYouTubeState extends State<JotifyWebsiteYouTube>
    with AutomaticKeepAliveClientMixin<JotifyWebsiteYouTube> {
  static const String _host = 'jotify-web-online.onrender.com';
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  int _progress = 0;

  @override
  bool get wantKeepAlive => true;

  Uri _url() {
    final args = <String, String>{};
    if (widget.videoId != null &&
        RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(widget.videoId!)) {
      args['v'] = widget.videoId!;
    } else if (widget.playlistId != null &&
        RegExp(r'^[A-Za-z0-9_-]{8,120}$').hasMatch(widget.playlistId!)) {
      args['list'] = widget.playlistId!;
    } else if ((widget.query ?? '').trim().isNotEmpty) {
      args['q'] = widget.query!.trim();
    }
    return Uri.https(_host, '/yt.html', args);
  }

  @override
  void initState() {
    super.initState();
    // Android/iOS only. Other builds retain the existing Flutter discovery UI.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF090E0B))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onPageStarted: (_) {
            if (mounted) setState(() {
              _error = null;
              _loading = true;
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() {
              _loading = false;
              _progress = 100;
            });
          },
          onWebResourceError: (error) {
            // YouTube thumbnails or third-party subresources can fail without
            // breaking the page. Report failures of the main site only.
            if (error.isForMainFrame == false) return;
            if (mounted) setState(() {
              _loading = false;
              _error = 'Website could not load. Check your connection and retry.';
            });
          },
          onNavigationRequest: (request) {
            // Allow YouTube embedded frames but only our own website as a
            // top-level page. Never navigate to arbitrary external content.
            if (!request.isMainFrame) return NavigationDecision.navigate;
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                uri.scheme == 'https' &&
                uri.host == _host) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(_url());
  }

  void _retry() {
    setState(() {
      _error = null;
      _loading = true;
      _progress = 0;
    });
    _controller?.loadRequest(_url());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_controller == null) return const JotifyYTDiscovery();
    return ColoredBox(
      color: const Color(0xFF090E0B),
      child: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller!),
            if (_loading && _error == null)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  backgroundColor: const Color(0xFF1B2920),
                  color: const Color(0xFF1ED760),
                  minHeight: 3,
                ),
              ),
            if (_error != null)
              ColoredBox(
                color: const Color(0xFF090E0B),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white70,
                            size: 42),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Jotify YT'),
                        ),
                      ],
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
