import 'package:flutter/material.dart';
import '../widget/footer.dart';

// A simple data model for each item in the kingdom
class KingdomItem {
  final String name;
  final String imagePath;
  final String rarity;
  final Color rarityColor;
  final List<Color> gradientColors;

  KingdomItem({
    required this.name,
    required this.imagePath,
    required this.rarity,
    required this.rarityColor,
    required this.gradientColors,
  });
}

class KingdomScreen extends StatefulWidget {
  const KingdomScreen({super.key});

  @override
  State<KingdomScreen> createState() => _KingdomScreenState();
}

class _KingdomScreenState extends State<KingdomScreen> {
  // --- State Variables ---
  String _selectedFilter = 'Fort';

  // --- Mock Data ---
  final List<KingdomItem> _kingdomItems = [
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'EPIC',
        rarityColor: const Color(0xFFC976FF),
        gradientColors: [
          const Color(0xFFC976FF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'Rare',
        rarityColor: const Color(0xFF699EFF),
        gradientColors: [
          const Color(0xFF699EFF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'Mythic',
        rarityColor: const Color(0xFFFF5C5C),
        gradientColors: [
          const Color(0xFFFF5C5C).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'Legendary',
        rarityColor: const Color(0xFF8AFF5C),
        gradientColors: [
          const Color(0xFF8AFF5C).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'EPIC',
        rarityColor: const Color(0xFFC976FF),
        gradientColors: [
          const Color(0xFFC976FF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'Rare',
        rarityColor: const Color(0xFF699EFF),
        gradientColors: [
          const Color(0xFF699EFF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'EPIC',
        rarityColor: const Color(0xFFC976FF),
        gradientColors: [
          const Color(0xFFC976FF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'Rare',
        rarityColor: const Color(0xFF699EFF),
        gradientColors: [
          const Color(0xFF699EFF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'EPIC',
        rarityColor: const Color(0xFFC976FF),
        gradientColors: [
          const Color(0xFFC976FF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'Rare',
        rarityColor: const Color(0xFF699EFF),
        gradientColors: [
          const Color(0xFF699EFF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'EPIC',
        rarityColor: const Color(0xFFC976FF),
        gradientColors: [
          const Color(0xFFC976FF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'Rare',
        rarityColor: const Color(0xFF699EFF),
        gradientColors: [
          const Color(0xFF699EFF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'EPIC',
        rarityColor: const Color(0xFFC976FF),
        gradientColors: [
          const Color(0xFFC976FF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'Rare',
        rarityColor: const Color(0xFF699EFF),
        gradientColors: [
          const Color(0xFF699EFF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'EPIC',
        rarityColor: const Color(0xFFC976FF),
        gradientColors: [
          const Color(0xFFC976FF).withOpacity(0.5),
          Colors.transparent
        ]),
    KingdomItem(
        name: 'Mumbai',
        imagePath: 'assets/images/mumbai.png',
        rarity: 'Rare',
        rarityColor: const Color(0xFF699EFF),
        gradientColors: [
          const Color(0xFF699EFF).withOpacity(0.5),
          Colors.transparent
        ]),
  ];

  final List<String> _filters = ['Fort', 'images/mumbai', 'Legend', 'Badge'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: 
        SingleChildScrollView(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildFilterChips(),
              const SizedBox(height: 24),
              Text(
                '${_kingdomItems.length} items',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              _buildKingdomGrid(),
              const SizedBox(height: 16),
              const StepWarsFooter(),
            ],
          ),
        ),
      );
  }

  // --- Helper Widgets ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'My Kingdom',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            // Handle filter tap
          },
          icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
          label: const Text('Filter', style: TextStyle(color: Colors.white)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey.shade800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return ChoiceChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              }
            },
            backgroundColor: Colors.grey.shade900,
            selectedColor: const Color(0xFFFFD700),
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFFFD700)
                    : Colors.grey.shade800,
              ),
            ),
            showCheckmark: false,
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          );
        },
      ),
    );
  }

  Widget _buildKingdomGrid() {
    return GridView.builder(
      // The parent SingleChildScrollView handles scrolling
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 1.0,
      ),
      itemCount: _kingdomItems.length,
      itemBuilder: (context, index) {
        return _buildKingdomItemCard(_kingdomItems[index]);
      },
    );
  }

  Widget _buildKingdomItemCard(KingdomItem item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      child: Stack(
        children: [
          // Gradient Glow Effect
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.7,
                  colors: item.gradientColors,
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildRarityTag(item.rarity, item.rarityColor),
                const Spacer(),
                Image.asset(
                  item.imagePath,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.fort, color: Colors.white, size: 60);
                  },
                ),
                const Spacer(),
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRarityTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
