import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرجاء تعبئة جميع الحقول")), // Fill all fields
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("كلمات المرور غير متطابقة")), // Passwords don't match
      );
      return;
    }

    setState(() => _isLoading = true);
    
    String result = await ApiService().registerDriver(
      _usernameController.text, 
      _passwordController.text
    );

    setState(() => _isLoading = false);

    if (result == "success") {
      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("تم التسجيل بنجاح"), // Success
          content: const Text("تم إرسال طلبك للإدارة. يرجى الانتظار حتى يتم تفعيل حسابك لتتمكن من تسجيل الدخول."), // Wait for admin
          actions:[
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to login screen
              },
              child: const Text("حسناً"), // OK
            )
          ],
        ),
      );
    } else {
      // Show error (e.g., Username exists)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إنشاء حساب سائق")), // Create Driver Account
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children:[
            const Icon(Icons.app_registration, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController, 
              decoration: const InputDecoration(
                labelText: "اسم المستخدم", // Username
                prefixIcon: Icon(Icons.person)
              )
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController, 
              decoration: const InputDecoration(
                labelText: "كلمة المرور", // Password
                prefixIcon: Icon(Icons.lock)
              ), 
              obscureText: true
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _confirmPasswordController, 
              decoration: const InputDecoration(
                labelText: "تأكيد كلمة المرور", // Confirm Password
                prefixIcon: Icon(Icons.lock_outline)
              ), 
              obscureText: true
            ),
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator()
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _register, 
                    child: const Text("تسجيل الحساب", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)) // Register
                  ),
                ),
          ],
        ),
      ),
    );
  }
}