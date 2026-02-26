import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddComponentPage extends StatefulWidget {
  const AddComponentPage({super.key});

  @override
  State<AddComponentPage> createState() => _AddComponentPageState();
}

class _AddComponentPageState extends State<AddComponentPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _apiService.fetchCategories();
    setState(() => _categories = cats);
  }

  // Popup dialog to add a new category string to the DB
  void _showAddCategoryDialog() {
    final TextEditingController _catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Category"),
        content: TextField(
          controller: _catController,
          decoration: const InputDecoration(hintText: "e.g. Sensors, Tools"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_catController.text.trim().isNotEmpty) {
                final success = await _apiService.addCategory(_catController.text.trim());
                if (success) {
                  Navigator.pop(context); // Close dialog
                  _loadCategories(); // Refresh dropdown list
                }
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and select a category")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await _apiService.addComponent(
      name: _nameController.text.trim(),
      totalQuantity: int.parse(_qtyController.text),
      categoryId: _selectedCategoryId!,
    );

    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Component Added!")));
      Navigator.pop(context); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add component")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register New Component")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Component Name",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? "Enter a name" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Initial Stock Quantity",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => (val == null || int.tryParse(val) == null) ? "Enter a valid number" : null,
              ),
              const SizedBox(height: 20),

              // --- CATEGORY ROW ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'],
                          child: Text(cat['name']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                      validator: (val) => val == null ? "Select a category" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Button to trigger the Quick Add Dialog
                  Container(
                    height: 58, // Matches the height of the OutlineInputBorder
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.teal),
                      onPressed: _showAddCategoryDialog,
                      tooltip: "Add New Category",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isSaving ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.teal,
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save to Inventory", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}