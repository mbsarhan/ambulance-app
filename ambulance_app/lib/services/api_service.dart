import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';

class ApiService {
  
  // 1. Guest Login (Regular User)
  Future<bool> loginAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we already have a Device ID
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4(); // Generate new ID
      await prefs.setString('device_id', deviceId);
    }

    final url = Uri.parse('${AppConstants.baseUrl}/Auth/guest-login');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': deviceId,
          'fcmToken': 'dummy_token_for_now' // We will add FCM later
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('auth_token', data['token']);
        await prefs.setString('user_type', 'Regular');
        return true;
      }
      return false;
    } catch (e) {
      print("Error logging in: $e");
      return false;
    }
  }

  // 2. Driver Login
  Future<bool> loginAsDriver(String username, String password) async {
    final url = Uri.parse('${AppConstants.baseUrl}/Auth/driver-login');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'fcmToken': 'dummy_driver_token'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        await prefs.setString('user_type', 'Ambulance');
        return true;
      }
      return false;
    } catch (e) {
      print("Error logging in driver: $e");
      return false;
    }
  }

  // 3. Update Location
  Future<void> updateLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return;

    final url = Uri.parse('${AppConstants.baseUrl}/Location/update');
    
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token' // Send JWT
        },
        body: jsonEncode({
          'latitude': lat,
          'longitude': lng
        }),
      );
      print("Location sent: $lat, $lng");
    } catch (e) {
      print("Error sending location: $e");
    }
  }

  // 4. Register Driver
  Future<String> registerDriver(String username, String password) async {
    final url = Uri.parse('${AppConstants.baseUrl}/Auth/register-driver');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'fcmToken': '' // Not needed until login
        }),
      );

      if (response.statusCode == 200) {
        return "success";
      } else {
        // Return the error message from the backend (e.g., "Username already exists")
        final data = jsonDecode(response.body);
        return data['message'] ?? "فشل التسجيل"; // Registration failed
      }
    } catch (e) {
      print("Error registering driver: $e");
      return "خطأ في الاتصال بالخادم"; // Server connection error
    }
  }
}