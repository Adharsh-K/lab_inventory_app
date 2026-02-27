import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;
  const RequestDetailPage({super.key, required this.request});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  final ApiService apiService = ApiService();
  bool _isUpdating = false;

  // UPDATED: Now accepts optional quantities map for both Issue and Return flows
  Future<void> _handleUpdate(String newStatus, {Map<int, int>? quantities}) async {
    setState(() => _isUpdating = true);
    try {
      await apiService.updateStatus(
        widget.request['id'], 
        newStatus, 
        issuedItems: quantities
      );
      if (mounted) Navigator.pop(context, true); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var items = widget.request['items'] as List? ?? [];
    String status = widget.request['status'] ?? 'pending';

    return Scaffold(
      appBar: AppBar(title: Text("Request #${widget.request['id']}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Student: ${widget.request['student_name']}", 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(" KTU ID : ${widget.request['student_id']}", style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 17, 169, 93))),
            Text("Status: ${status.toUpperCase()}", 
                style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            const Text("Components List:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  var item = items[index];
                  int req = item['quantity'] ?? 0;
                  int issued = item['issued_quantity'] ?? 0;
                  int returned = item['returned_quantity'] ?? 0;
                  
                  // Calculate remaining and progress percentage
                  int rem = issued - returned;
                  double progress = issued > 0 ? returned / issued : 0.0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['component_name'] ?? "Item", 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(status == 'collected' ? "REM: $rem" : "REQ: $req",
                                  style: TextStyle(color: rem > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (status == 'collected' || status == 'returned') ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(progress == 1.0 ? Colors.green : Colors.blue),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text("$returned of $issued returned", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            if (_isUpdating) 
              const Center(child: CircularProgressIndicator()) 
            else 
              _buildActionButtons(status, items),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'approved': return Colors.green;
      case 'collected': return Colors.blue;
      case 'returned': return Colors.grey;
      default: return Colors.black;
    }
  }

  Widget _buildActionButtons(String status, List items) {
    if (status == 'pending' || status == 'approved') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: () => _showDisburseSheet(items),
          child: const Text("ISSUE COMPONENTS"),
        ),
      );
    } else if (status == 'collected') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          onPressed: () => _showReturnSheet(items),
          child: const Text("PROCESS RETURN"),
        ),
      );
    }
    return const Center(child: Text("All items returned. Request Closed."));
  }

  // --- DISBURSEMENT MODAL ---
  void _showDisburseSheet(List items) {
    Map<int, int> issuedQuantities = {};
    for (var i = 0; i < items.length; i++) {
      issuedQuantities[i] = items[i]['quantity'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Verify Issual Quantities", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...items.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var item = entry.value;
                  return ListTile(
                    title: Text(item['item_name'] ?? "Item"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.remove), onPressed: () {
                          if (issuedQuantities[idx]! > 0) setModalState(() => issuedQuantities[idx] = issuedQuantities[idx]! - 1);
                        }),
                        Text("${issuedQuantities[idx]}"),
                        IconButton(icon: const Icon(Icons.add), onPressed: () => setModalState(() => issuedQuantities[idx] = issuedQuantities[idx]! + 1)),
                      ],
                    ),
                  );
                }),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green),
                  onPressed: () => _showFinalSummary(items, issuedQuantities),
                  child: const Text("REVIEW & CONFIRM", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // --- RETURN MODAL ---
  void _showReturnSheet(List items) {
    Map<int, int> returningQuantities = {};
    for (var i = 0; i < items.length; i++) {
      int issued = items[i]['issued_quantity'] ?? items[i]['quantity'] ?? 0;
      int returned = items[i]['returned_quantity'] ?? 0;
      returningQuantities[i] = issued - returned;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Log Returned Items", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...items.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var item = entry.value;
                  int maxReturn = (item['issued_quantity'] ?? item['quantity']) - (item['returned_quantity'] ?? 0);
                  return ListTile(
                    title: Text(item['item_name'] ?? "Item"),
                    subtitle: Text("Remaining: $maxReturn"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () {
                          if (returningQuantities[idx]! > 0) setModalState(() => returningQuantities[idx] = returningQuantities[idx]! - 1);
                        }),
                        Text("${returningQuantities[idx]}"),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {
                          if (returningQuantities[idx]! < maxReturn) setModalState(() => returningQuantities[idx] = returningQuantities[idx]! + 1);
                        }),
                      ],
                    ),
                  );
                }),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue),
                  onPressed: () {
                    Navigator.pop(context);
                    _handleUpdate('processing_return', quantities: returningQuantities);
                  },
                  child: const Text("CONFIRM RETURN", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFinalSummary(List items, Map<int, int> issued) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Issual"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.asMap().entries.map((e) => Text("${e.value['item_name']}: ${issued[e.key]}")).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BACK")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); Navigator.pop(context);
              _handleUpdate('collected', quantities: issued);
            },
            child: const Text("ISSUE NOW"),
          ),
        ],
      ),
    );
  }
}