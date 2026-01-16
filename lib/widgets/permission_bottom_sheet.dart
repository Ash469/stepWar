import 'package:flutter/material.dart';
import '../models/permission_model.dart';
import '../services/permission_service.dart';

class PermissionBottomSheet extends StatefulWidget {
  final VoidCallback? onAllGranted;
  final bool showCloseButton;

  const PermissionBottomSheet({
    super.key,
    this.onAllGranted,
    this.showCloseButton = true,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onAllGranted,
    bool showCloseButton = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, 
      enableDrag: true, 
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
  bool _isNavigating = false;
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
    final updatedPermissions = await PermissionService.checkAllPermissions();
    if (mounted) {
      setState(() {
        _permissions = updatedPermissions;
      });
      if (_currentIndex < _permissions.length) {
        final currentPerm = _permissions[_currentIndex];
        if (currentPerm.isGranted) {
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
    if (_areAllRequiredGranted) {
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
      if (mounted) _showSettingsDialog(permission);
    }
  }

  void _updatePermissionState(AppPermission permission, bool granted) async {
    if (granted) {
      setState(() {
        permission.isGranted = true;
      });
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _nextPage();
      }
    }
  }

  Future<void> _nextPage() async {
    if (_isNavigating || _currentIndex >= _permissions.length) return;

    if (_currentIndex == _permissions.length - 1) {
      if (_areAllRequiredGranted) {
        _isNavigating = true;
        await _pageController.nextPage(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut);
        if (mounted) {
          _isNavigating = false;
        }
      } else {
        Navigator.pop(context);
      }
    } else {
      _isNavigating = true;
      await _pageController.nextPage(
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      if (mounted) {
        _isNavigating = false;
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
                setState(() => permission.isGranted = true); 
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
    final height = MediaQuery.of(context).size.height * 0.55;
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
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),

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
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: itemCount,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        if (index == _permissions.length &&
                            !_areAllRequiredGranted) {
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
                          if (_areAllRequiredGranted) {
                            return _buildSuccessPage();
                          } else {
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
