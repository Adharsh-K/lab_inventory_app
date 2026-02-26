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
  final ScrollController _scrollController = ScrollController();
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

  void _showRequestDetails(Map<String, dynamic> req) {
  // Extract items (assuming they are nested in the 'items' key from your serializer)
  final List<dynamic> items = req['items'] ?? [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Request Details",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text("Student: ${req['student_name']}", style: TextStyle(color: Colors.grey[600])),
                const Divider(height: 30),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text("No items found in this request"))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item['component_name'] ?? "Unknown Item", 
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text("Category: ${item['category_name'] ?? 'General'}"),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("Qty: ${item['quantity']}", 
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                  if (item['issued_quantity'] != null)
                                    Text("Issued: ${item['issued_quantity']}", 
                                      style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

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
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  int get _totalPages => _totalRecords == 0 ? 1 : (_totalRecords / _pageSize).ceil();

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
      final Map<String, dynamic> data = await apiService.getHistory(
        page: page,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
        studentId: _searchController.text.trim().isNotEmpty 
            ? _searchController.text.trim() 
            : null,
      );

      debugPrint("DEBUG: API Response Keys: ${data.keys}");
      
      if (!mounted) return;

      setState(() {
        history = data['results'] as List<dynamic>? ?? [];
        _totalRecords = int.tryParse(data['count'].toString()) ?? 0;
        _hasNext = data['next'] != null;
        _hasPrev = data['previous'] != null;
        _currentPage = page;
        _isLoading = false;
      });

      // Reset scroll position to top when page changes
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOut
        );
      }
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
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_selectedDateRange != null) _buildFilterChip(),
          
          if (!_isLoading) Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            width: double.infinity,
            color: Colors.grey[100],
            child: Text(
              "Found $_totalRecords records", 
              style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w500)
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
        backgroundColor: Colors.teal[50],
        label: Text(
          "${df.format(_selectedDateRange!.start)} - ${df.format(_selectedDateRange!.end)}",
          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
        ),
        onDeleted: () {
          setState(() => _selectedDateRange = null);
          _fetchHistory(page: 1);
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("No records found.", style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchHistory(page: 1),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final req = history[index];
          final String status = (req['status'] ?? 'pending').toString().toLowerCase();
          final Color statusColor = _getStatusColor(status);
          
          String dateStr = "N/A";
          try {
            if (req['requested_at'] != null) {
              dateStr = DateFormat('dd MMM').format(DateTime.parse(req['requested_at']));
            }
          } catch (e) { dateStr = "Err"; }

          return Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              onTap: () => _showRequestDetails(req),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: Colors.teal[50],
                child: Text(dateStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
              title: Text(
                req['student_name'] ?? "Unknown",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Text("ID: ${req['student_id'] ?? 'No ID'}", style: TextStyle(color: Colors.grey[600])),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
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
            "Page $_currentPage of $_totalPages", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange[800]!;
      case 'collected': return Colors.green[700]!;
      case 'returned': return Colors.blue[700]!;
      case 'rejected': return Colors.red[700]!;
      case 'processing_return': return Colors.purple[700]!;
      default: return Colors.grey[700]!;
    }
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
    if (await Permission.storage.request().isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission required")));
      return;
    }

    List<List<dynamic>> rows = [["ID", "Date", "Student", "Status"]];
    for (var req in history) {
      rows.add([req['id'] ?? '', req['requested_at'] ?? '', req['student_name'] ?? 'Unknown', req['status'] ?? '']);
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