import 'package:flutter/material.dart';
import '../models/permission_model.dart';
import '../services/permission_service.dart';
import '../widget/responsive_wrapper.dart';

/// Professional bottom sheet to display and manage app permissions
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
      isDismissible: showCloseButton,
      enableDrag: showCloseButton,
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
    with SingleTickerProviderStateMixin {
  List<AppPermission> _permissions = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadPermissions();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    final permissions = await PermissionService.checkAllPermissions();
    setState(() {
      _permissions = permissions;
      _isLoading = false;
    });

    // Check if all permissions are granted
    if (permissions.every((p) => p.isGranted || !p.isRequired)) {
      widget.onAllGranted?.call();
    }
  }

  Future<void> _handlePermissionRequest(AppPermission permission) async {
    // Special handling for auto-start permission
    if (permission.id == 'autostart') {
      _showAutoStartDialog(permission);
      return;
    }

    final granted = await PermissionService.requestPermission(permission.id);

    if (granted) {
      setState(() {
        permission.isGranted = true;
      });

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${permission.title} granted!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Reload all permissions
      await _loadPermissions();
    } else {
      // Permission denied, show option to open settings
      if (mounted) {
        _showSettingsDialog(permission);
      }
    }
  }

  void _showAutoStartDialog(AppPermission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              permission.icon,
              color: permission.iconColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Enable Auto-Start',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'To ensure step counting continues after device restart, please enable auto-start permission from your device settings.\n\nWe\'ll take you to the settings page now. Please find StepWars and enable auto-start.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.openSettings(permission.id);
              // Reload permissions to show the updated status
              if (mounted) {
                await _loadPermissions();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: permission.iconColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(AppPermission permission) {
    // Special handling for auto-start permission
    final isAutoStart = permission.id == 'autostart';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.settings,
              color: permission.iconColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAutoStart ? 'Manual Setup Required' : 'Permission Required',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isAutoStart
              ? 'Auto-start must be enabled manually from your device settings. We\'ll take you there now - please find StepWars and enable auto-start.'
              : 'Please enable ${permission.title} from settings to continue using all features.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.openSettings(permission.id);
              // Check permissions again after returning
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) _loadPermissions();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: permission.iconColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(isAutoStart ? 'Open Settings' : 'Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _permissions.every((p) => p.isGranted || !p.isRequired);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1a1a1a),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: ResponsiveWrapper(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            allGranted ? Icons.check_circle : Icons.security,
                            size: 48,
                            color: allGranted
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFFC107),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allGranted ? 'All Set! 🎉' : 'Permissions Needed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          allGranted
                              ? 'All permissions are granted. You\'re ready to go!'
                              : 'To provide you with the best experience, StepWars needs the following permissions:',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Permissions list
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFC107),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _permissions.length,
                      itemBuilder: (context, index) {
                        final permission = _permissions[index];
                        return _buildPermissionCard(permission);
                      },
                    ),

                  // Bottom action button
                  if (!allGranted && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                // Request all missing permissions
                                for (final permission in _permissions) {
                                  if (!permission.isGranted) {
                                    await _handlePermissionRequest(permission);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Grant All Permissions',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (widget.showCloseButton) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'I\'ll do this later',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else if (allGranted && widget.showCloseButton)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard(AppPermission permission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: permission.isGranted
              ? permission.iconColor.withOpacity(0.3)
              : Colors.white10,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: permission.isGranted
              ? null
              : () => _handlePermissionRequest(permission),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: permission.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    permission.icon,
                    color: permission.iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Title and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        permission.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        permission.description,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Status indicator
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: permission.isGranted
                      ? Container(
                          key: const ValueKey('granted'),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF4CAF50),
                            size: 24,
                          ),
                        )
                      : Container(
                          key: const ValueKey('pending'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: permission.iconColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Grant',
                            style: TextStyle(
                              color: permission.iconColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
