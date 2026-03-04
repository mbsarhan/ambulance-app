import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

// Entry point for the background service
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // 1. Setup Notification Channel (For the foreground banner)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'ambulance_tracking_channel', // id
    'Tracking Service', // title
    description: 'Running in background to detect ambulances',
    importance: Importance.low, // Low importance so it doesn't make sound constantly
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 2. Configure the Service
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart, // The function to run
      autoStart: false, // We will start it manually
      isForegroundMode: true, // Required to not get killed
      notificationChannelId: 'ambulance_tracking_channel',
      initialNotificationTitle: 'منبه الإسعاف',
      initialNotificationContent: 'جاري مراقبة الطريق...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(), // iOS setup is more complex, skipping for now
  );
}

// ⚠️ This function runs in a separate isolated environment!
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Local Notifications for the ALERT
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 3. Start the Loop
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (await service is AndroidServiceInstance) {
      if (await (service as AndroidServiceInstance).isForegroundService()) {
        // Update the sticky notification text
        flutterLocalNotificationsPlugin.show(
          888,
          'منبه الإسعاف',
          'جاري المسح... ${DateTime.now().hour}:${DateTime.now().minute}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'ambulance_tracking_channel',
              'Tracking Service',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );
      }
    }

    // 4. Get Location & Send to Server
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        await _sendLocationAndCheckAlert(token, position, flutterLocalNotificationsPlugin);
      }
    } catch (e) {
      print("Background Error: $e");
    }
  });
}

// 5. API Call & Sound Trigger
Future<void> _sendLocationAndCheckAlert(
    String token, Position position, FlutterLocalNotificationsPlugin fln) async {
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
      bool isAlert = false;
      if (data.containsKey('alert')) isAlert = data['alert'];

      if (isAlert) {
        _triggerSoundAlert(fln);
      }
    }
  } catch (e) {
    print("API Error: $e");
  }
}

// 6. The Actual Siren Alert
Future<void> _triggerSoundAlert(FlutterLocalNotificationsPlugin fln) async {
  // Define the Siren Channel
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'ambulance_alert_channel', // NEW Channel ID for Alerts
    'Ambulance Alerts',
    channelDescription: 'Plays loud sound when ambulance is near',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    // Refers to android/app/src/main/res/raw/siren_sound.mp3
    sound: RawResourceAndroidNotificationSound('siren_sound'), 
    fullScreenIntent: true, // Wakes up screen
    enableVibration: true,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await fln.show(
    999, // Unique ID for alert
    'تحذير !!!',
    'سيارة إسعاف قريبة منك! أفسح الطريق!',
    platformChannelSpecifics,
  );
}