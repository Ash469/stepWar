import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/interest_service.dart';
import 'main_screen.dart';

class PreferencesScreen extends StatefulWidget {
  final UserModel user;

  const PreferencesScreen({super.key, required this.user});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final AuthService _authService = AuthService();
  final InterestService _interestService = InterestService();
  bool _isLoading = false;
  bool _isLoadingInterests = true;

  static const Map<String, String> _emojiMap = {
    'Travel': '🧳',
    'Movies': '🎬',
    'History': '🏛️',
    'TV Shows': '📺',
  };

  List<String> _interests = [];
  final Set<String> _selectedInterests = {};

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    final interests = await _interestService.fetchInterests();
    if (mounted) {
      setState(() {
        _interests = interests;
        _isLoadingInterests = false;
      });
    }
  }

  final List<String> _stepRanges = [
    '< 1000',
    '1000 - 3000',
    '3000 - 6000',
    '6000 - 10000',
    '10000 +',
  ];
  String? _selectedStepRange;

  bool get _canContinue =>
      _selectedInterests.isNotEmpty && _selectedStepRange != null;

  Future<void> _savePreferences() async {
    if (!_canContinue) return;
    setState(() => _isLoading = true);

    try {
      final updatedUser = widget.user.copyWith(
        interestAreas: _selectedInterests.toList(),
        avgDailySteps: _selectedStepRange,
      );

      await _authService.updateUserProfile(updatedUser);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
         
            SizedBox(
              height: 310,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: -374,
                    left: -125,
                    child: Image.asset(
                      'assets/images/preference_screen2.png',
                      width: 687,
                      height: 687,
                      fit: BoxFit.fill,
                    ),
                  ),
 
                  Positioned(
                    top: 47,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Image.asset(
                        'assets/images/preference_screen1.png',
                        width: 137,
                        height: 263,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),

         
            Expanded(
              child: SingleChildScrollView(
               
                padding: const EdgeInsets.fromLTRB(14, 30, 14, 30),
                child: Column(
                  children: [
                    _buildInterestsCard(),
                   
                    const SizedBox(height: 40),
                    _buildStepsCard(),
                    // Figma gap: button top(876) - steps bottom(616+192=808) = 68
                    const SizedBox(height: 68),
                    _buildContinueButton(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  
  Widget _buildGradientBorderCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFF131313)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(1), // 1px border width
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(19),
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

 
  Widget _buildInterestsCard() {
    return _buildGradientBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell Us Your Interests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingInterests)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(
                  color: Color(0xFFFDD85D),
                  strokeWidth: 2,
                ),
              ),
            )
          else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _interests.map((name) {
              final icon = _emojiMap[name] ?? '⭐';
              final isSelected = _selectedInterests.contains(name);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedInterests.remove(name);
                    } else {
                      _selectedInterests.add(name);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFDD85D)
                          : const Color(0xFF3A3A3A),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade300,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// "Active Daily Steps" card
  /// Figma: 412×192, radius 20, border 1px gradient, bg #1F1F1F
  Widget _buildStepsCard() {
    return _buildGradientBorderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Daily Steps',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _stepRanges.map((range) {
              final isSelected = _selectedStepRange == range;

              return GestureDetector(
                onTap: () => setState(() => _selectedStepRange = range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFDD85D)
                          : const Color(0xFF3A3A3A),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    range,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : Colors.grey.shade300,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// "Continue" button
  /// Figma: 412×56, radius 12, bg #FDD85D
  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _canContinue && !_isLoading ? _savePreferences : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFDD85D),
          disabledBackgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.black,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
