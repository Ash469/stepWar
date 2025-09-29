import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../widget/footer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _isLoading = true;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile({bool forceReload = false}) async {
    if (forceReload) {
      setState(() {
        _isLoading = true;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    final userProfileString = prefs.getString('userProfile');
    if (userProfileString != null) {
      final userJson = jsonDecode(userProfileString) as Map<String, dynamic>;

      setState(() {
        _user = UserModel(
          userId: userJson['userId'] ?? '',
          email: userJson['email'],
          username: userJson['username'],
          profileImageUrl: userJson['profileImageUrl'],
          dob: userJson['dob'] != null
              ? DateTime.tryParse(userJson['dob'])
              : null,
          gender: userJson['gender'],
          weight: (userJson['weight'] as num?)?.toDouble(),
          height: (userJson['height'] as num?)?.toDouble(),
          contactNo: userJson['contactNo'],
          stepGoal: (userJson['stepGoal'] as num?)?.toInt(),
          todaysStepCount: (userJson['todaysStepCount'] as num?)?.toInt(),
        );
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAndReloadProfile(UserModel updatedUser) async {
    if (mounted) Navigator.of(context).pop();

    setState(() => _isLoading = true);
    try {
      await _authService.updateUserProfile(updatedUser);
      await _loadUserProfile(forceReload: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.yellow));
    }

    if (_user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Could not load user profile.',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _logout,
              child: const Text('Log Out'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // 1. YOUR SCROLLABLE CONTENT (at the bottom of the stack)
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Padding(
            // Add padding at the bottom to avoid the main navigation bar
            padding: const EdgeInsets.only(bottom: 100.0),
            child: Column(
              children: [
                // Add space at the top so the header doesn't get hidden by the button
                const SizedBox(height: 56),
                _buildProfileHeader(),
                const SizedBox(height: 24),
                _buildInfoCard(
                    title: 'About you',
                    child: _buildAboutYouSection(),
                    onEditTap: () => _showEditAboutYouSheet()),
                const SizedBox(height: 16),
                _buildInfoCard(
                    title: 'Your Profile',
                    child: _buildYourProfileSection(),
                    onEditTap: () => _showEditYourProfileSheet()),
                const SizedBox(height: 24),
                _buildStepsChart(),
                const SizedBox(height: 40),
                const StepWarsFooter(),
              ],
            ),
          ),
        ),
        Positioned(
          top: 16.0, 
          right: 16.0, 
          child: IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ),
      ],
    );
  }

  void _showEditSheet(
      {required String title,
      required Widget content,
      required VoidCallback onSave}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                content,
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.yellow.shade700,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: _user!.profileImageUrl != null
                  ? NetworkImage(_user!.profileImageUrl!)
                  : null,
              child: _user!.profileImageUrl == null
                  ? const Icon(Icons.person, size: 50, color: Colors.white70)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _user!.username ?? 'Username',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _user!.email ?? 'No email provided',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
      {required String title,
      required Widget child,
      required VoidCallback onEditTap}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              GestureDetector(
                onTap: onEditTap,
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildAboutYouSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildDetailItem('Gender', _user!.gender ?? 'NA'),
        _buildDetailItem(
            'DOB',
            _user!.dob != null
                ? DateFormat('dd/MM/yyyy').format(_user!.dob!)
                : 'NA'),
        _buildDetailItem('Weight', '${_user!.weight?.toString() ?? 'NA'} kg'),
        _buildDetailItem('Height', '${_user!.height?.toString() ?? 'NA'} cm'),
      ],
    );
  }

  Widget _buildYourProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailItem('Email', _user!.email ?? 'Not provided',
            isColumn: true),
        const SizedBox(height: 16),
        _buildDetailItem('Contact No.', _user!.contactNo ?? 'Not provided',
            isColumn: true),
      ],
    );
  }

  void _showEditNameAndPhotoSheet() {
    final nameController = TextEditingController(text: _user?.username);
    const textStyle = TextStyle(color: Colors.black);
    const labelStyle = TextStyle(color: Colors.black54);

    _showEditSheet(
      title: 'Edit Profile',
      content: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: _user!.profileImageUrl != null
                ? NetworkImage(_user!.profileImageUrl!)
                : null,
            child: _user!.profileImageUrl == null
                ? Icon(Icons.person, size: 40, color: Colors.grey.shade800)
                : null,
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement image picking logic
            },
            child: const Text('Edit Photo'),
          ),
          TextField(
            controller: nameController,
            style: textStyle,
            decoration: const InputDecoration(
              labelText: 'Your name',
              labelStyle: labelStyle,
            ),
          ),
        ],
      ),
      onSave: () {
        final updatedUser =
            _user!.copyWith(username: nameController.text.trim());
        _updateAndReloadProfile(updatedUser);
      },
    );
  }

  void _showEditAboutYouSheet() {
    final weightController =
        TextEditingController(text: _user?.weight?.toString());
    final heightController =
        TextEditingController(text: _user?.height?.toString());
    DateTime? selectedDob = _user?.dob;
    String? selectedGender = _user?.gender;

    const textStyle = TextStyle(color: Colors.black);
    const labelStyle = TextStyle(color: Colors.black54);

    _showEditSheet(
      title: 'About You',
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gender', style: labelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = 'Male'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedGender == 'Male'
                              ? Colors.yellow.shade700
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Male',
                            style: TextStyle(
                              color: selectedGender == 'Male'
                                  ? Colors.black
                                  : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = 'Female'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedGender == 'Female'
                              ? Colors.yellow.shade700
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Female',
                            style: TextStyle(
                              color: selectedGender == 'Female'
                                  ? Colors.black
                                  : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDob ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDob = pickedDate;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    labelStyle: labelStyle,
                  ),
                  child: Text(
                    selectedDob != null
                        ? DateFormat('dd/MM/yyyy').format(selectedDob!)
                        : 'Select Date',
                    style: textStyle,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: weightController,
                  style: textStyle,
                  decoration: const InputDecoration(
                    labelText: 'Weight in KG',
                    labelStyle: labelStyle,
                  ),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(
                  controller: heightController,
                  style: textStyle,
                  decoration: const InputDecoration(
                    labelText: 'Height in cm',
                    labelStyle: labelStyle,
                  ),
                  keyboardType: TextInputType.number),
            ],
          );
        },
      ),
      onSave: () {
        final updatedUser = _user!.copyWith(
          gender: selectedGender,
          dob: selectedDob,
          weight: double.tryParse(weightController.text.trim()),
          height: double.tryParse(heightController.text.trim()),
        );
        _updateAndReloadProfile(updatedUser);
      },
    );
  }

  void _showEditYourProfileSheet() {
    final contactController = TextEditingController(text: _user?.contactNo);

    const textStyle = TextStyle(color: Colors.black);
    const labelStyle = TextStyle(color: Colors.black54);

    _showEditSheet(
      title: 'Your Profile',
      content: Column(
        children: [
          TextField(
            controller: contactController,
            style: textStyle,
            decoration: const InputDecoration(
              labelText: 'Contact No.',
              labelStyle: labelStyle,
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      onSave: () {
        final updatedUser =
            _user!.copyWith(contactNo: contactController.text.trim());
        _updateAndReloadProfile(updatedUser);
      },
    );
  }

  void _showSetGoalSheet() {
    final goalController =
        TextEditingController(text: _user?.stepGoal?.toString());

    const textStyle = TextStyle(color: Colors.black);
    const labelStyle = TextStyle(color: Colors.black54);

    _showEditSheet(
      title: 'Set Goal',
      content: TextField(
        controller: goalController,
        style: textStyle,
        decoration: const InputDecoration(
          labelText: 'Add Your Steps',
          labelStyle: labelStyle,
        ),
        keyboardType: TextInputType.number,
      ),
      onSave: () {
        final updatedUser =
            _user!.copyWith(stepGoal: int.tryParse(goalController.text.trim()));
        _updateAndReloadProfile(updatedUser);
      },
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isColumn = false}) {
    if (isColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      );
    }
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ],
    );
  }

  Widget _buildStepsChart() {
    final Map<String, int> stepsData = {
      'MO': 9568,
      'TU': 2563,
      'WE': 7000,
      'TH': 6500,
      'FR': 8000,
      'SA': 5000,
      'SU': 2121
    };
    const int maxSteps = 10000;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Last 7 days steps',
                style: TextStyle(color: Colors.white)),
            GestureDetector(
              onTap: _showSetGoalSheet,
              child: Text('+ Add Goal',
                  style: TextStyle(color: Colors.yellow.shade700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chevron_left, color: Colors.white),
            const SizedBox(width: 8),
            Text('Sep 10 - Sep 17 2025',
                style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: stepsData.entries.map((entry) {
              return _buildBar(
                day: entry.key,
                steps: entry.value,
                maxSteps: maxSteps,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(
      {required String day, required int steps, required int maxSteps}) {
    final double barHeight = (steps / maxSteps) * 100.0;
    final bool showLabel = day == 'MO' || day == 'TU' || day == 'SU';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showLabel)
          Text(NumberFormat.compact().format(steps),
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          height: barHeight.clamp(7.0, 120.0),
          width: 24,
          decoration: BoxDecoration(
            color: Colors.yellow.shade700,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ],
    );
  }
}

extension UserModelCopyWith on UserModel {
  UserModel copyWith({
    String? username,
    String? email,
    String? profileImageUrl,
    DateTime? dob,
    String? gender,
    double? weight,
    double? height,
    String? contactNo,
    int? stepGoal,
    int? todaysStepCount,
  }) {
    return UserModel(
      userId: userId,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      contactNo: contactNo ?? this.contactNo,
      stepGoal: stepGoal ?? this.stepGoal,
      todaysStepCount: todaysStepCount ?? this.todaysStepCount,
    );
  }
}
