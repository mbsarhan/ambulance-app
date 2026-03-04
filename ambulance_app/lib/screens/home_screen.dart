import 'package:flutter/material.dart';
import 'driver_login_screen.dart';
import 'regular_tracking_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade800, Colors.blue.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_services, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              "منبه الإسعاف", // App Title
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 50),

            // Regular User Button
            _buildRoleButton(
              context,
              "أنا مستخدم عادي", // I am a regular user
              Icons.person,
              () async {
                bool success = await ApiService().loginAsGuest();
                if (success) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RegularTrackingScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("خطأ في الاتصال بالخادم")), // Server Error
                  );
                }
              },
            ),

            const SizedBox(height: 20),

            // Driver Button
            _buildRoleButton(
              context,
              "أنا سائق إسعاف", // I am an ambulance driver
              Icons.directions_car,
              () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverLoginScreen()));
              },
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(BuildContext context, String text, IconData icon, VoidCallback onTap, {bool isPrimary = true}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white : Colors.blue.shade700,
          foregroundColor: isPrimary ? Colors.blue.shade900 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}