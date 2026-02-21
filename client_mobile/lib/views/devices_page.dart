import 'dart:ui';
import 'package:flutter/material.dart';
import 'device_details_page.dart';

class DevicesPage extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final Map<String, String> stats;

  const DevicesPage({
    super.key,
    required this.devices,
    required this.stats
  });

  // --- MARKA LOGOSU BULUCU ---
  String _getBrandLogo(String name) {
    String lowerName = name.toLowerCase();
    if (lowerName.contains("apple") || lowerName.contains("iphone") || lowerName.contains("mac") || lowerName.contains("ipad")) return "apple";
    if (lowerName.contains("samsung") || lowerName.contains("galaxy")) return "samsung";
    if (lowerName.contains("huawei")) return "huawei";
    if (lowerName.contains("xiaomi") || lowerName.contains("redmi") || lowerName.contains("poco")) return "xiaomi";
    if (lowerName.contains("asus")) return "asus";
    if (lowerName.contains("lenovo")) return "lenovo";
    if (lowerName.contains("hp") || lowerName.contains("hewlett")) return "hp";
    if (lowerName.contains("dell")) return "dell";
    if (lowerName.contains("cisco")) return "cisco";
    if (lowerName.contains("tp-link") || lowerName.contains("tplink")) return "tp-link";
    if (lowerName.contains("linux") || lowerName.contains("raspberry")) return "linux";
    if (lowerName.contains("windows") || lowerName.contains("microsoft") || lowerName.contains("pc")) return "windows";
    if (lowerName.contains("sony")) return "sony";
    if (lowerName.contains("lg")) return "lg";

    // Bilinmeyenler için ismin ilk kelimesini deneyelim
    return lowerName.split(" ").first.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // --- YEDEK İKON (LOGO YOKSA) ---
  IconData _getFallbackIcon(String name) {
    String lowerName = name.toLowerCase();
    if (lowerName.contains("apple") || lowerName.contains("samsung") || lowerName.contains("phone")) return Icons.smartphone;
    if (lowerName.contains("tv")) return Icons.tv;
    if (lowerName.contains("linux") || lowerName.contains("server")) return Icons.dns;
    if (lowerName.contains("mac") || lowerName.contains("pc") || lowerName.contains("windows")) return Icons.laptop;
    return Icons.devices_other;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
            "  ",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNetworkInfoCards(),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                    "Active Devices",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: Text(
                      "${devices.length} Devices",
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)
                  ),
                )
              ],
            ),
          ),

          Expanded(
            child: devices.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.cyanAccent),
                  SizedBox(height: 20),
                  Text("Scanning network...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 120),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return _buildGlassDeviceCard(context, devices[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkInfoCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          _buildGlassInfoCard(
              icon: Icons.domain,
              title: "ISP",
              value: stats["isp"] ?? "Scanning..."
          ),
          _buildGlassInfoCard(
              icon: Icons.location_on_outlined,
              title: "Location",
              value: stats["loc"] ?? "Waiting..."
          ),
          _buildGlassInfoCard(
              icon: Icons.language,
              title: "Public IP",
              value: stats["ip"] ?? "0.0.0.0"
          ),
        ],
      ),
    );
  }

  Widget _buildGlassInfoCard({required IconData icon, required String title, required String value}) {
    return Container(
      width: 155,
      height: 100,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDeviceCard(BuildContext context, Map<String, dynamic> device) {
    final isOnline = device["status"] == "Online";
    final deviceName = device["name"]?.toString() ?? "Unknown";
    final deviceIp = device["ip"]?.toString() ?? "0.0.0.0";

    // Hangi markanın logosunu çağıracağımızı bulalım
    final brandFile = _getBrandLogo(deviceName);

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DeviceDetailsPage(device: device))
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    // YENİ: LOGO YÜKLEME VE YEDEK İKON SİSTEMİ
                    child: Center(
                      child: Image.asset(
                        'assets/brands/$brandFile.png', // Örn: assets/brands/apple.png
                        width: 26,
                        height: 26,
                        fit: BoxFit.contain,
                        // Eğer o marka png dosyası yoksa beyaz ikon göster!
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            _getFallbackIcon(deviceName),
                            color: Colors.white,
                            size: 22,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deviceName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(deviceIp, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF34C759) : Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: isOnline ? const Color(0xFF34C759).withOpacity(0.5) : Colors.redAccent.withOpacity(0.5),
                            blurRadius: 8
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}