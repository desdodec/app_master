// lib/widgets/playlist_view.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/playlist_service.dart';
import '../services/database_service.dart';
import '../widgets/audio_player_widget.dart';

/// View for a single playlist, showing ID, title, description, audio controls, and file reveal.
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

  /// Loads playlist items and their full Track metadata.
  Future<void> _loadPlaylist() async {
    try {
      final pts = await PlaylistService.getPlaylistTracks(widget.playlist.id);
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
      debugPrint('Error loading playlist: $e');
    }
  }

  /// Reveals the specified audio file in Finder (macOS) or Explorer (Windows).
  Future<void> _revealInFolder(String filePath) async {
    final absPath = File(filePath).absolute.path;
    try {
      if (Platform.isMacOS) {
        // Finder: reveal and select
        await Process.run('open', ['-R', absPath]);
      } else if (Platform.isWindows) {
        // Explorer: open new window and select the file
        final winPath = Uri.file(absPath).toFilePath(windows: true);
        await Process.run('cmd', [
          '/C',
          'start',
          '',
          'explorer',
          '/select,',
          winPath,
        ]);
      }
    } catch (e) {
      debugPrint('Failed to reveal $absPath: $e');
    }
  }

  /// Handles reordering of tracks within the playlist.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final movedPt = _playlistTracks.removeAt(oldIndex);
    final movedTr = _displayTracks.removeAt(oldIndex);
    _playlistTracks.insert(newIndex, movedPt);
    _displayTracks.insert(newIndex, movedTr);
    setState(() {});
    await PlaylistService.updateTrackOrdering(
      widget.playlist.id,
      _playlistTracks,
    );
  }

  /// Prompts and removes a track from the playlist.
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
    _loadPlaylist();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Track removed')));
  }

  /// Builds a card for each track in the playlist.
  Widget _buildTrackItem(BuildContext context, int index) {
    final pt = _playlistTracks[index];
    final track = _displayTracks[index];
    return Card(
      key: ValueKey(pt.id),
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
                    key: ValueKey('audio_${pt.id}'),
                    track: track,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove from playlist',
                  onPressed: () => _deleteTrack(pt),
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
                _buildTrackItem(context, i),
            ],
          ),
        ),
      ],
    );
  }
}
