// lib/models/playlist.dart
class Playlist {
  final int id;
  String name;
  final DateTime createdAt;
  int ordering;
  int trackCount; // computed via a SQL join

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.ordering,
    this.trackCount = 0,
  });

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'],
      name: map['name'] ?? '',
      // If 'created_at' is null, we'll fallback to the current time.
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      // If ordering is null, default to 0. We use int.tryParse just in case the value is not an int.
      ordering:
          map['ordering'] != null
              ? int.tryParse(map['ordering'].toString()) ?? 0
              : 0,
      // Similarly, we ensure trackCount is an int.
      trackCount:
          map['trackCount'] != null
              ? int.tryParse(map['trackCount'].toString()) ?? 0
              : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'ordering': ordering,
    };
  }
}

class PlaylistTrack {
  final int id;
  final int playlistId;
  final String trackId;
  final int duration;
  final String title;
  final String library;
  final String cdTitle;
  final String filename;
  int ordering;

  PlaylistTrack({
    required this.id,
    required this.playlistId,
    required this.trackId,
    required this.duration,
    required this.title,
    required this.library,
    required this.cdTitle,
    required this.filename,
    required this.ordering,
  });

  factory PlaylistTrack.fromMap(Map<String, dynamic> map) {
    return PlaylistTrack(
      id: map['id'],
      playlistId: map['playlist_id'],
      trackId: map['track_id'],
      duration: map['duration'],
      title: map['title'],
      library: map['library'],
      cdTitle: map['cd_title'],
      filename: map['filename'],
      ordering:
          map['ordering'] != null
              ? int.tryParse(map['ordering'].toString()) ?? 0
              : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'playlist_id': playlistId,
      'track_id': trackId,
      'duration': duration,
      'title': title,
      'library': library,
      'cd_title': cdTitle,
      'filename': filename,
      'ordering': ordering,
    };
  }
}
