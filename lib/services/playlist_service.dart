// lib/services/playlist_service.dart
import 'package:flutter/foundation.dart'; // Needed for debugPrint
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class PlaylistService {
  /// Fetch all playlists including the track count.
  static Future<List<Playlist>> getPlaylists() async {
    final db = await DatabaseService.database;
    debugPrint("Fetching playlists from the database...");
    final String query = '''
    SELECT p.id, p.name, p.created_at, p.ordering,
      (SELECT COUNT(*) FROM playlist_tracks WHERE playlist_tracks.playlist_id = p.id) AS trackCount
    FROM playlists p
    ORDER BY p.ordering ASC
    ''';
    final List<Map<String, dynamic>> results = await db.rawQuery(query);
    debugPrint(
      "Query executed. Number of playlists fetched: ${results.length}",
    );
    return results.map((map) => Playlist.fromMap(map)).toList();
  }

  /// Create a new playlist given its name.
  static Future<Playlist> createPlaylist(String name) async {
    final db = await DatabaseService.database;
    debugPrint("Creating new playlist with name: $name");
    // Get next ordering value; if none, start at 0.
    final List<Map<String, dynamic>> orderingResult = await db.rawQuery(
      'SELECT MAX(ordering) as maxOrder FROM playlists',
    );
    int nextOrdering = 0;
    if (orderingResult.isNotEmpty && orderingResult.first['maxOrder'] != null) {
      nextOrdering = orderingResult.first['maxOrder'] + 1;
    }
    debugPrint("Next ordering value for new playlist: $nextOrdering");
    int id = await db.insert('playlists', {
      'name': name,
      'ordering': nextOrdering,
    });
    debugPrint("New playlist inserted with id: $id");
    final List<Map<String, dynamic>> newPlaylistData = await db.query(
      'playlists',
      where: 'id = ?',
      whereArgs: [id],
    );
    return Playlist.fromMap(newPlaylistData.first);
  }

  /// Rename an existing playlist.
  static Future<void> renamePlaylist(int playlistId, String newName) async {
    final db = await DatabaseService.database;
    debugPrint("Renaming playlist (id: $playlistId) to: $newName");
    await db.update(
      'playlists',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
    debugPrint("Playlist renamed successfully.");
  }

  /// Delete a playlist along with its tracks.
  static Future<void> deletePlaylist(int playlistId) async {
    final db = await DatabaseService.database;
    debugPrint("Deleting playlist with id: $playlistId");
    await db.transaction((txn) async {
      await txn.delete(
        'playlist_tracks',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      await txn.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
    });
    debugPrint("Playlist and its tracks deleted successfully.");
  }

  /// Update the ordering for a list of playlists.
  static Future<void> updatePlaylistOrdering(List<Playlist> playlists) async {
    final db = await DatabaseService.database;
    debugPrint("Updating ordering for ${playlists.length} playlists.");
    Batch batch = db.batch();
    for (int i = 0; i < playlists.length; i++) {
      batch.update(
        'playlists',
        {'ordering': i},
        where: 'id = ?',
        whereArgs: [playlists[i].id],
      );
    }
    await batch.commit(noResult: true);
    debugPrint("Playlist ordering updated.");
  }

  /// Get tracks for a specific playlist.
  static Future<List<PlaylistTrack>> getPlaylistTracks(int playlistId) async {
    final db = await DatabaseService.database;
    debugPrint("Fetching tracks for playlist id: $playlistId");
    final List<Map<String, dynamic>> results = await db.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'ordering ASC',
    );
    debugPrint("Number of tracks fetched: ${results.length}");
    return results.map((map) => PlaylistTrack.fromMap(map)).toList();
  }

  /// Update the ordering for tracks within a playlist.
  static Future<void> updateTrackOrdering(
    int playlistId,
    List<PlaylistTrack> tracks,
  ) async {
    final db = await DatabaseService.database;
    debugPrint(
      "Updating ordering for ${tracks.length} tracks in playlist id: $playlistId",
    );
    Batch batch = db.batch();
    for (int i = 0; i < tracks.length; i++) {
      batch.update(
        'playlist_tracks',
        {'ordering': i},
        where: 'id = ?',
        whereArgs: [tracks[i].id],
      );
    }
    await batch.commit(noResult: true);
    debugPrint("Track ordering updated for playlist id: $playlistId");
  }

  /// Add a track to a playlist.
  /// Returns true if added, false if a duplicate (based on track_id) exists.
  static Future<bool> addTrackToPlaylist(int playlistId, Track track) async {
    final db = await DatabaseService.database;
    debugPrint(
      "Checking for duplicate track with id: ${track.id} in playlist id: $playlistId",
    );
    final List<Map<String, dynamic>> dupCheck = await db.query(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, track.id],
    );
    if (dupCheck.isNotEmpty) {
      debugPrint("Duplicate track detected. Aborting addition.");
      return false;
    }
    debugPrint("No duplicate found. Proceeding to add track: ${track.id}");
    final List<Map<String, dynamic>> orderingResult = await db.rawQuery(
      'SELECT MAX(ordering) as maxOrder FROM playlist_tracks WHERE playlist_id = ?',
      [playlistId],
    );
    int nextOrdering = 0;
    if (orderingResult.isNotEmpty && orderingResult.first['maxOrder'] != null) {
      nextOrdering = orderingResult.first['maxOrder'] + 1;
    }
    debugPrint("Next ordering for new track in playlist: $nextOrdering");
    await db.insert('playlist_tracks', {
      'playlist_id': playlistId,
      'track_id': track.id,
      'duration': track.duration,
      'title': track.title,
      'library': track.library,
      'cd_title': track.cdTitle,
      'filename': track.filename,
      'ordering': nextOrdering,
    });
    debugPrint("Track added successfully to playlist id: $playlistId");
    return true;
  }

  /// Remove a track from a playlist.
  static Future<void> removeTrackFromPlaylist(
    int playlistId,
    String trackId,
  ) async {
    final db = await DatabaseService.database;
    debugPrint(
      "Removing track with id: $trackId from playlist id: $playlistId",
    );
    await db.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
    debugPrint("Track removed from playlist.");
  }
}
