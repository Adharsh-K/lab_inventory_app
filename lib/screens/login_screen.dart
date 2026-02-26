import 'package:flutter/material.dart';
import 'landing_page.dart';
import '../services/api_service.dart';
// To navigate to InchargeDashboard

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    
    bool success = await _apiService.login(
      _usernameController.text, 
      _passwordController.text
    );

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LandingPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid Credentials. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person, size: 80, color: Colors.blueGrey),
              SizedBox(height: 20),
              Text("MEC IdeaLab", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              Text("Incharge Portal", style: TextStyle(color: Colors.grey[600])),
              SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: "Username", border: OutlineInputBorder()),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                obscureText: true,
              ),
              SizedBox(height: 30),
              _isLoading 
                ? CircularProgressIndicator() 
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                      onPressed: _handleLogin,
                      child: Text("LOGIN"),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}