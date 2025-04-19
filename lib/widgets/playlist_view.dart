// lib/widgets/playlist_view.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/playlist_service.dart';
import '../services/database_service.dart';
import '../widgets/audio_player_widget.dart';

class PlaylistView extends StatefulWidget {
  final Playlist playlist;

  const PlaylistView({Key? key, required this.playlist}) : super(key: key);

  @override
  _PlaylistViewState createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  List<PlaylistTrack> _playlistTracks = [];
  List<Track> _displayTracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    try {
      final pts = await PlaylistService.getPlaylistTracks(widget.playlist.id);
      // Load full Track metadata for each playlist track
      final tracks = await Future.wait(
        pts.map((pt) async {
          final results = await DatabaseService.searchTracks(
            mainSearchTerm: '',
            filterField: 'id',
            filterValue: pt.trackId,
            page: 0,
            pageSize: 1,
            trackTypeFilter: 'all',
          );
          if (results.isNotEmpty) return results.first;
          // Fallback to dummy if DB lookup fails
          return Track(
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
        }),
      );
      if (!mounted) return;
      setState(() {
        _playlistTracks = pts;
        _displayTracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Error loading playlist tracks: $e');
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final movedTrack = _playlistTracks.removeAt(oldIndex);
    final movedDisplay = _displayTracks.removeAt(oldIndex);
    _playlistTracks.insert(newIndex, movedTrack);
    _displayTracks.insert(newIndex, movedDisplay);
    setState(() {});
    await PlaylistService.updateTrackOrdering(
      widget.playlist.id,
      _playlistTracks,
    );
  }

  Future<void> _deleteTrack(PlaylistTrack pt) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Remove Track'),
                content: const Text(
                  'Are you sure you want to remove this track from the playlist?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirmed) return;

    await PlaylistService.removeTrackFromPlaylist(
      widget.playlist.id,
      pt.trackId,
    );
    await _loadPlaylist();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Track removed')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            widget.playlist.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Expanded(
          child: ReorderableListView(
            onReorder: _onReorder,
            children: [
              for (var i = 0; i < _playlistTracks.length; i++)
                Card(
                  key: ValueKey(_playlistTracks[i].id),
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ID | Title | Description row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'ID: ${_displayTracks[i].id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _displayTracks[i].title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_displayTracks[i].description),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Audio player + remove button
                        Row(
                          children: [
                            Expanded(
                              child: AudioPlayerWidget(
                                key: ValueKey('audio_${_playlistTracks[i].id}'),
                                track: _displayTracks[i],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _deleteTrack(_playlistTracks[i]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
