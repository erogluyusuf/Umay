import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'views/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env dosyasını sisteme yüklüyoruz
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Hata: .env dosyası bulunamadı!");
  }

  runApp(const UmayApp());
}

class UmayApp extends StatelessWidget {
  const UmayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Umay Sentinel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
      ),
      // DÜZELTME: const kaldırıldı çünkü LoginPage içinde dinamik nesneler var.
      home: LoginPage(),
    );
  }
}