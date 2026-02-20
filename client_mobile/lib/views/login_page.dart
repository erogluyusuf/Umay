import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? user = await _googleSignIn.signIn();

      if (user != null) {
        print("Giriş Başarılı: ${user.email}");
        await _registerToSentinel(user.email, user.displayName ?? "Android Cihaz");
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      print("Google Giriş Hatası: $error");
      _showSnackBar("Giriş hatası: $error", Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerToSentinel(String email, String deviceName) async {
    final String? baseUrl = dotenv.env['SENTINEL_API_URL'];
    if (baseUrl == null) {
      _showSnackBar("HATA: .env dosyasında API URL bulunamadı!", Colors.red);
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/v1/register-device"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "device_name": deviceName}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String vpnConfigStr = responseData['config'] ?? "";

        _showSnackBar("Umay Sentinel'e Kayıt Başarılı!", Colors.green);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(vpnConfig: vpnConfigStr),
          ),
        );
      } else {
        _showSnackBar("Sunucu reddetti: ${response.statusCode}", Colors.orange);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("İstek Hatası: $e");
      _showSnackBar("Sunucuya bağlanılamadı (IP veya Firewall?).", Colors.red);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
                "UMAY SENTINEL",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0)
            ),
            const SizedBox(height: 50),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.blueAccent)
                : ElevatedButton.icon(
              onPressed: _handleSignIn,
              icon: const Icon(Icons.login),
              label: const Text("Google ile Giriş Yap", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(250, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}