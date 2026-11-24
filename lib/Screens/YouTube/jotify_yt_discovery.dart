// Jotify V11 native song / playlist discovery. No Render dependency.
// API key stays in Android secure storage; official YouTube iframe plays video.
import 'dart:convert';
import 'package:blackhole/Services/jotify_native_youtube_overlay.dart';
import 'package:blackhole/Screens/YouTube/official_youtube_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class JotifyYTDiscovery extends StatefulWidget {
  const JotifyYTDiscovery({super.key});
  @override
  State<JotifyYTDiscovery> createState() => _JotifyYTDiscoveryState();
}

class _JotifyYTDiscoveryState extends State<JotifyYTDiscovery>
    with AutomaticKeepAliveClientMixin<JotifyYTDiscovery> {
  static const store = FlutterSecureStorage();
  static const keyName = 'jotify_v11_yt_api_key';
  final query = TextEditingController(), secret = TextEditingController();
  String? apiKey, error;
  bool busy = false, showKey = false;
  String filter = 'All';
  List<Map<String, String>> songs = [], lists = [];
  final Map<String, List<Map<String, String>>> cache = {};

  @override bool get wantKeepAlive => true;
  @override void initState() { super.initState(); _restore(); }
  Future<void> _restore() async {
    try {
      final key = await store.read(key: keyName);
      if (mounted) setState(() => apiKey = key);
    } catch (_) { if (mounted) setState(() => error = 'Secure storage unavailable'); }
  }
  Future<void> _save() async {
    final key = secret.text.trim();
    if(key.length < 25) {setState(() => error = 'Enter a valid API key'); return;}
    try {
      await store.write(key: keyName, value: key);
      if(!mounted)return;
      secret.clear();
      setState(() {apiKey = key; showKey = false; error = null;});
    } catch (_) {if(mounted)setState(() => error = 'Failed to save API key');}
  }
  Future<List<Map<String, String>>> _fetch(String q, String kind) async {
    final cacheId = kind + ':' + q.toLowerCase();
    if(cache.containsKey(cacheId))return cache[cacheId]!;
    final params = <String,String>{'part':'snippet','q':q,
      'type':kind == 'playlist' ? 'playlist' : 'video',
      'maxResults':'12','safeSearch':'moderate','key':apiKey!};
    if(kind == 'song')params['videoEmbeddable']='true';
    // Do not log request URI or Google raw errors (may include credentials).
    final res = await http.get(Uri.https('www.googleapis.com','/youtube/v3/search',params))
      .timeout(const Duration(seconds:15));
    if(res.statusCode != 200)throw StateError(
      res.statusCode == 403 || res.statusCode == 400
      ? 'Google denied this key or quota. Check YouTube Data API v3.'
      : 'YouTube search temporarily unavailable.');
    final parsed = jsonDecode(res.body);
    final out = <Map<String,String>>[];
    if(parsed is Map && parsed['items'] is List){
      for(final item in parsed['items'] as List){
        if(item is! Map || item['id'] is! Map || item['snippet'] is! Map)continue;
        final idMap=item['id'] as Map, detail=item['snippet'] as Map;
        final id=(idMap[kind == 'song'?'videoId':'playlistId']??'').toString();
        if(!(kind == 'song' ? RegExp(r'^[A-Za-z0-9_-]{11}$')
             : RegExp(r'^[A-Za-z0-9_-]{8,120}$')).hasMatch(id))continue;
        final pics=detail['thumbnails'];
        String image='';
        if(pics is Map){
          final p=pics['medium']??pics['default'];
          if(p is Map)image=(p['url']??'').toString();
        }
        out.add({'id':id,'kind':kind,'title':(detail['title']??'YouTube').toString(),
          'artist':(detail['channelTitle']??'YouTube').toString(),'image':image});
      }
    }
    if(cache.length>80)cache.clear();
    cache[cacheId]=out;
    return out;
  }
  Future<void> _search([String? value]) async {
    final q=(value??query.text).trim();
    if(q.length<2){setState(()=>error='Enter at least 2 characters');return;}
    if((apiKey??'').isEmpty){setState((){
      showKey=true;error='Save an API key to search directly from Android.';});return;}
    if(busy)return;
    query.text=q;
    setState(() {busy=true;error=null;});
    try{
      final r=await Future.wait([_fetch(q,'song'),_fetch(q,'playlist')]);
      if(mounted)setState(() {songs=r[0];lists=r[1];});
    }catch(e){if(mounted)setState(()=>error=e is StateError?e.message.toString():'Network error');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  KrishnaYoutubeTrack _track(Map<String,String> t)=>KrishnaYoutubeTrack(
    videoId:t['id']??'',title:t['title']??'YouTube',artist:t['artist']??'');
  Future<void> _open(Map<String,String> item,List<Map<String,String>> group)async{
    if(item['kind']=='song'){
      final queue=group.map(_track).toList();
      final i=queue.indexWhere((e)=>e.videoId==item['id']);
      JotifyNativeYTOverlay.show(context,queue,i);
      return;
    }
    setState(()=>busy=true);
    try{
      final resp=await http.get(Uri.https('www.googleapis.com','/youtube/v3/playlistItems',{
        'part':'snippet','playlistId':item['id']!,'maxResults':'25','key':apiKey!,
      })).timeout(const Duration(seconds:15));
      if(resp.statusCode != 200)throw StateError('Playlist not public or unavailable');
      final data=jsonDecode(resp.body);
      final queue=<KrishnaYoutubeTrack>[];
      if(data is Map && data['items'] is List){
        for(final v in data['items'] as List){
          if(v is! Map || v['snippet'] is! Map)continue;
          final sn=v['snippet'] as Map;
          if(sn['resourceId'] is! Map)continue;
          final id=((sn['resourceId'] as Map)['videoId']??'').toString();
          if(!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id))continue;
          queue.add(KrishnaYoutubeTrack(videoId:id,
            title:(sn['title']??'YouTube video').toString(),
            artist:(sn['videoOwnerChannelTitle']??item['artist']??'').toString()));
        }
      }
      if(queue.isEmpty)throw StateError('No playable videos in this public playlist');
      if(mounted)JotifyNativeYTOverlay.show(context,queue,0);
    }catch(e){if(mounted)setState(()=>error=e is StateError?e.message.toString():'Playlist unavailable');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override void dispose(){query.dispose();secret.dispose();super.dispose();}
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
          IconButton(icon:const Icon(Icons.settings_outlined,color:Colors.white),
            tooltip:'YouTube API key',onPressed:()=>setState(()=>showKey=!showKey)),
        ]),
        if(apiKey==null||showKey) Card(
          color:const Color(0xFF21342A),
          child:Padding(padding:const EdgeInsets.all(14),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('YouTube Search — No Render',style:TextStyle(
                color:Colors.white,fontWeight:FontWeight.bold)),
              const Text('Use a fresh YouTube Data API v3 key. It stays only in this phone.',
                style:TextStyle(color:Colors.white70,fontSize:12)),
              TextField(controller:secret,obscureText:true,
                style:const TextStyle(color:Colors.white),
                decoration:const InputDecoration(hintText:'Paste private API key')),
              ElevatedButton(onPressed:_save,child:const Text('Save key privately')),
          ]))),
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
