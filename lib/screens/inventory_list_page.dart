import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key});

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  final ApiService _apiService = ApiService();

  List<dynamic> _allItems = [];      // The "Master" list from the server
  List<dynamic> _filteredItems = []; // The "View" list shown to the user
  List<String> _categories = ["All"]; 
  
  String _selectedCategory = "All";
  String _searchQuery = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      final data = await _apiService.fetchAllItems();
      setState(() {
        _allItems = data;
        _filteredItems = data;
        
        // --- DYNAMIC CATEGORY EXTRACTION ---
        // We pull unique category names directly from the items list
        final uniqueCats = _allItems
            .map((item) => item['category_name'].toString())
            .toSet() // Removes duplicates
            .toList();
        uniqueCats.sort(); 
        
        _categories = ["All", ...uniqueCats];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // This function handles both Search + Dropdown simultaneously
  void _runFilter() {
    setState(() {
      _filteredItems = _allItems.where((item) {
        final String itemName = item['name'].toString().toLowerCase();
        final String itemCat = item['category_name'].toString();
        
        final matchesSearch = itemName.contains(_searchQuery.toLowerCase());
        final matchesCategory = _selectedCategory == "All" || itemCat == _selectedCategory;
        
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Stock Room")),
      body: Column(
        children: [
          // 🛠️ FILTER SECTION
          // 🛠️ UPDATED FILTER SECTION
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
    children: [
      // 1. Search Bar (Takes up 60% of width)
      Expanded(
        flex: 3, 
        child: SizedBox(
          height: 45, // Set a fixed height to keep it compact
          child: TextField(
            onChanged: (val) {
              _searchQuery = val;
              _runFilter();
            },
            decoration: InputDecoration(
              hintText: "Search...",
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // 2. Category Dropdown (Takes up 40% of width)
      Expanded(
        flex: 2,
        child: SizedBox(
          height: 45,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            isExpanded: true, // IMPORTANT: Prevents the dropdown from overflowing internally
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            // Use a smaller font or icon if space is tight
            style: const TextStyle(fontSize: 13, color: Colors.black), 
            items: _categories.map((cat) => DropdownMenuItem(
              value: cat, 
              child: Text(cat, overflow: TextOverflow.ellipsis) // Clips long names
            )).toList(),
            onChanged: (val) {
              setState(() {
                _selectedCategory = val!;
                _runFilter();
              });
            },
          ),
        ),
      ),
    ],
  ),
),

          // 📦 LIST SECTION
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredItems.isEmpty 
                  ? const Center(child: Text("No items match your filter"))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Total: ${item['total_quantity']}"),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${item['available_quantity']}", 
                                  style: TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold,
                                    color: (item['available_quantity'] ?? 0) < 5 ? Colors.red : Colors.green
                                  ),
                                ),
                                const Text("In Lab", style: TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}