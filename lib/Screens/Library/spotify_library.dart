// Jotify Library Plus — local playlist folders, pins, search and sorting.
// The original playlist boxes are never renamed, removed, or migrated here.
import 'package:blackhole/Screens/Library/liked.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class JotifyLibraryPlus extends StatefulWidget {
  const JotifyLibraryPlus({super.key});

  @override
  State<JotifyLibraryPlus> createState() => _JotifyLibraryPlusState();
}

class _JotifyLibraryPlusState extends State<JotifyLibraryPlus> {
  static const _accent = Color(0xFF1ED760);
  final Box _settings = Hive.box('settings');
  String _query = '';
  String _filter = 'All';
  String _sort = 'Recent';

  List<String> _stringList(dynamic source) =>
      source is List ? source.map((item) => item.toString()).toList() : <String>[];

  Map<String, String> _placements(dynamic source) {
    final out = <String, String>{};
    if (source is Map) {
      for (final entry in source.entries) {
        out[entry.key.toString()] = entry.value.toString();
      }
    }
    return out;
  }

  Map _details(dynamic source) => source is Map ? source : <dynamic, dynamic>{};

  String _title(String id, Map details) {
    final record = details[id];
    if (record is Map) {
      final title = (record['name'] ?? '').toString().trim();
      if (title.isNotEmpty) return title;
    }
    return id;
  }

  int? _count(String id, Map details) {
    final record = details[id];
    if (record is Map && record['count'] is num) {
      return (record['count'] as num).toInt();
    }
    return null;
  }

  Future<void> _folderDialog({String? current}) async {
    final controller = TextEditingController(text: current ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current == null ? 'New playlist folder' : 'Rename folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (text) => Navigator.pop(dialogContext, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    final clean = name.trim();
    if (clean.isEmpty || clean == 'All' || clean == 'Pinned' ||
        clean == 'Unsorted') return;
    final folders = _stringList(
        _settings.get('jotifyFolderNames', defaultValue: <String>[]));
    if (folders.any((item) =>
        item.toLowerCase() == clean.toLowerCase() && item != current)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This folder already exists')),
        );
      }
      return;
    }
    if (current == null) {
      folders.add(clean);
    } else {
      final index = folders.indexOf(current);
      if (index < 0) return;
      folders[index] = clean;
      final places = _placements(
          _settings.get('jotifyPlaylistFolders', defaultValue: <String, String>{}));
      for (final id in places.keys.toList()) {
        if (places[id] == current) places[id] = clean;
      }
      await _settings.put('jotifyPlaylistFolders', places);
      if (_filter == current) _filter = clean;
    }
    await _settings.put('jotifyFolderNames', folders);
    if (mounted) setState(() {});
  }

  Future<void> _deleteFolder(String folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $folder?'),
        content: const Text(
          'Only the folder will be deleted. All playlists and songs will stay safe in your library.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete folder')),
        ],
      ),
    );
    if (confirmed != true) return;
    final folders = _stringList(
        _settings.get('jotifyFolderNames', defaultValue: <String>[]))
      ..remove(folder);
    final map = _placements(_settings.get(
        'jotifyPlaylistFolders', defaultValue: <String, String>{}));
    map.removeWhere((_, value) => value == folder);
    await _settings.put('jotifyPlaylistFolders', map);
    await _settings.put('jotifyFolderNames', folders);
    if (mounted) setState(() => _filter = 'All');
  }

  Future<void> _move(String id, List<String> folders) async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF202020),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Move to folder',
                    style: TextStyle(color: Colors.white,
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined,
                    color: Colors.white70),
                title: const Text('Unsorted',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(sheetContext, '__root__'),
              ),
              ...folders.map((folder) => ListTile(
                leading: const Icon(Icons.folder_rounded, color: _accent),
                title: Text(folder, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(sheetContext, folder),
              )),
            ],
          ),
        ),
      ),
    );
    if (selection == null) return;
    final map = _placements(_settings.get(
        'jotifyPlaylistFolders', defaultValue: <String, String>{}));
    if (selection == '__root__') {
      map.remove(id);
    } else {
      map[id] = selection;
    }
    await _settings.put('jotifyPlaylistFolders', map);
  }

  Future<void> _pin(String id) async {
    final pinned = _stringList(
        _settings.get('jotifyPinnedPlaylists', defaultValue: <String>[]));
    if (pinned.contains(id)) {
      pinned.remove(id);
    } else {
      pinned.insert(0, id);
    }
    await _settings.put('jotifyPinnedPlaylists', pinned);
  }

  Widget _playlistTile(String id, Map details, List<String> pinned,
      List<String> folders, Map<String, String> places) {
    final label = _title(id, details);
    final count = _count(id, details);
    final isPinned = pinned.contains(id);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: id == 'Favorite Songs'
              ? const Color(0xFF5636A2) : const Color(0xFF262B29),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(id == 'Favorite Songs'
            ? Icons.favorite_rounded : Icons.library_music_rounded,
            color: Colors.white, size: 26),
      ),
      title: Text(label,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700)),
      subtitle: Text(
        [
          if (isPinned) 'Pinned',
          if (places[id] != null) places[id]!,
          if (count != null) '$count songs',
        ].join(' • ').isEmpty ? 'Playlist' :
        [
          if (isPinned) 'Pinned',
          if (places[id] != null) places[id]!,
          if (count != null) '$count songs',
        ].join(' • '),
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
      onTap: () async {
        await Hive.openBox(id);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => LikedSongs(playlistName: id, showName: label),
        ));
      },
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
        color: const Color(0xFF282828),
        onSelected: (action) {
          if (action == 'pin') _pin(id);
          if (action == 'folder') _move(id, folders);
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'pin',
            child: Row(children: [
              Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  color: Colors.white70),
              const SizedBox(width: 10),
              Text(isPinned ? 'Unpin playlist' : 'Pin playlist',
                  style: const TextStyle(color: Colors.white)),
            ]),
          ),
          const PopupMenuItem(
            value: 'folder',
            child: Row(children: [
              Icon(Icons.drive_file_move_outline, color: Colors.white70),
              SizedBox(width: 10),
              Text('Move to folder', style: TextStyle(color: Colors.white)),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Your Library',
            style: TextStyle(fontWeight: FontWeight.w800,
                color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Create playlist',
            onPressed: () => Navigator.pushNamed(context, '/playlists'),
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            tooltip: 'Create folder',
            onPressed: () => _folderDialog(),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _settings.listenable(),
        builder: (context, Box box, _) {
          final names = _stringList(box.get('playlistNames',
              defaultValue: <String>['Favorite Songs']));
          if (!names.contains('Favorite Songs')) {
            names.insert(0, 'Favorite Songs');
          }
          final folders = _stringList(box.get('jotifyFolderNames',
              defaultValue: <String>[]));
          final pinned = _stringList(box.get('jotifyPinnedPlaylists',
              defaultValue: <String>[]));
          final placements = _placements(box.get('jotifyPlaylistFolders',
              defaultValue: <String, String>{}));
          final details = _details(box.get('playlistDetails',
              defaultValue: <dynamic, dynamic>{}));
          var matches = names.where((id) {
            if (!_title(id, details).toLowerCase().contains(_query.toLowerCase())) {
              return false;
            }
            if (_filter == 'Pinned' && !pinned.contains(id)) return false;
            if (_filter == 'Unsorted' && placements[id] != null) return false;
            if (_filter != 'All' && _filter != 'Pinned' &&
                _filter != 'Unsorted' && placements[id] != _filter) {
              return false;
            }
            return true;
          }).toList();
          if (_sort == 'A–Z') {
            matches.sort((a, b) => _title(a, details).toLowerCase()
                .compareTo(_title(b, details).toLowerCase()));
          } else {
            matches = matches.reversed.toList();
          }
          matches.sort((a, b) =>
              (pinned.contains(b) ? 1 : 0) -
              (pinned.contains(a) ? 1 : 0));

          final filters = <String>['All', 'Pinned', 'Unsorted', ...folders];
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.white70),
                    hintText: 'Find in Your Library',
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              SizedBox(
                height: 43,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final category = filters[i];
                    return ChoiceChip(
                      label: Text(category),
                      selected: _filter == category,
                      onSelected: (_) => setState(() => _filter = category),
                      selectedColor: _accent,
                      backgroundColor: const Color(0xFF292929),
                      labelStyle: TextStyle(
                        color: _filter == category ? Colors.black : Colors.white,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.sort_rounded, color: Colors.white70, size: 21),
                const SizedBox(width: 7),
                PopupMenuButton<String>(
                  tooltip: 'Sort library',
                  color: const Color(0xFF282828),
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'Recent',
                        child: Text('Recently created')),
                    PopupMenuItem(value: 'A–Z',
                        child: Text('Alphabetical')),
                  ],
                  child: Row(children: [
                    Text(_sort, style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                    const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  ]),
                ),
                const Spacer(),
                Text('${matches.length} playlists',
                    style: const TextStyle(color: Colors.white54,
                        fontSize: 12)),
              ]),
              const SizedBox(height: 14),
              if (_filter != 'All' && _filter != 'Pinned' &&
                  _filter != 'Unsorted')
                Row(children: [
                  const Icon(Icons.folder_rounded, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_filter,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 18))),
                  IconButton(
                    tooltip: 'Rename folder',
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.white70),
                    onPressed: () => _folderDialog(current: _filter),
                  ),
                  IconButton(
                    tooltip: 'Delete folder only',
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.white70),
                    onPressed: () => _deleteFolder(_filter),
                  ),
                ]),
              if (matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text(
                    'No playlists here yet. Create a playlist or folder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  )),
                ),
              ...matches.map((id) => _playlistTile(
                id, details, pinned, folders, placements,
              )),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _folderDialog(),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Create playlist folder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/playlists'),
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Create, import or merge playlists'),
                style: TextButton.styleFrom(foregroundColor: _accent),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Folders and pins are saved on this device. '
                  'Deleting a folder never deletes its playlists.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
