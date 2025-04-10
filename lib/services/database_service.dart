import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart'; // for debugPrint
import '../models/track.dart';

class DatabaseService {
  static Database? _database;

  /// Getter for the database instance.
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database from the assets folder.
  static Future<Database> _initDatabase() async {
    final currentDir = Directory.current.absolute.path;
    final dbPath = path.join(currentDir, 'assets', 'db', 'roo_sqlite.db');
    if (!await File(dbPath).exists()) {
      throw Exception('Database file not found at $dbPath');
    }
    // Open the database in read-only mode.
    return await openDatabase(dbPath, readOnly: true);
  }

  /// Searches for tracks using full-text search and filtering options.
  /// Logs the full SQL query and arguments before execution.
  static Future<List<Track>> searchTracks({
    required String mainSearchTerm,
    String? filterField,
    String? filterValue,
    int page = 0,
    int pageSize = 20,
    String trackTypeFilter = 'all',
  }) async {
    final db = await database;
    List<dynamic> args = [];
    List<String> whereClauses = [];

    // Apply track type filtering with explicit table alias.
    if (trackTypeFilter == 'instrumental') {
      whereClauses.add('t.vocal = 0');
    } else if (trackTypeFilter == 'vocal') {
      whereClauses.add('t.vocal = 1');
    } else if (trackTypeFilter == 'solo') {
      whereClauses.add('t.solo = 1');
    }

    // Apply additional field filter if provided.
    if (filterField != null && filterValue != null && filterValue.isNotEmpty) {
      whereClauses.add("t.$filterField LIKE ?");
      args.add('%$filterValue%');
    }

    // Apply full-text search if main search term is provided.
    if (mainSearchTerm.isNotEmpty) {
      whereClauses.add("tracks_fts MATCH ?");
      args.add(mainSearchTerm);
    }

    String whereStmt =
        whereClauses.isNotEmpty ? 'WHERE ' + whereClauses.join(' AND ') : '';

    // Explicit list of columns from the tracks table (aliased as 't')
    final String trackColumns = '''
      t.id,
      t.title,
      t.description,
      t.duration,
      t.version,
      t.library,
      t.cd_title,
      t.filename,
      t.number,
      t.composer,
      t.vocal,
      t.solo,
      t.favourited,
      t.publisher,
      t.released_at,
      t.cd_description,
      t.bpm,
      t.priority,
      t.keywords,
      t.is_child,
      t.parent,
      t.mood,
      t.featured,
      t.lyric
    ''';

    late String query;
    if (mainSearchTerm.isNotEmpty) {
      // Use full-text search with BM25 ranking.
      query = '''
      SELECT $trackColumns, bm25(tracks_fts, 5.0, 4.0, 3.0, 2.0, 1.0) AS rank
      FROM tracks t
      INNER JOIN tracks_fts ON tracks_fts.id = t.id
      $whereStmt
      ORDER BY rank DESC
      LIMIT ? OFFSET ?
      ''';
    } else {
      // Simple query without full-text search.
      query = '''
      SELECT $trackColumns
      FROM tracks t
      $whereStmt
      ORDER BY t.id
      LIMIT ? OFFSET ?
      ''';
    }

    // Append pagination parameters.
    args.addAll([pageSize, page * pageSize]);

    debugPrint("Executing SQL Query:");
    debugPrint(query);
    debugPrint("Arguments: $args");

    final List<Map<String, dynamic>> result = await db.rawQuery(query, args);
    return result.map((map) => Track.fromMap(map)).toList();
  }

  /// Returns the total count of tracks matching the search/filter criteria.
  /// This helps with pagination on the search screen.
  static Future<int> searchTracksCount({
    required String mainSearchTerm,
    String? filterField,
    String? filterValue,
    String trackTypeFilter = 'all',
  }) async {
    final db = await database;
    List<dynamic> args = [];
    List<String> whereClauses = [];

    if (trackTypeFilter == 'instrumental') {
      whereClauses.add('t.vocal = 0');
    } else if (trackTypeFilter == 'vocal') {
      whereClauses.add('t.vocal = 1');
    } else if (trackTypeFilter == 'solo') {
      whereClauses.add('t.solo = 1');
    }

    if (filterField != null && filterValue != null && filterValue.isNotEmpty) {
      whereClauses.add("t.$filterField LIKE ?");
      args.add('%$filterValue%');
    }

    if (mainSearchTerm.isNotEmpty) {
      whereClauses.add("tracks_fts MATCH ?");
      args.add(mainSearchTerm);
    }

    String whereStmt =
        whereClauses.isNotEmpty ? 'WHERE ' + whereClauses.join(' AND ') : '';

    late String countQuery;
    if (mainSearchTerm.isNotEmpty) {
      countQuery = '''
         SELECT COUNT(*) as count
         FROM tracks t
         INNER JOIN tracks_fts ON tracks_fts.id = t.id
         $whereStmt
      ''';
    } else {
      countQuery = '''
         SELECT COUNT(*) as count
         FROM tracks t
         $whereStmt
      ''';
    }

    debugPrint("Executing count query:");
    debugPrint(countQuery);
    debugPrint("Count query arguments: $args");

    final List<Map<String, dynamic>> result = await db.rawQuery(
      countQuery,
      args,
    );
    int? count = Sqflite.firstIntValue(result);
    return count ?? 0;
  }
}
