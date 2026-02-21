import 'dart:ui';
import 'package:flutter/material.dart';
import 'device_details_page.dart';

class DevicesPage extends StatelessWidget {
  // KRİTİK DÜZELTME: String yerine 'dynamic' kullanıyoruz ki zafiyet listeleri hata vermesin!
  final List<Map<String, dynamic>> devices;
  final Map<String, String> stats;

  const DevicesPage({
    super.key,
    required this.devices,
    required this.stats
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
            " "
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

  // KRİTİK DÜZELTME: Map<String, dynamic> kullanıyoruz
  Widget _buildGlassDeviceCard(BuildContext context, Map<String, dynamic> device) {
    final isOnline = device["status"] == "Online";

    // Veriler dynamic geldiği için .toString() ile güvenli bir şekilde metne çeviriyoruz
    final deviceName = device["name"]?.toString() ?? "Unknown";
    final deviceIp = device["ip"]?.toString() ?? "0.0.0.0";

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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        deviceName.toLowerCase().contains("apple") ||
                            deviceName.toLowerCase().contains("samsung")
                            ? Icons.smartphone
                            : Icons.devices_other,
                        color: Colors.white,
                        size: 20
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