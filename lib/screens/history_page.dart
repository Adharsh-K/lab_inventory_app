import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'dart:async';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService apiService = ApiService();
  
  List<dynamic> history = [];
  bool _isLoading = true;
  bool _isSearching = false;
  DateTimeRange? _selectedDateRange;
  Timer? _debounce;

  // Pagination State
  int _currentPage = 1;
  int _totalRecords = 0;
  final int _pageSize = 15; 
  bool _hasNext = false;
  bool _hasPrev = false;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  int get _totalPages => (_totalRecords / _pageSize).ceil();

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchHistory(page: 1); 
    });
  }

Future<void> _fetchHistory({int page = 1}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Fetch the data
      final Map<String, dynamic> data = await apiService.getHistory(
        page: page,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
        studentId: _searchController.text.trim().isNotEmpty 
            ? _searchController.text.trim() 
            : null,
      );

      // --- DEBUGGING PART: Check your console for this output ---
      debugPrint("DEBUG: API Response Keys: ${data.keys}");
      debugPrint("DEBUG: Total Count from Server: ${data['count']}");
      if (data.containsKey('results')) {
        debugPrint("DEBUG: Results found, length: ${(data['results'] as List).length}");
      } else {
        debugPrint("DEBUG: WARNING! 'results' key is missing from the response.");
      }
      // ---------------------------------------------------------

      if (!mounted) return;

      setState(() {
        // We cast to List<dynamic> to ensure history is updated correctly
        history = data['results'] as List<dynamic>? ?? [];
        
        // Use .toString() to avoid the "String can't be assigned to int" error
        _totalRecords = int.tryParse(data['count'].toString()) ?? 0;
        
        _hasNext = data['next'] != null;
        _hasPrev = data['previous'] != null;
        _currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("DEBUG: Catch Block Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fetch Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching ? _buildSearchField() : const Text("Issue History"),
        actions: _buildAppBarActions(),
      ),
      body: Column(
        children: [
          if (_selectedDateRange != null) _buildFilterChip(),
          
          if (!_isLoading) Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              "Found $_totalRecords records", 
              style: TextStyle(color: Colors.grey[600], fontSize: 11)
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildHistoryList(),
          ),

          if (!_isLoading && history.isNotEmpty) _buildPaginationFooter(),
        ],
      ),
    );
  }

  // --- UI BUILDER METHODS ---

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: "Search Name or ID...",
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white70),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        icon: Icon(_isSearching ? Icons.close : Icons.search),
        onPressed: () {
          setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) {
              _searchController.clear();
            }
          });
        },
      ),
      if (!_isSearching)
        IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () => _selectDateRange(context),
        ),
      IconButton(
        icon: const Icon(Icons.file_download, color: Colors.greenAccent),
        onPressed: (history.isEmpty || _isLoading) ? null : _exportToCSV,
      ),
    ];
  }

  Widget _buildFilterChip() {
    final df = DateFormat('dd MMM yyyy');
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Chip(
        label: Text("${df.format(_selectedDateRange!.start)} - ${df.format(_selectedDateRange!.end)}"),
        onDeleted: () {
          setState(() => _selectedDateRange = null);
          _fetchHistory(page: 1);
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    if (history.isEmpty) return const Center(child: Text("No records found."));
    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final req = history[index];
        String dateStr = "N/A";
        try {
          if (req['requested_at'] != null) {
            dateStr = DateFormat('dd MMM').format(DateTime.parse(req['requested_at']));
          }
        } catch (e) { dateStr = "Err"; }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.teal)),
            ),
            title: Text(req['student_name'] ?? "Unknown"),
            subtitle: Text("ID: ${req['student_id'] ?? 'No ID'} • ${req['status']}"),
            trailing: const Icon(Icons.chevron_right, size: 16),
          ),
        );
      },
    );
  }

  Widget _buildPaginationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _hasPrev ? () => _fetchHistory(page: _currentPage - 1) : null,
            icon: const Icon(Icons.arrow_back_ios, size: 14),
            label: const Text("Prev"),
          ),
          
          Text(
            "Page $_currentPage of ${_totalPages < 1 ? 1 : _totalPages}", 
            style: const TextStyle(fontWeight: FontWeight.bold)
          ),
          
          TextButton.icon(
            onPressed: _hasNext ? () => _fetchHistory(page: _currentPage + 1) : null,
            icon: const Text("Next"),
            label: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
        ],
      ),
    );
  }

  // --- HELPER LOGIC ---

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchHistory(page: 1);
    }
  }

  Future<void> _exportToCSV() async {
    // 4. Permission check for Android 13+ (requires specialized handling, but keeping your logic)
    if (await Permission.storage.request().isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission required")));
      return;
    }

    List<List<dynamic>> rows = [
      ["ID", "Date", "Student", "Status"]
    ];

    for (var req in history) {
      // 5. Added null-checks to prevent CSV crash
      rows.add([
        req['id'] ?? '',
        req['requested_at'] ?? '',
        req['student_name'] ?? 'Unknown',
        req['status'] ?? ''
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception("Could not access storage");
      
      final String path = "${directory.path}/History_Page_$_currentPage.csv";
      final File file = File(path);
      await file.writeAsString(csvData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved: $path")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    }
  }
}