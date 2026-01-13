import 'package:flutter/material.dart';
import '../models/permission_model.dart';
import '../services/permission_service.dart';

/// Professional bottom sheet to display and manage app permissions sequentially
/// Displays as a "card-like" overlay covering half the screen.
class PermissionBottomSheet extends StatefulWidget {
  final VoidCallback? onAllGranted;
  final bool showCloseButton;

  const PermissionBottomSheet({
    super.key,
    this.onAllGranted,
    this.showCloseButton = true,
  });

  /// Show the permission bottom sheet
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onAllGranted,
    bool showCloseButton = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // User cannot just tap outside to close easily
      enableDrag: true, // Allow dragging to close? User said "slide" for next.
      // Let's keep dismiss false to ensure they interact,
      // but maybe provide a skip/close button inside.
      backgroundColor: Colors.transparent,
      builder: (context) => PermissionBottomSheet(
        onAllGranted: onAllGranted,
        showCloseButton: showCloseButton,
      ),
    );
  }

  @override
  State<PermissionBottomSheet> createState() => _PermissionBottomSheetState();
}

class _PermissionBottomSheetState extends State<PermissionBottomSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<AppPermission> _permissions = [];
  bool _isLoading = true;
  late PageController _pageController;
  int _currentIndex = 0;

  // Track if all required permissions are actually granted
  bool get _areAllRequiredGranted =>
      _permissions.every((p) => p.isGranted || !p.isRequired);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _loadPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsOnResume();
    }
  }

  Future<void> _checkPermissionsOnResume() async {
    // Re-check all permissions when app resumes (e.g. from settings)
    final updatedPermissions = await PermissionService.checkAllPermissions();
    if (mounted) {
      setState(() {
        _permissions = updatedPermissions;
      });
      // If the current page's permission became granted, auto-advance
      if (_currentIndex < _permissions.length) {
        final currentPerm = _permissions[_currentIndex];
        if (currentPerm.isGranted) {
          // Small delay for UX
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) _nextPage();
        }
      }
    }
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    final permissions = await PermissionService.checkAllPermissions();

    setState(() {
      _permissions = permissions;
      _isLoading = false;
    });

    // If already all granted, maybe just close?
    // Or let user see "All Set" if they opened it manually.
    if (_areAllRequiredGranted) {
      // If opened automatically and all granted, we might want to skip logic,
      // but here we just show the success state.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.jumpToPage(_permissions.length);
        }
      });
    }
  }

  Future<void> _handlePermissionRequest(AppPermission permission) async {
    if (permission.id == 'autostart') {
      _showAutoStartDialog(permission);
      return;
    }

    final granted = await PermissionService.requestPermission(permission.id);
    if (granted) {
      _updatePermissionState(permission, true);
    } else {
      // If denied, we show settings dialog to guide them
      if (mounted) _showSettingsDialog(permission);
    }
  }

  void _updatePermissionState(AppPermission permission, bool granted) async {
    if (granted) {
      setState(() {
        permission.isGranted = true;
      });
      // Auto-advance
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _nextPage();
      }
    }
  }

  void _nextPage() {
    if (_currentIndex < _permissions.length) {
      // Allow going to "All Set" page index only if appropriate
      // If we are at the last permission, check if we can go to success page
      if (_currentIndex == _permissions.length - 1) {
        if (_areAllRequiredGranted) {
          _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
        } else {
          // If missing permissions, we don't go to "All Set".
          Navigator.pop(context);
        }
      } else {
        _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      }
    }
  }

  void _showAutoStartDialog(AppPermission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(permission.icon, color: permission.iconColor, size: 28),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Enable Auto-Start',
                    style: TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
        content: const Text(
            'To ensure step counting works, please enable auto-start in settings.',
            style: TextStyle(color: Colors.white70, fontSize: 15)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.openSettings(permission.id);
              if (mounted) {
                setState(() => permission.isGranted = true); // Optimistic
                _nextPage();
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(AppPermission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('Permission Required',
            style: TextStyle(color: Colors.white)),
        content: Text('Please enable ${permission.title} in settings.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.openSettings(permission.id);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Height is roughly half screen
    final height = MediaQuery.of(context).size.height * 0.55;

    // Total pages = permissions + 1 (success)
    // But success page only reachable if all granted.
    final itemCount = _permissions.length + 1;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ]),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),

                  // Progress Dots
                  if (!_areAllRequiredGranted ||
                      _currentIndex < _permissions.length)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_permissions.length, (index) {
                          bool isActive = index == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFFFC107)
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),

                  Expanded(
                    child: PageView.builder(
                      // IMPORTANT: Controller must be attached for programmatic navigation
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: itemCount,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });

                        // If user swiped to success page but permissions missing,
                        // block access to it.
                        if (index == _permissions.length &&
                            !_areAllRequiredGranted) {
                          // Revert to last permission
                          // We use a slight delay so they see they hit a wall, or just snap back
                          Future.delayed(Duration.zero, () {
                            _pageController.animateToPage(
                                _permissions.length - 1,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut);
                          });
                        }
                      },
                      itemBuilder: (context, index) {
                        if (index == _permissions.length) {
                          // This is the success page
                          // Only show if granted
                          if (_areAllRequiredGranted) {
                            return _buildSuccessPage();
                          } else {
                            // Should not be reachable ideally due to onPageChanged guard
                            // But return spacer just in case
                            return const SizedBox();
                          }
                        }
                        return _buildPermissionPage(_permissions[index]);
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPermissionPage(AppPermission permission) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: permission.iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(permission.icon, color: permission.iconColor, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            permission.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            permission.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (permission.isGranted) {
                  _nextPage();
                } else {
                  _handlePermissionRequest(permission);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: permission.isGranted
                    ? Colors.white10
                    : const Color(0xFFFFC107),
                foregroundColor:
                    permission.isGranted ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                permission.isGranted ? 'Next' : 'Allow Access',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Swipe hint
          if (!permission.isGranted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "Swipe left to skip",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 60),
        const SizedBox(height: 16),
        const Text(
          'All Set!',
          style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'You\'re ready to go.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (widget.onAllGranted != null) widget.onAllGranted!();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue'),
            ),
          ),
        ),
      ],
    );
  }
}
