// lib/widgets/playlist_sidebar.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';

enum _SortOption { name, dateCreated }

/// Sidebar that displays and manages playlists.
class PlaylistSidebar extends StatefulWidget {
  /// Callback when a playlist is selected (or null to return to search).
  final void Function(Playlist?) onPlaylistSelected;

  const PlaylistSidebar({Key? key, required this.onPlaylistSelected})
    : super(key: key);

  @override
  _PlaylistSidebarState createState() => _PlaylistSidebarState();
}

class _PlaylistSidebarState extends State<PlaylistSidebar> {
  String _searchQuery = '';
  List<Playlist> _displayedPlaylists = [];

  final _SortOption _sortOption = _SortOption.name;
  List<Playlist> playlists = [];
  int? editingPlaylistId;
  final TextEditingController editingController = TextEditingController();
  bool isCreatingNew = false;
  final TextEditingController newPlaylistController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchPlaylists();
  }

  Future<void> fetchPlaylists() async {
    try {
      final pls = await PlaylistService.getPlaylists();
      if (!mounted) return;
      setState(() {
        playlists = pls;
        _displayedPlaylists = List.from(pls);
        _sortPlaylists(); // ← NEW
      });
    } catch (e) {
      debugPrint('Error loading playlists: $e');
    }
  }

  void _sortPlaylists() {
    playlists.sort((a, b) {
      switch (_sortOption) {
        case _SortOption.name:
          return a.name.compareTo(b.name);
        case _SortOption.dateCreated:
          return a.createdAt.compareTo(b.createdAt);
      }
    });
  }

  void _filterPlaylists(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _displayedPlaylists = List.from(playlists);
    } else {
      _displayedPlaylists =
          playlists
              .where(
                (pl) => pl.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    }
    setState(() {});
  }

  Future<void> _renamePlaylist(int playlistId, String newName) async {
    await PlaylistService.renamePlaylist(playlistId, newName);
    await fetchPlaylists();
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
              (context) => AlertDialog(
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
    if (confirmed) {
      await PlaylistService.deletePlaylist(playlistId);
      await fetchPlaylists();
      widget.onPlaylistSelected(null);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Playlist deleted')));
    }
  }

  Future<void> _createNewPlaylist(String name) async {
    try {
      await PlaylistService.createPlaylist(name);
      await fetchPlaylists(); // Refresh the playlist list after creation.
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Playlist created')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating playlist: $e')));
    }
  }

  Widget _buildPlaylistItem(BuildContext context, int index, Playlist pl) {
    final pl = playlists[index];
    final isEditing = editingPlaylistId == pl.id;

    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      key: ValueKey(pl.id),
      title:
          isEditing
              ? TextField(
                controller: editingController..text = pl.name,
                autofocus: true,
                onSubmitted: (value) {
                  final newName = value.trim();
                  if (newName.isNotEmpty && newName != pl.name) {
                    _renamePlaylist(pl.id, newName);
                  }
                  setState(() => editingPlaylistId = null);
                },
                onEditingComplete: () {
                  setState(() => editingPlaylistId = null);
                },
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
          // 1) Search field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Playlists',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterPlaylists,
            ),
          ),

          // 2) The (filtered) playlist list
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              // only allow reordering when not filtered

              // must always supply a void Function(int,int)
              onReorder: (int oldIndex, int newIndex) {
                // only do anything when not filtered
                if (_searchQuery.isEmpty) {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = playlists.removeAt(oldIndex);
                  playlists.insert(newIndex, item);
                  setState(() {});
                  PlaylistService.updatePlaylistOrdering(playlists);
                }
              },
              children: [
                for (int i = 0; i < _displayedPlaylists.length; i++)
                  _buildPlaylistItem(context, i, _displayedPlaylists[i]),
              ],
            ),
          ),

          const Divider(),

          // 3) Inline “new playlist” row or button
          isCreatingNew
              ? Padding(
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
              : SizedBox(
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

  @override
  void dispose() {
    editingController.dispose();
    newPlaylistController.dispose();
    super.dispose();
  }
}
