import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../constants.dart';
import '../services/background_service.dart'; // تأكد من وجود هذا الملف كما أنشأناه سابقاً

class RegularTrackingScreen extends StatefulWidget {
  const RegularTrackingScreen({super.key});

  @override
  State<RegularTrackingScreen> createState() => _RegularTrackingScreenState();
}

class _RegularTrackingScreenState extends State<RegularTrackingScreen> {
  StreamSubscription<Position>? _positionStreamSubscription;
  String _status = "جاري التحضير...";
  String _lastLocation = "لا توجد بيانات بعد";
  int _updatesSent = 0;

  // متغيرات التنبيه وفترة التبريد (Cooldown)
  bool _isAlertVisible = false;
  DateTime? _lastAlertTime;
  bool _wasAmbulanceInRange = false;

  @override
  void initState() {
    super.initState();
    // بدء التتبع المباشر عند فتح الشاشة
    _startForegroundTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // ==========================================
  // 1. التتبع داخل التطبيق (Foreground)
  // ==========================================
  Future<void> _startForegroundTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _status = "تم رفض إذن الموقع");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = "خدمة الموقع معطلة نهائياً");
      return;
    }

    setState(() => _status = "جاري التتبع الحي...");

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // تحديث كل 10 أمتار
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _updateUI(position);
            _sendToBackend(position);
          },
          onError: (e) {
            setState(() => _status = "حدث خطأ: $e");
          },
        );
  }

  void _updateUI(Position position) {
    setState(() {
      _lastLocation =
          "خط العرض: ${position.latitude.toStringAsFixed(5)}\nخط الطول: ${position.longitude.toStringAsFixed(5)}";
      _status = "نشط ومراقب للمحيط";
    });
  }

  Future<void> _sendToBackend(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

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

        // التحقق من مرور دقيقتين على الأقل منذ آخر تنبيه
        bool hasCooldownPassed = _lastAlertTime == null || 
            DateTime.now().difference(_lastAlertTime!).inMinutes >= 2;

        if (isAlertNow && !_wasAmbulanceInRange) {
          // سيارة الإسعاف دخلت النطاق للتو
          if (hasCooldownPassed) {
            _lastAlertTime = DateTime.now(); // تحديث وقت آخر تنبيه
            _triggerAlert();
          } else {
            print("الإسعاف دخل النطاق، لكن التنبيه في فترة التبريد (Cooldown).");
          }
        }

        // تحديث الحالة للمرة القادمة
        _wasAmbulanceInRange = isAlertNow; 

        if (mounted) {
          setState(() => _updatesSent++);
        }
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  // واجهة التنبيه المنبثقة (الأحمر)
  void _triggerAlert() {
    if (_isAlertVisible) return;
    _isAlertVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false, // يجب على المستخدم الضغط على الزر للإغلاق
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.white, size: 30),
            SizedBox(width: 10),
            Text(
              "تـحـذيــر !",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "سيارة إسعاف تقترب من موقعك الحالي!\nالرجاء إفساح الطريق فوراً.",
          style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isAlertVisible = false;
            },
            style: TextButton.styleFrom(backgroundColor: Colors.white),
            child: const Text(
              "حسناً، فهمت",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. خدمة الخلفية (Background Service)
  // ==========================================
  Future<void> _startBackgroundService() async {
    var status = await Permission.locationAlways.request();

    if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("جاري تشغيل الحماية في الخلفية..."),
          backgroundColor: Colors.green,
        ),
      );

      await initializeService(); // تهيئة الخدمة
      final service = FlutterBackgroundService();
      await service.startService();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("الخدمة تعمل! يمكنك إغلاق التطبيق الآن."),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يجب السماح بالموقع 'طوال الوقت' للعمل في الخلفية"),
          backgroundColor: Colors.red,
        ),
      );
      openAppSettings(); // إجبار المستخدم على فتح الإعدادات
    }
  }

  Future<void> _stopBackgroundService() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("تم إيقاف خدمة الخلفية")));
  }

  // ==========================================
  // بناء واجهة المستخدم
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة المستخدم"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.radar, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                Text(
                  _status,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // مربع إحداثيات الموقع
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                  ),
                  child: Text(
                    _lastLocation,
                    style: const TextStyle(
                      fontSize: 18,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                    textDirection:
                        TextDirection.ltr, // لضمان بقاء الأرقام واضحة
                  ),
                ),

                const SizedBox(height: 15),
                Text(
                  "التحديثات المرسلة: $_updatesSent",
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 40),

                // زر تفعيل الخلفية
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _startBackgroundService,
                    icon: const Icon(Icons.security),
                    label: const Text(
                      "تفعيل الحماية في الخلفية",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // زر إيقاف الخلفية
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _stopBackgroundService,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text(
                      "إيقاف خدمة الخلفية",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // زر الخروج
                TextButton.icon(
                  onPressed: () {
                    _positionStreamSubscription?.cancel();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    "إيقاف التتبع الحي والرجوع",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
