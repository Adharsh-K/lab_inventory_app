import 'package:flutter/material.dart';
import 'inventory_list_page.dart';
import 'add_component_page.dart';

class InventoryHubPage extends StatelessWidget {
  const InventoryHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory Management")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _inventoryCard(
              context,
              "View Stock",
              "Check current quantities and availability",
              Icons.inventory_2,
              Colors.teal,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryListPage())),
            ),
            const SizedBox(height: 16),
            _inventoryCard(
              context,
              "Add New Component",
              "Register new parts or restock existing ones",
              Icons.add_circle_outline,
              Colors.orange,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddComponentPage())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inventoryCard(BuildContext context, String title, String desc, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(desc, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}