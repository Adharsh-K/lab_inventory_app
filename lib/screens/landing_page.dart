import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'request_list_page.dart';
import 'history_page.dart';
import 'inventory_hub_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("MEC IdeaLab Hub"),
        centerTitle: true,
        elevation: 0, // Clean look
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ApiService.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // --- LOGO SECTION ---
            Center(
              child: Column(
                children: [
                  Image.asset(
                    '../../assets/logo/logo.png',
                    height: 100, // Slightly reduced to fit grid better
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // --- WELCOME SECTION ---
            const Text(
              "Welcome, Incharge",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              "Select an action to continue",
              style: TextStyle(color: Colors.grey[600]),
            ),
            
            const SizedBox(height: 20),

            // --- ACTION GRID ---
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  _hubCard(
                    context,
                    "Disburse",
                    "Pending requests",
                    Icons.outbox,
                    Colors.orange,
                    () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const RequestListPage(
                        title: "Pending Disbursals", 
                        filterStatus: "issue",
                      ),
                    )),
                  ),
                  _hubCard(
                    context,
                    "Returns",
                    "Active issuals",
                    Icons.assignment_returned,
                    Colors.blue,
                    () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const RequestListPage(
                        title: "Component Returns", 
                        filterStatus: "collected",
                      ),
                    )),
                  ),
                  _hubCard(
                    context,
                    "View History",
                    "Audit Logs",
                    Icons.history,
                    Colors.blueGrey,
                    () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const HistoryPage(),
                    )),
                  ),
                  _hubCard(
                    context,
                    "Inventory",
                    "Check stock levels",
                    Icons.inventory_2,
                    Colors.purple,
                    () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const InventoryHubPage(),
                    )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hubCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 10),
            Text(
              title, 
              textAlign: TextAlign.center, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle, 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}