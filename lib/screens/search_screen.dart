import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../widgets/audio_player_widget.dart';
import 'package:flutter/foundation.dart'; // for debugPrint

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _mainSearchController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
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
  int _currentPage = 0;
  int _totalResults = 0;
  final int _rowsPerPage = 20;
  List<Track> _tracks = [];
  String _statusMessage = "";

  // Calculate total pages based on total results and rows per page.
  int get _totalPages => (_totalResults / _rowsPerPage).ceil();

  Future<void> _performSearch() async {
    setState(() {
      _statusMessage = "Searching...";
    });
    try {
      // Retrieve the total count first.
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

  /// Resets all search inputs and clears the results.
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

  /// Builds a toggle button for selecting track type.
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

  /// Builds the pagination controls as "< [Icon] Page X of Y [Icon] >"
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
            // Search input row.
            Row(
              children: [
                Expanded(
                  flex: 2,
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
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedFilter,
                    items:
                        _filterOptions.map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                    decoration: const InputDecoration(
                      labelText: 'Filter by',
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
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
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
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            // Track type toggle buttons.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToggleButton('All', 'all'),
                _buildToggleButton('Instrumental', 'instrumental'),
                _buildToggleButton('Vocal', 'vocal'),
                _buildToggleButton('Solo', 'solo'),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _currentPage = 0;
                _performSearch();
              },
              child: const Text("Search"),
            ),
            const SizedBox(height: 16),
            if (_statusMessage.isNotEmpty) Text(_statusMessage),
            // List of search results.
            Expanded(
              child: ListView.builder(
                itemCount: _tracks.length,
                itemBuilder: (context, index) {
                  final track = _tracks[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Display the track's ID first.
                          Text(
                            "ID: ${track.id}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Assign a unique key based on the track's ID.
                          AudioPlayerWidget(
                            key: ValueKey(track.id),
                            track: track,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Pagination controls.
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
