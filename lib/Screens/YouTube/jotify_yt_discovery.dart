// Jotify V11 native song / playlist discovery. No Render dependency.
// API key stays in Android secure storage; official YouTube iframe plays video.
import 'dart:convert';
import 'package:blackhole/Services/jotify_native_youtube_overlay.dart';
import 'package:blackhole/Screens/YouTube/official_youtube_player.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class JotifyYTDiscovery extends StatefulWidget {
  const JotifyYTDiscovery({super.key});
  @override
  State<JotifyYTDiscovery> createState() => _JotifyYTDiscoveryState();
}

class _JotifyYTDiscoveryState extends State<JotifyYTDiscovery>
    with AutomaticKeepAliveClientMixin<JotifyYTDiscovery> {
  static const String _configUrl =
    'https://raw.githubusercontent.com/Krishna775577/krishna-music/main/jotify-config.json';
  static const String _buildUrl =
    String.fromEnvironment('JOTIFY_YT_API_BASE', defaultValue: '');
  final query = TextEditingController();
  String? error;
  bool busy = false;
  String filter = 'All';
  Uri? _base;
  List<Map<String, String>> songs = [], lists = [];
  final Map<String, List<Map<String, String>>> cache = {};
  @override bool get wantKeepAlive => true;

  Future<Uri> _api() async {
    if (_base != null) return _base!;
    String address = _buildUrl.trim();
    if (address.isEmpty) {
      http.Response config;
      try {
        config = await http.get(Uri.parse(_configUrl),
          headers: {'Accept':'application/json'}).timeout(const Duration(seconds:8));
      } catch (_) {
        throw StateError('YT service configuration unavailable. Try again.');
      }
      if (config.statusCode != 200) throw StateError('YT service configuration unavailable.');
      try {
        final body = jsonDecode(config.body);
        if(body is Map) address = (body['youtubeApiBase'] ?? '').toString().trim();
      } catch (_) { throw StateError('YT service configuration is invalid.'); }
    }
    final uri = Uri.tryParse(address);
    if(uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw StateError('YT shared search is awaiting owner activation.');
    }
    _base = uri;
    return uri;
  }
  Future<Uri> _route(String path, Map<String,String> params) async =>
      (await _api()).replace(path:path,queryParameters:params);

  String _errorFor(http.Response response) {
    if(response.statusCode == 429) return 'YouTube quota or rate limit reached. Try later.';
    if(response.statusCode == 503) return 'YT shared service not ready. Owner setup may be pending.';
    try {
      final body = jsonDecode(response.body);
      if(body is Map && body['error'] is String) return (body['error'] as String).substring(
        0,(body['error'] as String).length.clamp(0,160).toInt());
    } catch (_) {}
    return 'YouTube search unavailable (' + response.statusCode.toString() + ').';
  }

  Future<List<Map<String, String>>> _fetch(String q, String kind) async {
    final cacheId = kind + ':' + q.toLowerCase();
    if(cache.containsKey(cacheId)) return cache[cacheId]!;
    final uri = await _route('/api/yt/search', {'kind':kind,'q':q});
    final res = await http.get(uri).timeout(const Duration(seconds:15));
    if(res.statusCode != 200) throw StateError(_errorFor(res));
    final body = jsonDecode(res.body);
    final out = <Map<String,String>>[];
    if(body is! Map || body['status'] != 'ok' || body['items'] is! List) {
      throw StateError('YT returned an invalid response.');
    }
    for(final item in body['items'] as List){
      if(item is! Map)continue;
      final id=(item['id']??'').toString();
      if(!(kind=='song'?RegExp(r'^[A-Za-z0-9_-]{11}$'):RegExp(r'^[A-Za-z0-9_-]{8,120}$')).hasMatch(id))continue;
      out.add({'id':id,'kind':kind,
        'title':(item['title']??'YouTube').toString(),
        'artist':(item['channel']??'YouTube').toString(),
        'image':(item['thumbnail']??'').toString()});
    }
    if(cache.length>80)cache.clear();
    cache[cacheId]=out;
    return out;
  }

  Future<void> _search([String? value]) async {
    final q=(value??query.text).trim();
    if(q.length<2){setState(()=>error='Enter at least 2 characters');return;}
    if(busy)return;
    query.text=q;
    setState((){busy=true;error=null;});
    try{
      final r=await Future.wait([_fetch(q,'song'),_fetch(q,'playlist')]);
      if(mounted)setState((){songs=r[0];lists=r[1];});
    }catch(e){
      if(mounted)setState(()=>error=e is StateError?e.message.toString():'Network error. Try again.');
    }finally{if(mounted)setState(()=>busy=false);}
  }
  KrishnaYoutubeTrack _track(Map<String,String> t)=>KrishnaYoutubeTrack(
    videoId:t['id']??'',title:t['title']??'YouTube',artist:t['artist']??'');
  Future<void> _open(Map<String,String> item,List<Map<String,String>> group) async {
    if(item['kind']=='song'){
      final queue=group.map(_track).toList();
      final index=queue.indexWhere((e)=>e.videoId==item['id']);
      JotifyNativeYTOverlay.show(context,queue,index);
      return;
    }
    setState(()=>busy=true);
    try{
      final uri=await _route('/api/yt/playlist',{'list':item['id']!});
      final res=await http.get(uri).timeout(const Duration(seconds:15));
      if(res.statusCode!=200)throw StateError(_errorFor(res));
      final data=jsonDecode(res.body);
      final queue=<KrishnaYoutubeTrack>[];
      if(data is Map && data['status']=='ok' && data['items'] is List){
        for(final row in data['items'] as List){
          if(row is! Map)continue;
          final id=(row['id']??'').toString();
          if(!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id))continue;
          queue.add(KrishnaYoutubeTrack(videoId:id,
            title:(row['title']??'YouTube video').toString(),
            artist:(row['channel']??'YouTube').toString()));
        }
      }
      if(queue.isEmpty)throw StateError('No playable public videos found.');
      if(mounted)JotifyNativeYTOverlay.show(context,queue,0);
    }catch(e){
      if(mounted)setState(()=>error=e is StateError?e.message.toString():'Playlist unavailable');
    }finally{if(mounted)setState(()=>busy=false);}
  }
  @override void dispose(){query.dispose();super.dispose();}
  Widget _card(Map<String,String> t,List<Map<String,String>> group)=>Card(
    color:const Color(0xFF1B2921),
    child:ListTile(
      leading:SizedBox(width:72,height:56,child:(t['image']??'').startsWith('https://')
        ?Image.network(t['image']!,fit:BoxFit.cover,
           errorBuilder:(_,__,___)=>const Icon(Icons.music_video))
        :const Icon(Icons.music_video)),
      title:Text(t['title']??'',maxLines:2,overflow:TextOverflow.ellipsis,
        style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
      subtitle:Text(t['artist']??'',maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(color:Colors.white60)),
      trailing:Icon(t['kind']=='playlist'?Icons.queue_music:Icons.play_circle_fill_rounded,
        color:const Color(0xFF30E398)),
      onTap:busy?null:()=>_open(t,group),
    ),
  );
  @override Widget build(BuildContext context){
    super.build(context);
    return ColoredBox(color:const Color(0xFF101719),child:SafeArea(
      child:ListView(padding:const EdgeInsets.fromLTRB(14,18,14,25),children:[
        Row(children:[
          const Icon(Icons.smart_display_rounded,color:Colors.redAccent,size:28),
          const SizedBox(width:10),
          const Expanded(child:Text('YT · Jotify',style:TextStyle(color:Colors.white,
            fontSize:25,fontWeight:FontWeight.w800))),
          const Icon(Icons.verified_user_outlined,color:Color(0xFF30E398)),
        ]),
        const Padding(
          padding:EdgeInsets.only(top:8),
          child:Text('Shared YouTube search · No API key needed · No Render',
            style:TextStyle(color:Colors.white70,fontSize:12)),
        ),
        const SizedBox(height:12),
        TextField(controller:query,style:const TextStyle(color:Colors.white),
          onSubmitted:_search,
          decoration:InputDecoration(
            hintText:'Search Radhe Radhe, Tum Mere, playlists...',
            prefixIcon:const Icon(Icons.search),
            suffixIcon:IconButton(icon:const Icon(Icons.arrow_forward),
              onPressed:busy?null:()=>_search()),
            filled:true,fillColor:const Color(0xFF26382E),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)))),
        const SizedBox(height:12),
        Wrap(spacing:8,children:[
          for(final opt in ['All','Songs','Playlists'])
            ChoiceChip(label:Text(opt),selected:filter==opt,
              onSelected:(_)=>setState(()=>filter=opt)),
        ]),
        if(busy)const Padding(padding:EdgeInsets.all(12),
          child:LinearProgressIndicator()),
        if(error!=null)Padding(padding:const EdgeInsets.all(12),
          child:Text(error!,style:const TextStyle(color:Colors.orangeAccent))),
        if(songs.isEmpty&&lists.isEmpty&&!busy) ...[
          const Text('Search songs, videos or public playlists.',
            style:TextStyle(color:Colors.white70)),
          Wrap(spacing:8,children:[
            for(final q in ['Radhe Radhe','Tum Mere','Krishna Bhajan'])
              ActionChip(label:Text(q),onPressed:()=>_search(q)),
          ]),
        ],
        if(filter!='Playlists'&&songs.isNotEmpty)...[
          const Padding(padding:EdgeInsets.all(8),child:Text('Songs & Videos',
            style:TextStyle(color:Colors.white,fontSize:19))),
          for(final t in songs)_card(t,songs),
        ],
        if(filter!='Songs'&&lists.isNotEmpty)...[
          const Padding(padding:EdgeInsets.all(8),child:Text('Playlists',
            style:TextStyle(color:Colors.white,fontSize:19))),
          for(final t in lists)_card(t,lists),
        ],
        const SizedBox(height:20),
        const Text('Official YouTube player. No hidden video, background-only playback or screen-lock audio.',
          style:TextStyle(color:Colors.white54,fontSize:12)),
      ]),
    ));
  }
}
