import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Hafıza kontrolü için eklendi

import 'views/login_page.dart';
import 'views/main_screen.dart'; // Otomatik giriş için eklendi

Future<void> main() async {
  // 1. Flutter motorunu başlat
  WidgetsFlutterBinding.ensureInitialized();

  // 2. UI ve Ekran Yönü Ayarları
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 3. .env Dosyasını Yükle
  try {
    await dotenv.load(fileName: ".env");
    print("✅ INFO: .env file loaded successfully.");
  } catch (e) {
    print("❌ CRITICAL ERROR: .env file not found! Details: $e");
  }

  // ==========================================
  // 4. HAFIZAYI (OTURUM DURUMUNU) KONTROL ET
  // ==========================================
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String vpnConfig = prefs.getString('vpnConfig') ?? "";

  // 5. Uygulamayı başlat ve hafızadan gelen verileri içeri aktar
  runApp(UmayApp(isLoggedIn: isLoggedIn, vpnConfig: vpnConfig));
}

class UmayApp extends StatelessWidget {
  final bool isLoggedIn;
  final String vpnConfig;

  // Parametreleri kurucu (constructor) metoda ekledik
  const UmayApp({
    super.key,
    required this.isLoggedIn,
    required this.vpnConfig
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Umay Sentinel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.cyanAccent,
          surface: Color(0xFF161B22),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1117),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      // ==========================================
      // KRİTİK NOKTA: GİRİŞ YAPILDIYSA MAIN SCREEN'E, YAPILMADIYSA LOGIN'E
      // ==========================================
      home: isLoggedIn ? MainScreen(vpnConfig: vpnConfig) : LoginPage(),
    );
  }
}