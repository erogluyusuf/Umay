import 'package:flutter/material.dart';
import 'devices_page.dart';
import 'topology_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  
  late AnimationController _bgController;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  final List<Widget> _pages = [
    const DevicesPage(),
    const TopologyPage(),
  ];

  @override
  void initState() {
    super.initState();
    // HIZLANDIRILDI: 10 saniyeden 5 saniyeye düşürüldü
    _bgController = AnimationController(
      duration: const Duration(seconds: 5), 
      vsync: this,
    )..repeat(reverse: true); 

    _topAlignmentAnimation = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
    ).animate(_bgController);

    _bottomAlignmentAnimation = Tween<Alignment>(
      begin: Alignment.bottomRight,
      end: Alignment.bottomLeft,
    ).animate(_bgController);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = MediaQuery.of(context).size.width * 0.90;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _topAlignmentAnimation.value,
                end: _bottomAlignmentAnimation.value,
                // BEYAZ KISIM AZALTILDI: Mavilere %70 alan verildi
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
                    child: _pages[_currentIndex],
                  ),
                  
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
