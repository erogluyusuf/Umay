import 'package:flutter/material.dart';
import 'main_screen.dart';

class DashboardPage extends StatefulWidget {
  final String vpnConfig;

  const DashboardPage({super.key, required this.vpnConfig});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title": "Umay Sentinel'e\nHoş Geldiniz",
      "description": "Ağ trafiğinizi kontrol altına alın ve siber tehditlere karşı tam koruma sağlayın.",
      "icon": Icons.security,
      "color": Colors.blueAccent,
    },
    {
      "title": "Gerçek Zamanlı\nİzleme",
      "description": "Ağınıza bağlı tüm cihazları anlık olarak görün, paketleri analiz edin.",
      "icon": Icons.radar,
      "color": Colors.cyanAccent,
    },
    {
      "title": "WireGuard Tüneli\nHazır!",
      "description": "Güvenli bağlantı anahtarlarınız sunucu tarafından başarıyla üretildi. Başlamaya hazırsınız.",
      "icon": Icons.vpn_key,
      "color": Colors.greenAccent,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  _pageController.jumpToPage(_onboardingData.length - 1);
                },
                child: const Text("Atla", style: TextStyle(color: Colors.grey)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() {
                    _currentPage = value;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _onboardingData[index]["icon"],
                          size: 120,
                          color: _onboardingData[index]["color"],
                        ),
                        const SizedBox(height: 50),
                        Text(
                          _onboardingData[index]["title"],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _onboardingData[index]["description"],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                          (index) => buildDot(index, context),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _onboardingData.length - 1) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            // DİKKAT: Config verisi asıl ekrana taşınıyor
                            builder: (context) => MainScreen(vpnConfig: widget.vpnConfig),
                          ),
                        );
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentPage == _onboardingData.length - 1
                          ? Colors.greenAccent
                          : Colors.blueAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: Text(
                      _currentPage == _onboardingData.length - 1 ? "Başla" : "İleri",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.blueAccent : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}