import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../widgets/audio_player_widget.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _mainSearchController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();

  // Updated filter options.
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

  // Pagination state.
  int _currentPage = 0;
  int _totalResults = 0;
  final int _rowsPerPage = 10;
  List<Track> _tracks = [];
  String _statusMessage = "";

  int get _totalPages => (_totalResults / _rowsPerPage).ceil();

  Future<void> _performSearch() async {
    setState(() {
      _statusMessage = "Searching...";
    });
    try {
      int count = await DatabaseService.searchTracksCount(
        mainSearchTerm: _mainSearchController.text.trim(),
        filterField: _selectedFilter,
        filterValue: _filterController.text.trim(),
        trackTypeFilter: _selectedTrackType,
      );

      List<Track> results = await DatabaseService.searchTracks(
        mainSearchTerm: _mainSearchController.text.trim(),
        filterField: _selectedFilter,
        filterValue: _filterController.text.trim(),
        page: _currentPage,
        pageSize: _rowsPerPage,
        trackTypeFilter: _selectedTrackType,
      );

      setState(() {
        _tracks = results;
        _totalResults = count;
        _statusMessage = results.isEmpty ? "No results found." : "";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
      });
    }
  }

  void _clearAll() {
    setState(() {
      _mainSearchController.clear();
      _filterController.clear();
      _selectedFilter = 'id';
      _selectedTrackType = 'all';
      _currentPage = 0;
      _tracks = [];
      _totalResults = 0;
      _statusMessage = "";
    });
  }

  Widget _buildToggleButton(String label, String value) {
    bool isSelected = _selectedTrackType == value;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey,
      ),
      onPressed: () {
        setState(() {
          _selectedTrackType = value;
          _currentPage = 0;
        });
        _performSearch();
      },
      child: Text(label),
    );
  }

  /// Builds the search controls all on one horizontal line.
  Widget _buildSearchControls() {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Full-text search field.
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
            // Filter by dropdown.
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedFilter,
                icon: const Icon(Icons.arrow_drop_down, size: 24),
                items:
                    _filterOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                decoration: const InputDecoration(
                  labelText: 'Filter by',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedFilter = val;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            // Filter value field.
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
            // Toggle buttons.
            _buildToggleButton('All', 'all'),
            const SizedBox(width: 4),
            _buildToggleButton('Instrumental', 'instrumental'),
            const SizedBox(width: 4),
            _buildToggleButton('Vocal', 'vocal'),
            const SizedBox(width: 4),
            _buildToggleButton('Solo', 'solo'),
            const SizedBox(width: 8),
            // Search button.
            ElevatedButton(
              onPressed: () {
                _currentPage = 0;
                _performSearch();
              },
              child: const Text("Search"),
            ),
            const SizedBox(width: 8),
            // Clear All button.
            ElevatedButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear),
              label: const Text("Clear All"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds each result row with two lines:
  /// First line: ID, title, and description.
  /// Second line: AudioPlayerWidget.
  Widget _buildResultRow(Track track) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First line: ID, title, and description.
            Row(
              children: [
                Text(
                  "ID: ${track.id}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Text(
                    track.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Text(
                    track.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Second line: AudioPlayerWidget.
            AudioPlayerWidget(key: ValueKey(track.id), track: track),
          ],
        ),
      ),
    );
  }

  /// Builds pagination controls in the format "< [icon] Page X of Y [icon] >"
  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
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
        Text("Page ${_currentPage + 1} of $_totalPages"),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed:
              (_currentPage + 1) < _totalPages
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Search')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchControls(),
            const SizedBox(height: 16),
            if (_statusMessage.isNotEmpty) Text(_statusMessage),
            Expanded(
              child: ListView.builder(
                itemCount: _tracks.length,
                itemBuilder: (context, index) {
                  final track = _tracks[index];
                  return _buildResultRow(track);
                },
              ),
            ),
            _buildPagination(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mainSearchController.dispose();
    _filterController.dispose();
    super.dispose();
  }
}
