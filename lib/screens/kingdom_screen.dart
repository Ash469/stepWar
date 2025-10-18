import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widget/footer.dart';

class KingdomItem {
  final String name;
  final String imagePath;
  final String rarity;
  final String description; 
  final Color rarityColor;
  final List<Color> gradientColors;

  KingdomItem({
    required this.name,
    required this.imagePath,
    required this.rarity,
     required this.description,
    required this.rarityColor,
    required this.gradientColors,
  });

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
      description: json['description'] ?? 'No description available.', 
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

  Map<String, List<KingdomItem>>? _allRewards;
  bool _isLoading = true;
  String _selectedFilter = 'All';
  List<KingdomItem> _currentItems = [];

  @override
  void initState() {
    super.initState();
    _loadRewardsFromCache();
  }

  Future<void> _loadRewardsFromCache() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final cachedRewardsString = prefs.getString('userRewardsCache');

    if (cachedRewardsString != null) {
      final rawRewards = Map<String, dynamic>.from(jsonDecode(cachedRewardsString));
      _processAndSetRewards(rawRewards);
    } else {
      await _fetchAndCacheRewards();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAndCacheRewards() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("Not logged in");

      final rawRewards = await _authService.getUserRewards(userId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRewardsCache', jsonEncode(rawRewards));

      _processAndSetRewards(rawRewards);
    } catch (e) {
      print("Error fetching rewards: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching rewards: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processAndSetRewards(Map<String, dynamic> rawRewards) {
    final processedRewards = rawRewards.map((key, value) {
      final items = (value as List).map((item) => KingdomItem.fromJson(item)).toList();
      return MapEntry(key, items);
    });
    if (mounted) {
      setState(() {
        _allRewards = processedRewards;
      });
    }
  }

  void _showRewardDetailsDialog(KingdomItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: item.rarityColor.withOpacity(0.7)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image
              Image.asset(item.imagePath, height: 120, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.red, size: 80)),
              const SizedBox(height: 16),
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Rarity Tag
              _buildRarityTag(item.rarity, item.rarityColor),
              const SizedBox(height: 20),
              // Description
              Text(
                item.description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.yellow));
    }

    if (_allRewards == null || _allRewards!.values.every((list) => list.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("You haven't collected any rewards yet.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.yellow),
              onPressed: _fetchAndCacheRewards,
            ),
          ],
        ),
      );
    }

    final availableFilters = ['All', ..._allRewards!.keys];
    if (_selectedFilter == 'All') {
      _currentItems = _allRewards!.values.expand((list) => list).toList();
    } else {
      _currentItems = _allRewards![_selectedFilter] ?? [];
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFilterChips(availableFilters),
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
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.yellow),
          onPressed: _fetchAndCacheRewards,
          tooltip: 'Refresh Rewards',
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
    return GestureDetector(
      onTap: () => _showRewardDetailsDialog(item),
      child: Container(
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