import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ApiService {
  // Use your production domain
  static const String baseUrl = 'https://ilabmec.engineer/api';
  
  // Static token to persist across different screens during the session
  static String? _token;

  // ==========================================
  // 🔑 AUTHENTICATION
  // ==========================================

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        body: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token']; // Save token for subsequent requests
        return true;
      }
      print("Login failed: ${response.body}");
      return false;
    } catch (e) {
      print("Login Network Error: $e");
      return false;
    }
  }

  static void logout() {
    _token = null;
  }

  // ==========================================
  // 📦 REQUESTS & INVENTORY
  // ==========================================

  /// Fetches the list of all requests for the Incharge
  Future<List<dynamic>> fetchPendingRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/requests/'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Fetch Error: ${response.body}");
        throw Exception('Failed to load requests');
      }
    } catch (e) {
      throw Exception('Network Error: $e');
    }
  }

  /// Updates status and sends adjusted quantities to Django
  Future<void> updateStatus(int id, String status, {Map<int, int>? issuedItems}) async {
    final String url = '$baseUrl/requests/$id/update/'; 
    
    Map<String, int>? formattedItems;
    if (issuedItems != null) {
      formattedItems = issuedItems.map((key, value) => MapEntry(key.toString(), value));
    }

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: _authHeaders,
        body: jsonEncode({
          "status": status,
          "issued_items": formattedItems,
        }),
      );

      if (response.statusCode != 200) {
        print("DJANGO ERROR: ${response.body}"); 
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print("Update Error: $e");
      rethrow;
    }
  }

  // ==========================================
  // 📜 HISTORY & AUDIT
  // ==========================================

  /// Fetches history with optional date range and Student ID filters
  /// Fetches history with pagination, date range, and Student ID filters
  /// Changed return type to Map<String, dynamic> to support pagination metadata
  Future<Map<String, dynamic>> getHistory({
  int page = 1,
  DateTime? startDate,
  DateTime? endDate,
  String? studentId,
}) async {
  // Use 'page' in the URL - this triggers Django's PageNumberPagination
  String url = '$baseUrl/history/?page=$page'; 

  if (startDate != null && endDate != null) {
    url += '&start_date=${DateFormat('yyyy-MM-dd').format(startDate)}';
    url += '&end_date=${DateFormat('yyyy-MM-dd').format(endDate)}';
  }
  if (studentId != null && studentId.trim().isNotEmpty) {
    url += '&student_id=${studentId.trim()}';
  }

  try {
    final response = await http.get(Uri.parse(url), headers: _authHeaders);
    
    if (response.statusCode == 200) {
      final decodedData = jsonDecode(response.body);
      
      // If Django isn't paginating, it returns a List. We must return a Map.
      if (decodedData is List) {
        return {
          'count': decodedData.length,
          'next': null,
          'previous': null,
          'results': decodedData
        };
      }
      return decodedData as Map<String, dynamic>;
    } else {
      throw Exception("Server Error: ${response.statusCode}");
    }
  } catch (e) {
    rethrow; // Pass it to the HistoryPage debug printer
  }
}

  // ==========================================
  // 🛠️ HELPERS
  // ==========================================

  /// Helper to provide headers including the Token auth
  Map<String, String> get _authHeaders => {
        "Content-Type": "application/json",
        if (_token != null) "Authorization": "Token $_token",
      };

  // 1. Fetch all items for the "View Stock" page
Future<List<dynamic>> fetchAllItems() async {
  final response = await http.get(
    Uri.parse('$baseUrl/items/'), 
    headers: _authHeaders,
  );
  if (response.statusCode == 200) {
    return json.decode(response.body);
  }
  throw Exception('Failed to load inventory');
}

// 2. Post a new component for the "Add Component" page
Future<bool> addItem(String name, int quantity, String category) async {
  final response = await http.post(
    Uri.parse('$baseUrl/items/add/'),
    headers: _authHeaders,
    body: jsonEncode({
      'name': name,
      'total_quantity': quantity,
      'category': category,
    }),
  );
  return response.statusCode == 201;
}
Future<bool> addComponent({
  required String name,
  required int totalQuantity,
  required int categoryId, // We send the ID, not the name string
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/items/add/'), // Ensure this matches your Django URL
      headers: _authHeaders,
      body: jsonEncode({
        "name": name,
        "total_quantity": totalQuantity,
        "available_quantity": totalQuantity, // Initially, they are the same
        "category": categoryId,
      }),
    );

    if (response.statusCode == 201) return true;
    print("Add Error: ${response.body}");
    return false;
  } catch (e) {
    print("Network Error: $e");
    return false;
  }
}
// ==========================================
  // 📂 CATEGORIES
  // ==========================================

  /// Fetches all available categories for the dropdowns
  Future<List<dynamic>> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/'), // Ensure this matches your urls.py
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Category Fetch Error: ${response.body}");
        return []; // Return empty list if server fails
      }
    } catch (e) {
      print("Network Error fetching categories: $e");
      return [];
    }
  }
Future<bool> addCategory(String name) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/categories/add/'),
      headers: _authHeaders,
      body: jsonEncode({"name": name}),
    );
    return response.statusCode == 201;
  } catch (e) {
    print("Error adding category: $e");
    return false;
  }
}
Future<Map<String, dynamic>> fetchHistory({int page = 1}) async {
  final response = await http.get(
    Uri.parse('$baseUrl/history/?page=$page'),
    headers: _authHeaders,
  );
  if (response.statusCode == 200) {
    return json.decode(response.body);
  }
  throw Exception('Failed to load history');
}
}