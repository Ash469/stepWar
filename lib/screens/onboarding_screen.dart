import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildPageOne(),
      _buildPageTwo(),
      _buildPageThree(),
      _buildPageFour(),
      _buildPageFive(),
    ];
  }

  Widget _buildPageOne() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildTitleWithArrows(['Walk', 'Steps', 'Power']), // Updated
              const SizedBox(height: 16),
              const Text(
                "Every step you take gives you power",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.normal),
              ),
              const Spacer(flex: 2),
              Expanded(
                flex: 4,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -availableWidth * 0.5,
                      child: Container(
                        width: availableWidth * 0.95,
                        height: availableWidth * 0.95,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE047),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 6),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      height: 300,
                      width: 180,
                      child: Image.asset(
                        'assets/images/person_walking.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, size: 80),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.yellow.withOpacity(0.5),
                                  Colors.orange.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                                stops: const [0.4, 0.7, 1.0],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: Image.asset(
                              'assets/images/spark.png',
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.bolt, size: 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageTwo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double circleDiameter = availableWidth * 1.5;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _buildTitleWithArrows(['Steps', 'Battles']), // Updated
              const SizedBox(height: 16),
              const Text(
                "Your steps fight your opponent’s steps in real-time battles",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.normal),
              ),
              const Spacer(flex: 2),
              Expanded(
                flex: 4,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: circleDiameter,
                      height: circleDiameter,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE047),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 6),
                      ),
                    ),
                    SizedBox(
                      width: circleDiameter * 0.65,
                      height: circleDiameter * 0.65,
                      child: Image.asset(
                        'assets/images/onboarding_3.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.emoji_events,
                                size: 80, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageThree() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(flex: 2),
          const Text(
            "How to Win",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          const Text(
            "Walk more than your rival to win battles and grow stronger",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.normal),
          ),
          const Spacer(flex: 1),
          Expanded(
            flex: 4,
            child: _buildWinConditionContent(),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildPageFour() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(flex: 2),
         _buildTitleWithArrows(['Win', 'Coins','Rewards']), 
          const SizedBox(height: 16),
          const Text(
            "Every battle gives coins and a chance to unlock rare treasures",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.normal),
          ),
          const Spacer(flex: 2),
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Image.asset(
                    'assets/images/box.png',
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.card_giftcard, size: 100),
                  ),
                ),
                SizedBox(
                  width: 280,
                  height: 280,
                  child: Image.asset(
                    'assets/images/party.png',
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.celebration, size: 100),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildPageFive() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double circleDiameter = constraints.maxWidth * 0.8;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Text(
                "Grow Your Kingdom",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                "Collect victories to expand your empire and show off your strength",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.normal),
              ),
              const Spacer(flex: 2),
              Expanded(
                flex: 4,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: circleDiameter,
                      height: circleDiameter,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE047),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 6),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      child: SizedBox(
                        width: circleDiameter * 1.1,
                        height: circleDiameter,
                        child: Image.asset(
                          'assets/images/onboarding_5.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.fort, size: 100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitleWithArrows(List<String> parts) {
    const titleStyle = TextStyle(
      fontSize: 28,
      color: Colors.white,
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w600,
    );
    const arrowIcon = Icon(
      Icons.arrow_forward,
      color: Colors.white,
      size: 26,
    );

    List<Widget> children = [];
    for (int i = 0; i < parts.length; i++) {
      children.add(Text(parts[i], style: titleStyle));
      if (i < parts.length - 1) {
        children.add(const SizedBox(width: 8));
        children.add(arrowIcon);
        children.add(const SizedBox(width: 8));
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }


  Widget _buildWinConditionContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWinConditionItem(
              'assets/images/ko_image.png', "KO Victory", "200 step lead"),
          const SizedBox(height: 24),
          _buildWinConditionItem('assets/images/medel.png', "Win", "More steps"),
          const SizedBox(height: 24),
          _buildWinConditionItem(
              'assets/images/flag.png', "Draw", "Within 50 steps"),
        ],
      ),
    );
  }

  Widget _buildWinConditionItem(
      String imagePath, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFFDE047),
            child: Padding(
              padding: const EdgeInsets.all(8.0), 
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.help_outline, color: Colors.black54),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onIntroEnd(){
    if (mounted) {
     
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF373737),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (int page) =>
                          setState(() => _currentPage = page),
                      itemBuilder: (context, index) {
                        return _pages[index];
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _buildNavigationControls(),
                ),
              ],
            ),
            Positioned(
              top: 16.0,
              right: 24.0,
              child: TextButton(
                onPressed: _onIntroEnd,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 4.0),
                  child: const Text('Skip',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length,
                (index) => _buildIndicator(index == _currentPage)),
          ),
          const SizedBox(height: 24),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 4.0,
      width: isActive ? 32.0 : 16.0,
      decoration: BoxDecoration(
        color: isActive
            ? const Color.fromARGB(255, 232, 253, 2)
            : Colors.grey.shade600,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    bool isFirstPage = _currentPage == 0;
    bool isLastPage = _currentPage == _pages.length - 1;

    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: isFirstPage
              ? const SizedBox(width: 0)
              : OutlinedButton(
                  key: const ValueKey('backButton'),
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    shape: const CircleBorder(),
                    side: const BorderSide(
                        color: Color.fromARGB(255, 232, 253, 2)),
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Color.fromARGB(255, 232, 253, 2)),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (isLastPage) {
                _onIntroEnd();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF373737),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLastPage
                ? const Text(
                    "Let's Start",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Text(
                    "Next",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                    ),
                  )
          ),
        ),
      ],
    );
  }
}