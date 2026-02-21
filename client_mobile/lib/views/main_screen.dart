import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'devices_page.dart';
import 'topology_page.dart';

class MainScreen extends StatefulWidget {
  final String vpnConfig;

  const MainScreen({super.key, required this.vpnConfig});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  WebSocketChannel? _channel;

  // --- MOD ANAHTARI ---
  // false = Fedora Sunucusu (Umay Node) | true = Telefonun Kendi Wi-Fi'ı (Local Radar)
  bool _isLocalMode = false;

  // --- CENTRAL DATA STORAGE ---
  // DİKKAT: Veriler sayfalara aktarılırken hata olmaması için 'dynamic' kullanıyoruz.
  Map<String, Map<String, dynamic>> discoveredDevices = {};
  Map<String, String> networkStats = {
    "isp": "Scanning...",
    "ip": "0.0.0.0",
    "loc": "Waiting..."
  };

  late AnimationController _bgController;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);

    _topAlignmentAnimation = Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight).animate(_bgController);
    _bottomAlignmentAnimation = Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft).animate(_bgController);

    // Uygulama ilk açıldığında Sunucu (Remote) modunda başlar
    _initWebSocket();
  }

  // ==========================================
  // 1. UMAY SUNUCU (REMOTE) MODU
  // ==========================================
  void _initWebSocket() {
    final String? baseUrl = dotenv.env['SENTINEL_API_URL'];
    if (baseUrl == null) return;

    String cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    final String wsUrl = cleanUrl.replaceFirst("http://", "ws://").replaceFirst("https://", "wss://") + "/ws/traffic";

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen((message) {
        if (_isLocalMode) return; // Eğer Local moddaysak sunucudan gelenleri görmezden gel

        final data = jsonDecode(message);
        setState(() {
          if (data['type'] == 'network_info') {
            networkStats = {
              "isp": data['data']['isp'] ?? "Unknown ISP",
              "ip": data['data']['public_ip'] ?? "0.0.0.0",
              "loc": "${data['data']['city'] ?? ''}, ${data['data']['country'] ?? ''}"
            };
          } else if (data.containsKey('mac') && data['mac'] != null) {
            String mac = data['mac'];
            String name = data['hostname']?.toString() != "null" && data['hostname'] != ""
                ? data['hostname'] : (data['vendor'] ?? "Unknown Device");

            discoveredDevices[mac] = {
              "name": name,
              "ip": data['source'] ?? "0.0.0.0",
              "mac": mac,
              "status": "Online",
              "vulns": data['vulns'] ?? [] // Zafiyet listesi varsa ekle
            };
          }
        });
      }, onError: (err) => print("WS Error: $err"));
    } catch (e) {
      print("WS Connect Failed: $e");
    }
  }

  // ==========================================
  // 2. YEREL RADAR (LOCAL) MODU & İSTİHBARAT
  // ==========================================
  Future<void> _startLocalScan() async {
    // 1. Telefonun kendi IP'sini bul
    String? localIp;
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.')) {
              localIp = addr.address;
            }
          }
        }
      }
    } catch (e) {
      print("IP Error: $e");
    }

    if (localIp == null) {
      setState(() => networkStats["isp"] = "No Wi-Fi Connection");
      return;
    }

    setState(() {
      networkStats = {
        "isp": "Local Radar Active",
        "ip": localIp!,
        "loc": "On-the-go Mode"
      };
    });

    // 2. Subnet'i hesapla
    String subnet = localIp.substring(0, localIp.lastIndexOf('.'));
    List<String> foundIps = []; // Karargaha yollanacak IP listesi

    // 3. Ağdaki tüm 254 cihaza ping at
    for (int i = 1; i < 255; i++) {
      if (!_isLocalMode) break;

      String targetIp = '$subnet.$i';

      Process.run('ping', ['-c', '1', '-W', '1', targetIp]).then((ProcessResult result) {
        if (result.exitCode == 0) {
          foundIps.add(targetIp); // Bulunan IP'yi listeye ekle

          if (mounted && _isLocalMode) {
            setState(() {
              discoveredDevices[targetIp] = {
                "name": targetIp == localIp ? "My Phone" : "Local Target",
                "ip": targetIp,
                "mac": "Hidden by OS",
                "status": "Online",
                "vulns": [] // Yerel taramada henüz vuln bilinmiyor
              };
            });
          }
        }
      });

      // Taramayı boğmamak için es ver
      await Future.delayed(const Duration(milliseconds: 5));
    }

    // 4. TARAMA BİTİNCE SUNUCUYA (KARARGAHA) RAPORLA
    Future.delayed(const Duration(seconds: 3), () async {
      if (foundIps.isNotEmpty && _isLocalMode) {
        final String? baseUrl = dotenv.env['SENTINEL_API_URL'];
        if (baseUrl != null) {
          try {
            print("🚀 İstihbarat Sunucuya Gönderiliyor... Toplam: ${foundIps.length}");
            await http.post(
              Uri.parse('$baseUrl/api/v1/radar-intel'),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "agent_ip": localIp,
                "discovered_ips": foundIps
              }),
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Field intel successfully sent to Headquarters!"),
                      backgroundColor: Colors.green
                  )
              );
            }
          } catch (e) {
            print("❌ İstihbarat gönderilemedi: $e");
          }
        }
      }
    });
  }

  // ==========================================
  // MOD DEĞİŞTİRİCİ TETİK (TOGGLE)
  // ==========================================
  void _toggleMode() {
    setState(() {
      _isLocalMode = !_isLocalMode;
      discoveredDevices.clear();
      networkStats = {
        "isp": _isLocalMode ? "Starting Radar..." : "Connecting to Umay...",
        "ip": "0.0.0.0",
        "loc": "Waiting..."
      };
    });

    if (_isLocalMode) {
      _channel?.sink.close();
      _startLocalScan();
    } else {
      _initWebSocket();
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = MediaQuery.of(context).size.width * 0.90;

    // Type casting hatasını önlemek için doğrudan liste olarak aktarıyoruz
    final deviceList = discoveredDevices.values.toList();

    final List<Widget> pages = [
      DevicesPage(devices: deviceList, stats: networkStats),
      TopologyPage(devices: deviceList),
    ];

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _topAlignmentAnimation.value,
                end: _bottomAlignmentAnimation.value,
                stops: const [0.0, 0.7, 1.0],
                colors: const [
                  Color(0xFF305282),
                  Color(0xFF98AFC7),
                  Color(0xFFE9ECEF),
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: pages[_currentIndex],
                  ),

                  // SAĞ ÜST KÖŞEDEKİ MOD DEĞİŞTİRİCİ BUTON
                  Positioned(
                    top: 10,
                    right: 15,
                    child: GestureDetector(
                      onTap: _toggleMode,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                                color: _isLocalMode ? Colors.orangeAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: _isLocalMode ? Colors.orangeAccent : Colors.blueAccent, width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: _isLocalMode ? Colors.orangeAccent.withOpacity(0.2) : Colors.transparent, blurRadius: 10)
                                ]
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_isLocalMode ? Icons.radar : Icons.dns, color: _isLocalMode ? Colors.orangeAccent : Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                    _isLocalMode ? "LOCAL RADAR" : "UMAY SERVER",
                                    style: TextStyle(color: _isLocalMode ? Colors.orangeAccent : Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Navigasyon Barı
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: SizedBox(
                        width: barWidth,
                        child: _buildLiquidBottomBar(barWidth),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiquidBottomBar(double barWidth) {
    final innerWidth = barWidth - 2;
    final itemWidth = innerWidth / 2;

    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.9),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 6,
            bottom: 6,
            left: (_currentIndex * itemWidth) + 6,
            width: itemWidth - 12,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: const Color(0xFF305282).withOpacity(0.6),
              ),
            ),
          ),

          Row(
            children: [
              _buildNavItem(Icons.format_list_bulleted_rounded, "Devices", 0, itemWidth),
              _buildNavItem(Icons.account_tree_outlined, "Topology", 1, itemWidth),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, double itemWidth) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Colors.white : Colors.grey.shade400;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        width: itemWidth,
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
              ),
            ),
          ],
        ),
      ),
    );
  }
}