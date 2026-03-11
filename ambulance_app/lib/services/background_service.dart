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
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Tracking channel (existing)
  const AndroidNotificationChannel trackingChannel = AndroidNotificationChannel(
    'ambulance_tracking_channel',
    'Tracking Service',
    description: 'Running in background to detect ambulances',
    importance: Importance.low,
  );

  // ✅ ADD THIS: Alert channel for the siren
  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'ambulance_alert_channel',
    'Ambulance Alerts',
    description: 'Plays loud sound when ambulance is near',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('siren_sound'),
    enableVibration: true,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(trackingChannel);
  await androidPlugin?.createNotificationChannel(alertChannel); // ✅ Create alert channel

  // Initialize the plugin (also missing from original!)
  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'ambulance_tracking_channel',
      initialNotificationTitle: 'منبه الإسعاف',
      initialNotificationContent: 'جاري مراقبة الطريق...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

// ⚠️ This function runs in a separate isolated environment!
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();

  // ✅ Must initialize inside the isolate too
  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await fln.initialize(initSettings);

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    // Check if service should stop
    if (service is AndroidServiceInstance) {
      if (!await service.isForegroundService()) {
        timer.cancel();
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        await _sendLocationAndCheckAlert(token, position, fln);
      }
    } catch (e) {
      print("Background Error: $e");
    }
  });

  // ✅ Handle stop command
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

// 5. API Call & Sound Trigger (State + Cooldown)
Future<void> _sendLocationAndCheckAlert(
    String token, Position position, FlutterLocalNotificationsPlugin fln) async {
  try {
    final url = Uri.parse('${AppConstants.baseUrl}/Location/update');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      bool isAlertNow = data['alert'] ?? false;

      final prefs = await SharedPreferences.getInstance();
      
      bool wasAlertBefore = prefs.getBool('was_ambulance_in_range') ?? false;
      int lastAlertTimestamp = prefs.getInt('last_alert_time') ?? 0;
      int now = DateTime.now().millisecondsSinceEpoch;

      // 120,000 ms = 2 Minutes Cooldown
      bool hasCooldownPassed = (now - lastAlertTimestamp) > 120000;

      if (isAlertNow && !wasAlertBefore) {
        // Ambulance ENTERED the radius
        if (hasCooldownPassed) {
          await _triggerSoundAlert(fln);
          await prefs.setInt('last_alert_time', now); // Save the exact time we played the sound
          print("Ambulance entered radius — alert fired!");
        } else {
          print("Ambulance entered radius, but siren is on COOLDOWN.");
        }
      } else if (isAlertNow && wasAlertBefore) {
        // Ambulance is still in range — do nothing
        print("Ambulance still in range — waiting for it to exit.");
      } else if (!isAlertNow && wasAlertBefore) {
        // Ambulance LEFT the radius
        print("Ambulance exited radius.");
      }

      // Always save the current state for next iteration
      await prefs.setBool('was_ambulance_in_range', isAlertNow);
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