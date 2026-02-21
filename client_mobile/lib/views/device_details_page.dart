import 'dart:ui';
import 'dart:io'; // EKLENDİ: Ping ve Socket işlemleri için
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';

class DeviceDetailsPage extends StatefulWidget {
  final Map<String, dynamic> device;
  const DeviceDetailsPage({super.key, required this.device});

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> with SingleTickerProviderStateMixin {
  WebSocketChannel? _channel;
  Timer? _pingTimer;

  // --- DATA VARIABLES ---
  String _pingResult = "Ready";
  bool _isBlocked = false;
  bool _isAutoPinging = false;
  bool _isScanningPorts = false;

  bool _isSniffing = false;
  List<Map<String, String>> _trafficLogs = [];

  List<int>? _openPorts;
  List<FlSpot> _pingSpots = [];
  double _xCount = 0;

  // Cihazın MAC adresi Android tarafından gizlendiyse (Hidden by OS), Local moddayız demektir.
  bool get _isLocalMode => widget.device['mac'] == "Hidden by OS";

  @override
  void initState() {
    super.initState();
    if (!_isLocalMode) {
      _connectToUmayServer();
    }
  }

  void _connectToUmayServer() {
    final String? baseUrl = dotenv.env['SENTINEL_API_URL'];
    if (baseUrl == null) return;

    String cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    final String wsUrl = cleanUrl.replaceFirst("http://", "ws://").replaceFirst("https://", "wss://") + "/ws/traffic";

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen((message) {
        final data = jsonDecode(message);

        // 1. PING RESULT
        if (data['type'] == 'ping_result' && data['ip'] == widget.device['ip']) {
          double pingVal = double.tryParse(data['value'].toString()) ?? 0;
          setState(() {
            _pingResult = "${pingVal.toInt()} ms";
            _pingSpots.add(FlSpot(_xCount, pingVal));
            _xCount++;
            if (_pingSpots.length > 40) _pingSpots.removeAt(0);
          });
        }

        // 2. PORT SCAN RESULT
        if ((data['type'] == 'scan_result' || data['action'] == 'scan_complete') && data['ip'] == widget.device['ip']) {
          setState(() {
            _openPorts = List<int>.from(data['ports'] ?? []);
            _isScanningPorts = false;
          });
        }

        // 3. GERÇEK TRAFİK AKIŞI (Sunucu Modu)
        if (_isSniffing && !_isLocalMode && data.containsKey('source') && data.containsKey('destination')) {
          if (data['source'] == widget.device['ip'] || data['mac'] == widget.device['mac']) {
            setState(() {
              String timeStr = DateTime.now().toLocal().toString().split(' ')[1].substring(0, 8);
              _trafficLogs.insert(0, {
                "time": timeStr,
                "dest": data['destination'].toString(),
              });
              if (_trafficLogs.length > 15) _trafficLogs.removeLast();
            });
          }
        }
      });
    } catch (e) {
      print("WS Connection Error: $e");
    }
  }

  void _toggleAutoPing() {
    setState(() {
      _isAutoPinging = !_isAutoPinging;
      if (_isAutoPinging) {
        _pingResult = "Tracking...";
        _pingSpots.clear();
        _xCount = 0;

        _pingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_isLocalMode) {
            // Local Modda cihaz üzerinden manuel ping at (Düzeltildi)
            Process.run('ping', ['-c', '1', '-W', '1', widget.device['ip']]).then((result) {
              if (result.exitCode == 0 && mounted) {
                // Ping çıktısından süreyi ayıkla (Örn: time=15.2 ms)
                final match = RegExp(r'time=([\d.]+)\s*ms').firstMatch(result.stdout.toString());
                double pingTime = 0.0;
                if (match != null && match.groupCount >= 1) {
                  pingTime = double.tryParse(match.group(1)!) ?? 0.0;
                }
                setState(() {
                  _pingResult = "${pingTime.toInt()} ms";
                  _pingSpots.add(FlSpot(_xCount, pingTime));
                  _xCount++;
                  if (_pingSpots.length > 40) _pingSpots.removeAt(0);
                });
              }
            });
          } else {
            _channel?.sink.add(jsonEncode({"action": "get_ping", "ip": widget.device["ip"]}));
          }
        });
      } else {
        _pingTimer?.cancel();
        _pingResult = "Ready";
      }
    });
  }

  void _startPortScan() {
    if (_isScanningPorts) return;
    setState(() {
      _isScanningPorts = true;
      _openPorts = null;
    });

    if (_isLocalMode) {
      // Local Mod: Cihaz üzerinden basit bir socket taraması (Düzeltildi)
      Future(() async {
        List<int> foundPorts = [];
        List<int> commonPorts = [21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 3306, 3389, 8000, 8080];

        for (int port in commonPorts) {
          try {
            final socket = await Socket.connect(widget.device['ip'], port, timeout: const Duration(milliseconds: 200));
            foundPorts.add(port);
            socket.destroy();
          } catch (_) {} // Bağlanamazsa hata fırlatır, geçiyoruz.
        }

        if (mounted) {
          setState(() {
            _openPorts = foundPorts;
            _isScanningPorts = false;
          });
        }
      });
    } else {
      _channel?.sink.add(jsonEncode({"action": "start_scan", "ip": widget.device["ip"]}));
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _isScanningPorts) {
          setState(() {
            _isScanningPorts = false;
            _openPorts = [];
          });
        }
      });
    }
  }

  void _toggleBlock() {
    if (_isLocalMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KILL switch requires Umay Server connection (Root).'), backgroundColor: Colors.orange));
      return;
    }
    setState(() { _isBlocked = !_isBlocked; });
    _channel?.sink.add(jsonEncode({"action": "toggle_kill", "ip": widget.device["ip"], "state": _isBlocked}));
  }

  void _toggleSniffing() {
    setState(() {
      _isSniffing = !_isSniffing;
      if (!_isSniffing) {
        _trafficLogs.clear();
      }
    });
  }

  Future<void> _launchPortUrl(int port) async {
    String scheme = (port == 443 || port == 8443) ? 'https' : 'http';
    final Uri url = Uri.parse('$scheme://${widget.device["ip"]}:$port');

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the browser for this port.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> vulns = [];
    if (widget.device.containsKey('vulns') && widget.device['vulns'] is List) {
      vulns = widget.device['vulns'];
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(title: Text(widget.device["name"]!.toString().toUpperCase(), style: const TextStyle(fontSize: 14, letterSpacing: 2))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeaderStatus(),
            const SizedBox(height: 30),

            _buildControlPanel(),
            const SizedBox(height: 30),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isAutoPinging ? _buildLiveChart() : const SizedBox.shrink(),
            ),
            if (_isAutoPinging) const SizedBox(height: 30),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isSniffing ? _buildTrafficFlowSection() : const SizedBox.shrink(),
            ),
            if (_isSniffing) const SizedBox(height: 30),

            _buildVulnSection(vulns),
            const SizedBox(height: 30),

            if (_openPorts != null || _isScanningPorts) _buildPortSection(),
            if (_openPorts != null || _isScanningPorts) const SizedBox(height: 30),

            _buildStaticDetails(),
          ],
        ),
      ),
    );
  }

  // --- TRAFİK AKIŞI (FLOW) EKRANI ---
  Widget _buildTrafficFlowSection() {
    return Container(
      width: double.infinity,
      height: 250,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isLocalMode ? Colors.redAccent.withOpacity(0.5) : Colors.purpleAccent.withOpacity(0.5))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                      _isLocalMode ? Icons.gavel : Icons.wifi_tethering,
                      color: _isLocalMode ? Colors.redAccent : Colors.purpleAccent,
                      size: 16
                  ),
                  const SizedBox(width: 8),
                  Text(
                      _isLocalMode ? "ACCESS DENIED" : "LIVE TRAFFIC INTERCEPT",
                      style: TextStyle(
                          color: _isLocalMode ? Colors.redAccent : Colors.purpleAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1
                      )
                  ),
                ],
              ),
              if (!_isLocalMode)
                const SizedBox(
                    height: 12, width: 12,
                    child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2)
                ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Expanded(
            child: _isLocalMode
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text("> Listening on interface wlan0...", style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                SizedBox(height: 5),
                Text("[!] FATAL: Operation not permitted", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text("[!] ERROR: Cannot capture packets on a non-root environment.", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                SizedBox(height: 15),
                Text("SUGGESTION: Connect to Umay Node (Server Mode) to intercept network traffic.", style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace')),
              ],
            )
                : _trafficLogs.isEmpty
                ? const Center(child: Text("Listening for packets on Port 53...", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)))
                : ListView.builder(
              itemCount: _trafficLogs.length,
              itemBuilder: (context, index) {
                final log = _trafficLogs[index];
                double opacity = 1.0 - (index * 0.06);
                if (opacity < 0.2) opacity = 0.2;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Opacity(
                    opacity: opacity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("[${log['time']}] ", style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace')),
                        const Text("OUT -> ", style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                        Expanded(
                            child: Text(
                              log['dest']!,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            )
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVulnSection(List<dynamic> vulns) {
    bool isSafe = vulns.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isSafe ? Colors.greenAccent.withOpacity(0.05) : Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSafe ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isSafe ? Icons.verified_user : Icons.dangerous, color: isSafe ? Colors.greenAccent : Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Text(isSafe ? "SYSTEM SECURE" : "DANGER: VULNERABILITIES DETECTED", style: TextStyle(color: isSafe ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            ],
          ),
          const SizedBox(height: 15),
          if (isSafe)
            const Text("No known vulnerabilities or open exploits detected for this device.", style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic))
          else
            ...vulns.map((vuln) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• ", style: TextStyle(color: Colors.redAccent)),
                  Expanded(child: Text(vuln.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                ],
              ),
            )).toList(),
        ],
      ),
    );
  }

  Widget _buildPortSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("OPEN PORTS RECON", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          if (_isScanningPorts)
            const LinearProgressIndicator(backgroundColor: Colors.white10, color: Colors.orangeAccent)
          else if (_openPorts != null && _openPorts!.isEmpty)
            const Text("ALL SCANNED PORTS ARE CLOSED OR FILTERED.", style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic))
          else if (_openPorts != null)
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _openPorts!.map((p) => GestureDetector(
                  onTap: () => _launchPortUrl(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blueAccent.withOpacity(0.5))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Icon((p == 80 || p == 443 || p == 8000 || p == 8080) ? Icons.public : Icons.lan, color: Colors.blueAccent, size: 12)
                      ],
                    ),
                  ),
                )).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionBtn(Icons.analytics, "TRACK", _isAutoPinging, _toggleAutoPing, Colors.cyanAccent),
        _actionBtn(Icons.radar, "SCAN", _isScanningPorts, _startPortScan, Colors.orangeAccent),
        _actionBtn(Icons.filter_alt, "FLOW", _isSniffing, _toggleSniffing, Colors.purpleAccent),
        _actionBtn(_isBlocked ? Icons.lock_open : Icons.front_hand, "KILL", _isBlocked, _toggleBlock, Colors.redAccent),
      ],
    );
  }

  Widget _buildLiveChart() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(20)),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _pingSpots.isEmpty ? [const FlSpot(0, 0)] : _pingSpots,
              isCurved: false,
              color: Colors.cyanAccent,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.cyanAccent.withOpacity(0.05)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, bool active, VoidCallback tap, Color activeColor) {
    return GestureDetector(
      onTap: tap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: active ? activeColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: active ? activeColor : Colors.white10),
            ),
            child: Icon(icon, color: active ? activeColor : Colors.white38),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 10, color: active ? activeColor : Colors.white38, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHeaderStatus() {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _isAutoPinging ? Colors.cyanAccent : Colors.blueAccent, width: 2),
              boxShadow: [if(_isAutoPinging) BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20)]
          ),
          child: Icon(_isBlocked ? Icons.block : Icons.security, color: _isBlocked ? Colors.redAccent : Colors.blueAccent, size: 30),
        ),
        const SizedBox(height: 15),
        Text(_pingResult, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildStaticDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _row("IP ADDRESS", widget.device["ip"] ?? "Unknown"),
          const Divider(color: Colors.white10, height: 25),
          _row("MAC ADDRESS", widget.device["mac"] ?? "Unknown"),
        ],
      ),
    );
  }

  Widget _row(String l, String v) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
    ]);
  }
}