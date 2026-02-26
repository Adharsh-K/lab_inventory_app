import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'request_detail_page.dart'; // We'll link to the detail page here

class RequestListPage extends StatefulWidget {
  final String title;
  final String filterStatus;

  const RequestListPage({
    super.key, 
    required this.title, 
    required this.filterStatus
  });

  @override
  State<RequestListPage> createState() => _RequestListPageState();
}

class _RequestListPageState extends State<RequestListPage> {
  final ApiService apiService = ApiService();
  String _searchQuery = "";

  void _refreshData() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search student name...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          // 📜 The List
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: apiService.fetchPendingRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData) {
                  // 1. Filter by Status (pending/collected)
                  var requests = snapshot.data!.where((req) {
                    final status = req['status'];
                    
                    // If we are on the "Disburse/Issue" page
                    if (widget.filterStatus == "issue") {
                      return status == 'pending' || status == 'approved';
                    }
                    
                    // Otherwise, match the status exactly (for 'collected', etc.)
                    return status == widget.filterStatus;
                  }).toList();

                  // 2. Filter by Search Query
                  if (_searchQuery.isNotEmpty) {
                    requests = requests.where((req) {
                      final name = (req['student_name'] ?? "").toString().toLowerCase();
                      return name.contains(_searchQuery);
                    }).toList();
                  }

                  if (requests.isEmpty) {
                    return const Center(child: Text("No requests found."));
                  }

                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(child: Text("${request['id']}")),
                          title: Text(request['student_name'] ?? "Unknown Student"),
                          subtitle: Text("Items: ${(request['items'] as List).length}"),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () async {
                            // NAVIGATE to Detail Page
                            bool? updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RequestDetailPage(request: request),
                              ),
                            );
                            // Refresh if status was changed
                            if (updated == true) _refreshData();
                          },
                        ),
                      );
                    },
                  );
                }
                return const Center(child: Text("Error fetching data."));
              },
            ),
          ),
        ],
      ),
    );
  }
}