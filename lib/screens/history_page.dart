import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'dart:async'; // Required for Timer (Debouncer)
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
  Timer? _debounce; // Prevents hitting API on every single keystroke

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    // Dynamic listener for as-you-type searching
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchHistory();
    });
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Unified API call with Date and Search params
      final data = await apiService.getHistory(
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
        studentId: _searchController.text.trim().isNotEmpty 
            ? _searchController.text.trim() 
            : null,
      );

      setState(() {
        history = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  // ... (Your _exportToCSV logic remains the same)
  Future<void> _exportToCSV() async {
    if (await Permission.storage.request().isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Storage permission required")),
      );
      return;
    }

    List<List<dynamic>> rows = [
      ["Request ID", "Date", "Student Name", "Student ID", "Status"]
    ];

    for (var req in history) {
      rows.add([
        req['id'],
        req['requested_at'],
        req['student_name'] ?? "Unknown",
        req['student_id'] ?? "N/A",
        req['status'] ?? "Pending",
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    try {
      final directory = await getExternalStorageDirectory();
      final String path = "${directory!.path}/Audit_${DateTime.now().millisecondsSinceEpoch}.csv";
      final File file = File(path);
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Report saved to: $path")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: $e")),
      );
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search Name or ID...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
              )
            : const Text("Issue History"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear(); // This triggers _fetchHistory via listener
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
            onPressed: history.isEmpty ? null : _exportToCSV,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDateRange != null) _buildFilterChip(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip() {
    final df = DateFormat('dd MMM yyyy');
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Chip(
        label: Text("${df.format(_selectedDateRange!.start)} - ${df.format(_selectedDateRange!.end)}"),
        onDeleted: () {
          setState(() => _selectedDateRange = null);
          _fetchHistory();
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
        } catch (e) {
          dateStr = "Error";
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(child: Text(dateStr, style: const TextStyle(fontSize: 10))),
            title: Text(req['student_name'] ?? "Unknown"),
            subtitle: Text("ID: ${req['student_id'] ?? 'No ID'} • ${req['status']}"),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}