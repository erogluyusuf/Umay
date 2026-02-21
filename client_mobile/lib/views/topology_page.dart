import 'dart:math';
import 'package:flutter/material.dart';
import 'device_details_page.dart';

class TopologyPage extends StatefulWidget {
  // KRİTİK DÜZELTME: String yerine dynamic kullanıyoruz ki listeler (vulns) hata vermesin.
  final List<Map<String, dynamic>> devices;

  const TopologyPage({super.key, required this.devices});

  @override
  State<TopologyPage> createState() => _TopologyPageState();
}

class _TopologyPageState extends State<TopologyPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getDeviceIcon(String name) {
    name = name.toLowerCase();
    if (name.contains("apple") || name.contains("iphone") || name.contains("samsung") || name.contains("phone")) {
      return Icons.smartphone;
    } else if (name.contains("macbook") || name.contains("laptop") || name.contains("pc")) {
      return Icons.laptop;
    } else if (name.contains("tv") || name.contains("smart tv")) {
      return Icons.tv;
    } else if (name.contains("linux") || name.contains("server") || name.contains("raspberry")) {
      return Icons.dns;
    }
    return Icons.devices_other;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 20),
            Text("Waiting for network discovery...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Connection lines
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: TopologyPainter(
                  deviceCount: widget.devices.length,
                  animationValue: _controller.value,
                ),
                child: Container(),
              );
            },
          ),

          // 2. Umay Hub (Center)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 5),
                    ],
                  ),
                  child: const Icon(Icons.shield, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                    "UMAY HUB",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)
                ),
              ],
            ),
          ),

          // 3. Clickable Discovered Devices
          ...List.generate(widget.devices.length, (index) {
            double angle = (2 * pi / widget.devices.length) * index;
            final device = widget.devices[index];

            // Dynamic veri geldiği için toString() ile güvene alıyoruz
            final deviceName = device["name"]?.toString() ?? "Unknown";

            return Align(
              alignment: Alignment(
                cos(angle) * 0.8,
                sin(angle) * 0.6,
              ),
              child: GestureDetector(
                onTap: () {
                  // Haritadaki cihaza tıklandığında detay sayfasına uçuyoruz!
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceDetailsPage(device: device),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cihaz İkonu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 10),
                        ],
                      ),
                      child: Icon(
                          _getDeviceIcon(deviceName),
                          size: 24,
                          color: Colors.cyanAccent
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Cihaz İsmi
                    SizedBox(
                      width: 80,
                      child: Text(
                        deviceName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class TopologyPainter extends CustomPainter {
  final int deviceCount;
  final double animationValue;

  TopologyPainter({required this.deviceCount, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.2)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    for (int i = 0; i < deviceCount; i++) {
      double angle = (2 * pi / deviceCount) * i;
      Offset deviceOffset = Offset(
        center.dx + cos(angle) * (size.width * 0.4),
        center.dy + sin(angle) * (size.height * 0.3),
      );

      canvas.drawLine(center, deviceOffset, paint);

      double progress = (animationValue + (i / deviceCount)) % 1.0;
      Offset dotPosition = Offset.lerp(center, deviceOffset, progress)!;
      canvas.drawCircle(dotPosition, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TopologyPainter oldDelegate) => true;
}