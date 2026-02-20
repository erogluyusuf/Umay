import 'dart:ui';
import 'package:flutter/material.dart';
import 'device_details_page.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> devices = [
      {"name": "Galaxy A55", "ip": "192.168.1.15", "mac": "2A:4B:6C:8D:1E:3F", "status": "Online"},
      {"name": "Raspberry Pi ARK", "ip": "192.168.1.20", "mac": "B8:27:EB:CC:DD:22", "status": "Online"},
      {"name": "Main Router", "ip": "192.168.1.1", "mac": "00:14:22:01:23:45", "status": "Online"},
      {"name": "Unknown Laptop", "ip": "192.168.1.45", "mac": "F4:0F:24:1A:2B:3C", "status": "Offline"},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Network Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNetworkInfoCards(),
          const SizedBox(height: 10),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text("Active Devices", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          
          Expanded(
            child: ListView.builder(
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
          _buildGlassInfoCard(icon: Icons.domain, title: "ISP", value: "Turk Telekomunikasyon\nAnonim Sirketi"),
          _buildGlassInfoCard(icon: Icons.location_on_outlined, title: "Location", value: "Kosekoy, Turkey"),
          _buildGlassInfoCard(icon: Icons.language, title: "Public IP", value: "95.10.206.137"),
        ],
      ),
    );
  }

  // GÖRSELDEN ESİNLENİLEN KOYU BUZLU CAM
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
              color: Colors.black.withOpacity(0.15), // Beyazı okutmak için hafif koyu cam
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
                    Text(title, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
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

  Widget _buildGlassDeviceCard(BuildContext context, Map<String, String> device) {
    final isOnline = device["status"] == "Online";

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => DeviceDetailsPage(device: device)));
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
                    child: Icon(isOnline ? Icons.smartphone : Icons.devices_other, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device["name"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(device["ip"]!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
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
                        BoxShadow(color: isOnline ? const Color(0xFF34C759).withOpacity(0.5) : Colors.redAccent.withOpacity(0.5), blurRadius: 8),
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
