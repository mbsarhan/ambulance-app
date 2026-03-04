import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _isBroadcasting = false;
  String _status = "خامل"; // Idle
  int _nearbyUsersCount = 0;
  StreamSubscription<Position>? _positionStreamSubscription;

  void _toggleBroadcast() async {
    if (_isBroadcasting) {
      _positionStreamSubscription?.cancel();
      setState(() {
        _isBroadcasting = false;
        _status = "خامل";
        _nearbyUsersCount = 0;
      });
    } else {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
          return;
        }
      }

      setState(() {
        _isBroadcasting = true;
        _status = "جاري بث الموقع..."; // Broadcasting...
      });

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, 
      );

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) {
        _sendLocationAndCheckProximity(position);
      });
    }
  }

  Future<void> _sendLocationAndCheckProximity(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final url = Uri.parse('${AppConstants.baseUrl}/Location/update');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _nearbyUsersCount = data['nearbyUsersCount'] ?? 0;
            _status = "نشط | خط العرض: ${position.latitude.toStringAsFixed(4)}";
          });
        }
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة تحكم الإسعاف"), // Ambulance Dashboard
        backgroundColor: _isBroadcasting ? Colors.red : Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isBroadcasting ? Icons.fmd_good : Icons.fmd_good_outlined,
              size: 100,
              color: _isBroadcasting ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 20),
            
            Text(
              _status,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            if (_isBroadcasting) ...[
              const Text("مستخدمون في النطاق:", style: TextStyle(fontSize: 18)), // Users in range
              Text(
                "$_nearbyUsersCount",
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const Text("(يتم إرسال التنبيهات تلقائياً)", style: TextStyle(color: Colors.grey)), // Alerts sent automatically
            ],

            const SizedBox(height: 50),

            ElevatedButton.icon(
              onPressed: _toggleBroadcast,
              icon: Icon(_isBroadcasting ? Icons.stop : Icons.play_arrow),
              label: Text(_isBroadcasting ? "إيقاف وضع الطوارئ" : "بدء وضع الطوارئ"), // Stop/Start Emergency Mode
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                backgroundColor: _isBroadcasting ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}