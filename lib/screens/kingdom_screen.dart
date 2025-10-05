import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widget/footer.dart';

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

  // Factory to create a KingdomItem from the JSON from our backend
  factory KingdomItem.fromJson(Map<String, dynamic> json) {
    String rarity = json['tier'] ?? 'Unknown';
    Color rarityColor;
    switch (rarity) {
      case 'Rare':
        rarityColor = const Color(0xFF699EFF);
        break;
      case 'Epic':
        rarityColor = const Color(0xFFC976FF);
        break;
      case 'Mythic':
        rarityColor = const Color(0xFFFF5C5C);
        break;
      case 'Legendary':
        rarityColor = const Color(0xFF8AFF5C);
        break;
      default:
        rarityColor = Colors.grey;
    }
    return KingdomItem(
      name: json['name'] ?? 'Unnamed',
      imagePath: json['imagePath'] ?? '', 
      rarity: rarity,
      rarityColor: rarityColor,
      gradientColors: [rarityColor.withOpacity(0.5), Colors.transparent],
    );
  }
}

class KingdomScreen extends StatefulWidget {
  const KingdomScreen({super.key});

  @override
  State<KingdomScreen> createState() => _KingdomScreenState();
}

class _KingdomScreenState extends State<KingdomScreen> {
  final AuthService _authService = AuthService();
  late Future<Map<String, List<KingdomItem>>> _rewardsFuture;
  String? _selectedFilter; 
  final List<String> _filters = ['Fort', 'Monument', 'Legend', 'Badge'];
  List<KingdomItem> _currentItems = [];

  @override
  void initState() {
    super.initState();
    _rewardsFuture = _fetchAndProcessRewards();
  }

  Future<Map<String, List<KingdomItem>>> _fetchAndProcessRewards() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception("Not logged in");
    }
    final rawRewards = await _authService.getUserRewards(userId);

    return rawRewards.map((key, value) {
      final items = (value as List).map((item) => KingdomItem.fromJson(item)).toList();
      return MapEntry(key, items);
    });
  }

  @override
 Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: FutureBuilder<Map<String, List<KingdomItem>>>(
        future: _rewardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.yellow));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty || snapshot.data!.values.every((list) => list.isEmpty)) {
            return const Center(child: Text("You haven't collected any rewards yet.", style: TextStyle(color: Colors.white70)));
          }
          final allRewards = snapshot.data!;
          if (_selectedFilter == null && allRewards.keys.isNotEmpty) {
            _selectedFilter = allRewards.keys.first;
          }
          _currentItems = allRewards[_selectedFilter] ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildFilterChips(allRewards.keys.toList()),
                const SizedBox(height: 24),
                Text(
                  '${_currentItems.length} items',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildKingdomGrid(),
                const SizedBox(height: 40),
                const StepWarsFooter(),
              ],
            ),
          );
        },
      ),
    );
  }



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
        PopupMenuButton<String>(
          onSelected: (String newFilter) {
            setState(() {
              _selectedFilter = newFilter;
            });
          },
          color: const Color(0xFF2a2a2a),
          itemBuilder: (BuildContext context) {
            return _filters.map((String filter) {
              return PopupMenuItem<String>(
                value: filter,
                child: Text(filter, style: const TextStyle(color: Colors.white)),
              );
            }).toList();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade800),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: const Row(
              children: [
                Icon(Icons.filter_list, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Filter', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

 Widget _buildFilterChips(List<String> availableFilters) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableFilters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = availableFilters[index];
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
              side: BorderSide(color: isSelected ? const Color(0xFFFFD700) : Colors.grey.shade800),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          );
        },
      ),
    );
  }

  Widget _buildKingdomGrid() {
    if (_currentItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 50.0),
          child: Text(
            "No items collected in the '$_selectedFilter' category yet.",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 0.9,
      ),
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        return _buildKingdomItemCard(_currentItems[index]);
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
                item.imagePath.isNotEmpty
                    ? Image.asset(item.imagePath, height: 80, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.red, size: 60))
                    : const Icon(Icons.question_mark, color: Colors.white, size: 60),
                const Spacer(),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}