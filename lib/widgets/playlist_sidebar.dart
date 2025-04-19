// lib/widgets/playlist_sidebar.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';

import '../models/playlist.dart';
import '../models/track.dart';
import '../services/playlist_service.dart';
import 'package:file_selector/file_selector.dart';

/// Sidebar that displays, searches, sorts, and manages playlists.
enum _SortOption { name, dateCreated }

class PlaylistSidebar extends StatefulWidget {
  /// Called when the user taps a playlist (or back to search via null).
  final void Function(Playlist?) onPlaylistSelected;

  const PlaylistSidebar({Key? key, required this.onPlaylistSelected})
    : super(key: key);

  @override
  _PlaylistSidebarState createState() => _PlaylistSidebarState();
}

class _PlaylistSidebarState extends State<PlaylistSidebar> {
  String _searchQuery = '';
  _SortOption _sortOption = _SortOption.name;

  List<Playlist> playlists = [];
  List<Playlist> _displayedPlaylists = [];

  int? editingPlaylistId;
  final TextEditingController editingController = TextEditingController();

  bool isCreatingNew = false;
  final TextEditingController newPlaylistController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  Future<void> _fetchPlaylists() async {
    final pls = await PlaylistService.getPlaylists();
    if (!mounted) return;
    playlists = pls;
    _refreshDisplayList();
  }

  void _refreshDisplayList() {
    playlists.sort((a, b) {
      switch (_sortOption) {
        case _SortOption.name:
          return a.name.compareTo(b.name);
        case _SortOption.dateCreated:
          return a.createdAt.compareTo(b.createdAt);
      }
    });
    if (_searchQuery.isEmpty) {
      _displayedPlaylists = List.from(playlists);
    } else {
      _displayedPlaylists =
          playlists
              .where(
                (pl) =>
                    pl.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();
    }
    setState(() {});
  }

  Future<void> _renamePlaylist(int id, String newName) async {
    await PlaylistService.renamePlaylist(id, newName);
    await _fetchPlaylists();
  }

  Future<void> _deletePlaylist(int id) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Delete Playlist'),
                content: const Text(
                  'Are you sure you want to delete this playlist?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }
    await PlaylistService.deletePlaylist(id);
    widget.onPlaylistSelected(null);
    await _fetchPlaylists();
  }

  /// Prompts the user to save a ZIP of all audio files in the playlist.
  Future<void> _downloadPlaylist(Playlist pl) async {
    // 1) Fetch the playlist entries
    final pts = await PlaylistService.getPlaylistTracks(pl.id);

    // 2) Create the ZIP in a temporary file
    final tempDir = Directory.systemTemp;
    final tempZip = File(p.join(tempDir.path, '${pl.name}.zip'));
    final encoder = ZipFileEncoder()..create(tempZip.path);

    // 3) Add each existing audio file to the zip
    for (var pt in pts) {
      final t = Track(
        id: pt.trackId,
        favourited: 0,
        publisher: '',
        library: pt.library,
        cdTitle: pt.cdTitle,
        composer: '',
        title: pt.title,
        description: '',
        version: '',
        filename: pt.filename,
        releasedAt: 0,
        number: 0,
        cdDescription: '',
        duration: pt.duration,
        bpm: 0,
        priority: 0,
        keywords: '',
        isChild: 0,
        parent: 0,
        mood: 0,
        solo: 0,
        vocal: 0,
        featured: 0,
        lyric: '',
      );
      final file = File(t.audioPath);
      if (await file.exists()) {
        encoder.addFile(file);
      }
    }
    encoder.close();

    // 4) Prompt user for save location
    final saveLocation = await getSaveLocation(
      suggestedName: '${pl.name}.zip',
      acceptedTypeGroups: [
        XTypeGroup(label: 'ZIP Archive', extensions: ['zip']),
      ],
    );
    if (saveLocation != null) {
      try {
        await tempZip.copy(saveLocation.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist saved to ${saveLocation.path}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving ZIP: $e')));
      }
    }

    // 5) Clean up the temporary ZIP file
    if (await tempZip.exists()) {
      await tempZip.delete();
    }
  }

  Widget _buildItem(Playlist pl) {
    final isEditing = editingPlaylistId == pl.id;
    return ListTile(
      key: ValueKey(pl.id),
      title:
          isEditing
              ? TextField(
                controller: editingController..text = pl.name,
                autofocus: true,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    _renamePlaylist(pl.id, v.trim());
                  }
                  setState(() => editingPlaylistId = null);
                },
              )
              : Text(pl.name),
      subtitle: Text(
        '${pl.createdAt.toLocal().toIso8601String().split('T')[0]} • ${pl.trackCount} tracks',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename',
            onPressed: () {
              setState(() {
                editingPlaylistId = pl.id;
                editingController.text = pl.name;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.archive),
            tooltip: 'Download as ZIP',
            onPressed: () => _downloadPlaylist(pl),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: () => _deletePlaylist(pl.id),
          ),
        ],
      ),
      onTap: () => widget.onPlaylistSelected(pl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Playlists',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                _searchQuery = v;
                _refreshDisplayList();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<_SortOption>(
              decoration: const InputDecoration(
                labelText: 'Sort by',
                border: OutlineInputBorder(),
              ),
              value: _sortOption,
              items: const [
                DropdownMenuItem(value: _SortOption.name, child: Text('Name')),
                DropdownMenuItem(
                  value: _SortOption.dateCreated,
                  child: Text('Date Created'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  _sortOption = v;
                  _refreshDisplayList();
                }
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: _displayedPlaylists.map(_buildItem).toList(),
            ),
          ),
          const Divider(),
          if (isCreatingNew)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newPlaylistController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'New Playlist',
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final name = newPlaylistController.text.trim();
                      if (name.isNotEmpty) {
                        PlaylistService.createPlaylist(
                          name,
                        ).then((_) => _fetchPlaylists());
                      }
                      setState(() {
                        isCreatingNew = false;
                        newPlaylistController.clear();
                      });
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New Playlist'),
                onPressed: () => setState(() => isCreatingNew = true),
              ),
            ),
        ],
      ),
    );
  }
}
