import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 20, bottom: 100), 
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildNetworkInfoCards(),
        const SizedBox(height: 30),
        _buildDeviceListSection(),
      ],
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        "Network Status",
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.black87),
      ),
    );
  }

  Widget _buildNetworkInfoCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildInfoCard(icon: Icons.domain, title: "ISP", value: "Turk Telekomunikasyon\nAnonim Sirketi"),
          _buildInfoCard(icon: Icons.location_on_outlined, title: "Location", value: "Kosekoy, Turkey"),
          _buildInfoCard(icon: Icons.language, title: "Public IP", value: "95.10.206.137"),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return Container(
      width: 140,
      height: 125,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 26),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceListSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Active Devices", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildDeviceItem("Galaxy A55 (This Device)", "192.168.1.15", true),
          _buildDeviceItem("Raspberry Pi 5 (ARK)", "192.168.1.20", false),
          _buildDeviceItem("Main Router", "192.168.1.1", false),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(String name, String ip, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF34C759).withOpacity(0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCurrent ? Icons.smartphone : Icons.router_outlined,
              color: isCurrent ? const Color(0xFF34C759) : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600)),
                const SizedBox(height: 4),
                Text(ip, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
