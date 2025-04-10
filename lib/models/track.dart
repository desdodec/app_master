import 'dart:io';
import 'package:path/path.dart' as path;

class Track {
  final String id;
  final int favourited;
  final String publisher;
  final String library;
  final String cdTitle;
  final String composer;
  final String title;
  final String description;
  final String version;
  final String filename;
  final int releasedAt;
  final int number;
  final String cdDescription;
  final int duration;
  final int bpm;
  final int priority;
  final String keywords;
  final int isChild;
  final int parent;
  final int mood;
  final int solo;
  final int vocal;
  final int featured;
  final String lyric;

  Track({
    required this.id,
    required this.favourited,
    required this.publisher,
    required this.library,
    required this.cdTitle,
    required this.composer,
    required this.title,
    required this.description,
    required this.version,
    required this.filename,
    required this.releasedAt,
    required this.number,
    required this.cdDescription,
    required this.duration,
    required this.bpm,
    required this.priority,
    required this.keywords,
    required this.isChild,
    required this.parent,
    required this.mood,
    required this.solo,
    required this.vocal,
    required this.featured,
    required this.lyric,
  });

  factory Track.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        try {
          return int.parse(value);
        } catch (e) {
          return 0;
        }
      }
      return 0;
    }

    return Track(
      id: map['id']?.toString() ?? '',
      favourited: toInt(map['favourited']),
      publisher: map['publisher']?.toString() ?? '',
      library: map['library']?.toString() ?? '',
      cdTitle: map['cd_title']?.toString() ?? '',
      composer: map['composer']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      version: map['version']?.toString() ?? '',
      filename: map['filename']?.toString() ?? '',
      releasedAt: toInt(map['released_at']),
      number: toInt(map['number']),
      cdDescription: map['cd_description']?.toString() ?? '',
      duration: toInt(map['duration']),
      bpm: toInt(map['bpm']),
      priority: toInt(map['priority']),
      keywords: map['keywords']?.toString() ?? '',
      isChild: toInt(map['is_child']),
      parent: toInt(map['parent']),
      mood: toInt(map['mood']),
      solo: toInt(map['solo']),
      vocal: toInt(map['vocal']),
      featured: toInt(map['featured']),
      lyric: map['lyric']?.toString() ?? '',
    );
  }

  // Extract catalogue number (portion before the underscore)
  String get catalogueNumber => id.contains('_') ? id.split('_')[0] : id;

  // Use the current directory as the base directory.
  String get baseDir => Directory.current.absolute.path;

  // Construct asset file paths.
  String get artworkPath =>
      path.join(baseDir, 'assets', 'artwork', library, '$catalogueNumber.jpg');
  String get audioPath => path.join(
    baseDir,
    'assets',
    'audio',
    'mp3s',
    library,
    '$catalogueNumber $cdTitle',
    '$filename.mp3',
  );
  String get waveformPath => path.join(
    baseDir,
    'assets',
    'waveforms',
    library,
    '$catalogueNumber $cdTitle',
    '$filename.png',
  );
  String get waveformOverlayPath => path.join(
    baseDir,
    'assets',
    'waveforms',
    library,
    '$catalogueNumber $cdTitle',
    '${filename}_over.png',
  );
}
