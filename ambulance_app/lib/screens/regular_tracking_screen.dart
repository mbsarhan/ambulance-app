import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this package!
import '../services/background_service.dart'; // Import the new service file

class RegularTrackingScreen extends StatefulWidget {
  const RegularTrackingScreen({super.key});

  @override
  State<RegularTrackingScreen> createState() => _RegularTrackingScreenState();
}

class _RegularTrackingScreenState extends State<RegularTrackingScreen> {
  String _status = "غير نشط";

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startBackgroundService() async {
    // 1. Ask for "Always" Location Permission (Required for background)
    var status = await Permission.locationAlways.request();
    
    if (status.isGranted) {
      setState(() => _status = "جاري تشغيل الخدمة في الخلفية...");
      
      // Initialize the service (This creates the isolates)
      await initializeService();
      
      // Start it
      final service = FlutterBackgroundService();
      await service.startService();
      
      setState(() => _status = "الخدمة تعمل في الخلفية!\nيمكنك إغلاق التطبيق الآن.");
    } else {
      setState(() => _status = "يجب السماح بالموقع 'طوال الوقت' للعمل في الخلفية");
      openAppSettings(); // Force user to settings if denied
    }
  }

  Future<void> _stopBackgroundService() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService"); // You need to handle this in onStart if you want clean stop
    setState(() => _status = "تم إيقاف الخدمة");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("وضع المستخدم (خلفية)")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_moon, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            
            // Start Button
            ElevatedButton.icon(
              onPressed: _startBackgroundService,
              icon: const Icon(Icons.play_arrow),
              label: const Text("تفعيل الحماية في الخلفية"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
            
            const SizedBox(height: 20),

            // Stop Button (Optional)
            ElevatedButton.icon(
              onPressed: _stopBackgroundService,
              icon: const Icon(Icons.stop),
              label: const Text("إيقاف"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}