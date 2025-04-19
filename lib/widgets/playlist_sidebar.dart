// lib/widgets/playlist_sidebar.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';

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
  // --- State fields ---
  String _searchQuery = '';
  _SortOption _sortOption = _SortOption.name;

  List<Playlist> playlists = [];
  List<Playlist> _displayedPlaylists = [];

  int? editingPlaylistId;
  final TextEditingController editingController = TextEditingController();

  bool isCreatingNew = false;
  final TextEditingController newPlaylistController = TextEditingController();

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  @override
  void dispose() {
    editingController.dispose();
    newPlaylistController.dispose();
    super.dispose();
  }

  // --- Data loading & refresh ---
  Future<void> _fetchPlaylists() async {
    try {
      final pls = await PlaylistService.getPlaylists();
      if (!mounted) return;
      playlists = pls;
      _refreshDisplayList();
    } catch (e) {
      debugPrint('Error loading playlists: $e');
    }
  }

  void _refreshDisplayList() {
    // 1) sort master list based on selected option
    playlists.sort((a, b) {
      switch (_sortOption) {
        case _SortOption.name:
          return a.name.compareTo(b.name);
        case _SortOption.dateCreated:
          return a.createdAt.compareTo(b.createdAt);
      }
    });

    // 2) filter into displayed list
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

  // --- Search & Sort callbacks ---
  void _onSearchChanged(String query) {
    _searchQuery = query;
    _refreshDisplayList();
  }

  void _onSortChanged(_SortOption? opt) {
    if (opt != null) {
      _sortOption = opt;
      _refreshDisplayList();
    }
  }

  // --- CRUD operations ---
  Future<void> _renamePlaylist(int playlistId, String newName) async {
    await PlaylistService.renamePlaylist(playlistId, newName);
    await _fetchPlaylists();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Playlist renamed')));
  }

  Future<void> _deletePlaylist(int playlistId) async {
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
    if (!confirmed) return;

    await PlaylistService.deletePlaylist(playlistId);
    widget.onPlaylistSelected(null);
    await _fetchPlaylists();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Playlist deleted')));
  }

  Future<void> _createNewPlaylist(String name) async {
    await PlaylistService.createPlaylist(name);
    await _fetchPlaylists();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Playlist created')));
  }

  // --- UI builders ---
  Widget _buildPlaylistItem(Playlist pl) {
    final isEditing = editingPlaylistId == pl.id;
    return ListTile(
      key: ValueKey(pl.id),
      title:
          isEditing
              ? TextField(
                controller: editingController..text = pl.name,
                autofocus: true,
                onSubmitted: (val) {
                  final trimmed = val.trim();
                  if (trimmed.isNotEmpty && trimmed != pl.name) {
                    _renamePlaylist(pl.id, trimmed);
                  }
                  setState(() => editingPlaylistId = null);
                },
                onEditingComplete:
                    () => setState(() => editingPlaylistId = null),
              )
              : Text(pl.name),
      subtitle: Text(
        '${pl.createdAt.toLocal().toString().split(' ')[0]} • ${pl.trackCount} tracks',
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
          // --- 1) Search field ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Playlists',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // --- 2) Sort dropdown ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<_SortOption>(
              decoration: const InputDecoration(
                labelText: 'Sort by',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: _sortOption,
              items: const [
                DropdownMenuItem(value: _SortOption.name, child: Text('Name')),
                DropdownMenuItem(
                  value: _SortOption.dateCreated,
                  child: Text('Date Created'),
                ),
              ],
              onChanged: _onSortChanged,
            ),
          ),

          const Divider(),

          // --- 3) Playlist list ---
          Expanded(
            child: ListView(
              children: _displayedPlaylists.map(_buildPlaylistItem).toList(),
            ),
          ),

          const Divider(),

          // --- 4) Inline “new playlist” row or button ---
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
                      if (name.isNotEmpty) _createNewPlaylist(name);
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
                onPressed: () => setState(() => isCreatingNew = true),
                icon: const Icon(Icons.add),
                label: const Text('New Playlist'),
              ),
            ),
        ],
      ),
    );
  }
}
