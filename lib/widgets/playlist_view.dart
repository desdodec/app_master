// lib/widgets/playlist_view.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';
import '../models/track.dart';
import '../widgets/audio_player_widget.dart';

class PlaylistView extends StatefulWidget {
  final Playlist playlist;

  const PlaylistView({Key? key, required this.playlist}) : super(key: key);

  @override
  _PlaylistViewState createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  List<PlaylistTrack> tracks = [];

  @override
  void initState() {
    super.initState();
    fetchTracks();
  }

  Future<void> fetchTracks() async {
    var ts = await PlaylistService.getPlaylistTracks(widget.playlist.id);
    if (!mounted) return;
    setState(() {
      tracks = ts;
    });
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, item);
    setState(() {});
    await PlaylistService.updateTrackOrdering(widget.playlist.id, tracks);
  }

  Future<void> _deleteTrack(PlaylistTrack track) async {
    bool confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
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
    if (confirmed) {
      await PlaylistService.removeTrackFromPlaylist(
        widget.playlist.id,
        track.trackId,
      );
      await fetchTracks();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Track removed')));
    }
  }

  Widget _buildTrackItem(BuildContext context, int index) {
    final trackItem = tracks[index];
    // Create a dummy Track instance for the AudioPlayerWidget using available track info.
    final Track dummyTrack = Track(
      id: trackItem.trackId,
      favourited: 0,
      publisher: '',
      library: trackItem.library,
      cdTitle: trackItem.cdTitle,
      composer: '',
      title: trackItem.title,
      description: '',
      version: '',
      filename: trackItem.filename,
      releasedAt: 0,
      number: 0,
      cdDescription: '',
      duration: trackItem.duration,
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

    return Column(
      key: ValueKey(trackItem.id),
      children: [
        ListTile(
          title: Text(trackItem.title),
          subtitle: Text('Library: ${trackItem.library}'),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Remove Track',
            onPressed: () => _deleteTrack(trackItem),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8.0,
            horizontal: 16.0,
          ),
        ),
        AudioPlayerWidget(
          key: ValueKey('audio_${trackItem.id}'),
          track: dummyTrack,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Playlist header.
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
              for (int i = 0; i < tracks.length; i++)
                _buildTrackItem(context, i),
            ],
          ),
        ),
      ],
    );
  }
}
