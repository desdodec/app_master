// lib/screens/search_screen.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import '../models/track.dart';
import '../models/playlist.dart';
import '../services/database_service.dart';
import '../services/playlist_service.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/playlist_sidebar.dart';
import '../widgets/playlist_view.dart';

/// Main screen that toggles between search mode and playlist mode.
class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Controllers for search inputs
  final TextEditingController _mainSearchController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  int _sidebarRefreshCounter = 0; // ← add it here, as a field

  // Filter options
  final List<String> _filterOptions = [
    'id',
    'title',
    'composer',
    'cd_title',
    'library',
    'lyric',
  ];
  String _selectedFilter = 'id';
  String _selectedTrackType = 'all';

  // Pagination
  int _currentPage = 0;
  int _totalResults = 0;
  final int _rowsPerPage = 10;

  // Search results and status
  List<Track> _tracks = [];
  String _statusMessage = '';

  // Playlist mode state
  Playlist? selectedPlaylist;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _mainSearchController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  /// Reveal the given file in Finder (macOS) or Explorer (Windows).
  Future<void> _revealInFolder(String filePath) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isWindows) {
        final winPath = filePath.replaceAll('/', r'\\');
        await Process.run('explorer.exe', ['/select,$winPath']);
      }
    } catch (e) {
      debugPrint('Failed to reveal $filePath: $e');
    }
  }

  /// Downloads the audio file to a location chosen by the user.
  void _handleDownload(Track track) async {
    final sourceFile = File(track.audioPath);
    if (!await sourceFile.exists()) return;
    final fileName = p.basename(track.audioPath);
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [
        XTypeGroup(label: 'Audio', extensions: ['mp3']),
      ],
    );
    if (location != null) await sourceFile.copy(location.path);
  }

  /// Performs the search by querying the database service.
  Future<void> _performSearch() async {
    setState(() => _statusMessage = 'Searching...');
    try {
      final count = await DatabaseService.searchTracksCount(
        mainSearchTerm: _mainSearchController.text.trim(),
        filterField: _selectedFilter,
        filterValue: _filterController.text.trim(),
        trackTypeFilter: _selectedTrackType,
      );
      if (!mounted) return;
      final results = await DatabaseService.searchTracks(
        mainSearchTerm: _mainSearchController.text.trim(),
        filterField: _selectedFilter,
        filterValue: _filterController.text.trim(),
        page: _currentPage,
        pageSize: _rowsPerPage,
        trackTypeFilter: _selectedTrackType,
      );
      if (!mounted) return;
      setState(() {
        _tracks = results;
        _totalResults = count;
        _statusMessage = results.isEmpty ? 'No results found.' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  /// Clears all search inputs and resets to initial state.
  void _clearAll() {
    setState(() {
      _mainSearchController.clear();
      _filterController.clear();
      _selectedFilter = 'id';
      _selectedTrackType = 'all';
      _currentPage = 0;
      _tracks = [];
      _totalResults = 0;
      _statusMessage = '';
      selectedPlaylist = null;
    });
  }

  /// Builds the top search/filter controls.
  Widget _buildSearchControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize:
              MainAxisSize.min, // allow horizontal scrolling without overflow
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: _mainSearchController,
                decoration: const InputDecoration(
                  labelText: 'Search (FTS)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _currentPage = 0;
                  _performSearch();
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 124,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Filter by',
                  border: OutlineInputBorder(),
                ),
                value: _selectedFilter,
                items:
                    _filterOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedFilter = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _filterController,
                decoration: const InputDecoration(
                  labelText: 'Filter value',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _currentPage = 0;
                  _performSearch();
                },
              ),
            ),
            const SizedBox(width: 8),
            ...['all', 'instrumental', 'vocal', 'solo'].map((type) {
              final isSelected = _selectedTrackType == type;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedTrackType = type;
                      _currentPage = 0;
                    });
                    _performSearch();
                  },
                  child: Text(type[0].toUpperCase() + type.substring(1)),
                ),
              );
            }),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                _currentPage = 0;
                _performSearch();
              },
              child: const Text('Search'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear),
              label: const Text('Clear All'),
            ),
          ],
        ),
      ),
    );
  }

  // ... rest of the code remains unchanged

  /// Builds a single track result row with player and actions.
  Widget _buildResultRow(Track track) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ID: ${track.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    track.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(track.description)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AudioPlayerWidget(
                    key: ValueKey(track.id),
                    track: track,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Download',
                  onPressed: () => _handleDownload(track),
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add),
                  tooltip: 'Add to playlist',
                  onPressed: () => _handleAddTrackToPlaylist(track),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Reveal in folder',
                  onPressed: () => _revealInFolder(track.audioPath),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds pagination controls at bottom.
  Widget _buildPagination() {
    final totalPages = (_totalResults / _rowsPerPage).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed:
              _currentPage > 0
                  ? () {
                    setState(() {
                      _currentPage--;
                    });
                    _performSearch();
                  }
                  : null,
        ),
        Text('Page ${_currentPage + 1} of $totalPages'),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed:
              _currentPage + 1 < totalPages
                  ? () {
                    setState(() {
                      _currentPage++;
                    });
                    _performSearch();
                  }
                  : null,
        ),
      ],
    );
  }

  /// Shows a full‑height, scrollable modal for adding a track to a playlist,
  /// but does NOT select the playlist (so you stay in search mode).
  void _handleAddTrackToPlaylist(Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AddToPlaylistModal(
                    track: track,
                    onPlaylistSelected: (_) {
                      // Only bump the sidebar key to reload playlists,
                      // but don’t set selectedPlaylist.
                      setState(() {
                        _sidebarRefreshCounter++;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool inPlaylistMode = selectedPlaylist != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Search'),
        actions: [
          if (selectedPlaylist != null)
            IconButton(
              icon: const Icon(Icons.search), // 🔍 back-to-search
              tooltip: 'Back to Search',
              onPressed: () => setState(() => selectedPlaylist = null),
            ),
        ],
      ),
      body: Row(
        children: [
          PlaylistSidebar(
            key: ValueKey(
              _sidebarRefreshCounter,
            ), // ← rebuild widget when counter changes
            onPlaylistSelected: (pl) {
              setState(() => selectedPlaylist = pl);
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child:
                inPlaylistMode
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextButton.icon(
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back to Search'),
                            onPressed:
                                () => setState(() => selectedPlaylist = null),
                          ),
                        ),
                        Expanded(
                          child: PlaylistView(
                            key: ValueKey('playlist_${selectedPlaylist!.id}'),
                            playlist: selectedPlaylist!,
                          ),
                        ),
                      ],
                    )
                    : Column(
                      children: [
                        _buildSearchControls(),
                        const SizedBox(height: 16),
                        if (_statusMessage.isNotEmpty) Text(_statusMessage),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _tracks.length,
                            itemBuilder:
                                (context, index) =>
                                    _buildResultRow(_tracks[index]),
                          ),
                        ),
                        _buildPagination(),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet component to add a track to a playlist.
class AddToPlaylistModal extends StatefulWidget {
  final Track track;
  final void Function(Playlist?) onPlaylistSelected; // ← add this
  const AddToPlaylistModal({
    Key? key,
    required this.track,
    required this.onPlaylistSelected, // ← and this
  }) : super(key: key);

  @override
  State<AddToPlaylistModal> createState() => _AddToPlaylistModalState();
}

class _AddToPlaylistModalState extends State<AddToPlaylistModal> {
  List<Playlist> playlists = [];
  bool isCreatingNew = false;
  final TextEditingController newPlaylistController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final pls = await PlaylistService.getPlaylists();
    if (!mounted) return;
    setState(() => playlists = pls);
  }

  Future<void> _addToPlaylist(Playlist pl) async {
    final added = await PlaylistService.addTrackToPlaylist(pl.id, widget.track);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'Added to ${pl.name}' : 'Already in ${pl.name}'),
      ),
    );
    widget.onPlaylistSelected(pl);
    Navigator.pop(context);
  }

  Future<void> _createAndAdd(String name) async {
    final pl = await PlaylistService.createPlaylist(name);
    await _addToPlaylist(pl);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child:
              isCreatingNew
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: newPlaylistController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Playlist Name',
                        ),
                        onSubmitted: (v) {
                          final name = v.trim();
                          if (name.isNotEmpty) _createAndAdd(name);
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          final name = newPlaylistController.text.trim();
                          if (name.isNotEmpty) _createAndAdd(name);
                        },
                        child: const Text('Create & Add'),
                      ),
                    ],
                  )
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('New Playlist'),
                        onTap: () => setState(() => isCreatingNew = true),
                      ),
                      const Divider(),
                      ...playlists.map(
                        (pl) => ListTile(
                          title: Text(pl.name),
                          onTap: () => _addToPlaylist(pl),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
