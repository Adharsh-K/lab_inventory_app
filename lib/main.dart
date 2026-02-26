import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
// Make sure this is created

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blueGrey,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
    ),
    home: LoginScreen(), 
  ));
}

class InchargeDashboard extends StatefulWidget {
  final String filterStatus; 
  const InchargeDashboard({super.key, required this.filterStatus});

  @override
  _InchargeDashboardState createState() => _InchargeDashboardState();
}

class _InchargeDashboardState extends State<InchargeDashboard> {
  final ApiService apiService = ApiService();
  String _searchQuery = ""; 
  bool _isSearching = false; 

  void _refreshData() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Search student or ID...",
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            )
          : Text(widget.filterStatus == 'pending' ? "Disburse Requests" : "Component Returns"),
        actions: [
          // Fixed Refresh Button
          IconButton(
            onPressed: _refreshData, 
            icon: const Icon(Icons.refresh)
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = ""; 
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout), 
            onPressed: () {
              ApiService.logout();
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (context) => LoginScreen()), 
                (route) => false
              );
            }
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: apiService.fetchPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } 
          
          if (snapshot.hasData) {
            // 1. Filter by Status (Pending/Collected)
            var requests = snapshot.data!
                .where((req) => req['status'] == widget.filterStatus)
                .toList();

            // 2. Filter by Search Query
            if (_searchQuery.isNotEmpty) {
              requests = requests.where((req) {
                final name = (req['student_name'] ?? "").toString().toLowerCase();
                final id = req['id'].toString();
                return name.contains(_searchQuery) || id.contains(_searchQuery);
              }).toList();
            }

            if (requests.isEmpty) {
              return Center(
                child: Text(_searchQuery.isEmpty 
                  ? "No ${widget.filterStatus} requests." 
                  : "No matches found.")
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _refreshData(),
              child: ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final String studentName = request['student_name'] ?? "ID: ${request['student']}";
                  final String status = request['status'] ?? "pending";
                  final int requestId = request['id'];
                  final bool isPending = status == 'pending';

                  return Card(
                    elevation: isPending ? 6 : 2,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isPending ? Colors.orange : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(status),
                        child: Icon(_getStatusIcon(status), color: Colors.white, size: 18),
                      ),
                      title: Text(
                        "Request from $studentName",
                        style: TextStyle(fontWeight: isPending ? FontWeight.bold : FontWeight.normal),
                      ),
                      subtitle: Text("Status: ${status.toUpperCase()}"),
                      trailing: isPending 
                        ? const Icon(Icons.notification_important, color: Colors.orange) 
                        : const Icon(Icons.check_circle_outline, color: Colors.green),
                      onTap: () => _showActionDialog(context, requestId, status),
                    ),
                  );
                },
              ),
            );
          }
          return const Center(child: Text("Error loading data. Check Tunnel/Server."));
        },
      ),
    );
  }

  // --- Helper Methods ---

  void _showActionDialog(BuildContext context, int requestId, String currentStatus) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Update Request #$requestId",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Text("Current Status: ${currentStatus.toUpperCase()}"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(context, requestId, 'collected', Colors.green, Icons.check_circle),
                  _actionButton(context, requestId, 'returned', Colors.blue, Icons.assignment_returned),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton(BuildContext context, int id, String status, Color color, IconData icon) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: () async {
        try {
          await apiService.updateStatus(id, status);
          if (!mounted) return;
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Updated to $status")),
          );
          _refreshData(); 
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
      },
      icon: Icon(icon),
      label: Text(status.toUpperCase()),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'collected': return Colors.green;
      case 'returned': return Colors.blue;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'collected': return Icons.shopping_bag;
      case 'returned': return Icons.assignment_returned;
      case 'pending': return Icons.hourglass_empty;
      default: return Icons.help_outline;
    }
  }
}