import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stepwars_app/screens/main_screen.dart';
import '../services/auth_service.dart';
import 'profile_completion_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum LoginState {
  initial,
  enterEmail,
  enterOtp,
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  LoginState _loginState = LoginState.initial;

  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _resendTimer = 45;
  Timer? _timer;

  @override
  void dispose() {
    _emailController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        _timer?.cancel();
      }
    });
  }

  // --- Navigation Logic ---
  Future<void> _navigateAfterLogin() async {
    final user = _authService.currentUser;
    if (user == null || !mounted) return;
    setState(() => _isLoading = true);

    final isNew = await _authService.isNewUser(user.uid);

    if (!mounted) return;

    if (isNew) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProfileCompletionScreen(user: user),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();

      if (user != null && mounted) {
        await _navigateAfterLogin();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in was cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted && _authService.currentUser == null) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.sendOtpToEmail(_emailController.text.trim());
      if (mounted) {
        setState(() {
          _loginState = LoginState.enterOtp;
          _startResendTimer();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit OTP.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user =
          await _authService.verifyOtpAndSignIn(_emailController.text, otp);
      if (user != null && mounted) {
        await _navigateAfterLogin();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
        );
      }
    } finally {
      if (mounted && _authService.currentUser == null) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final paddingTop = MediaQuery.of(context).padding.top;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDD85D), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - paddingTop - paddingBottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: screenHeight * 0.05),
                      child: Image.asset(
                        'assets/images/login.png',
                        fit: BoxFit.contain,
                        height: screenHeight * 0.32,
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Welcome to',
                            style: TextStyle(
                                fontSize: 24,
                                color: Colors.black,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Step Wars',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 30),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _buildAuthForm(),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    switch (_loginState) {
      case LoginState.initial:
        return _buildInitialButtons();
      case LoginState.enterEmail:
        return _buildEmailForm();
      case LoginState.enterOtp:
        return _buildOtpForm();
    }
  }

  Widget _buildInitialButtons() {
    return Column(
      key: const ValueKey('initial'),
      children: [
        const Text('Sign in',
            style: TextStyle(
                fontSize: 24,
                color: Colors.black,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        _buildButton('Sign in with Email', Icons.email, () {
          setState(() => _loginState = LoginState.enterEmail);
        }),
        const SizedBox(height: 16),
        _buildButton(
            'Sign in with Google', Icons.g_mobiledata, _signInWithGoogle,
            isLoading: _isLoading),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Column(
      key: const ValueKey('emailForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sign in',
            style: TextStyle(
                fontSize: 24,
                color: Colors.black,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        const Text('Email',
            style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.normal)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
          
          decoration: InputDecoration(
            hintText: 'Enter your email',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintStyle: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 20),
        _buildButton('Send OTP', null, _sendOtp,
            isPrimary: true, isLoading: _isLoading),
        const SizedBox(height: 16),
        _buildButton(
            'Sign in with Google', Icons.g_mobiledata, _signInWithGoogle,
            isLoading: _isLoading),
        TextButton(
            onPressed: () => setState(() => _loginState = LoginState.initial),
            child: const Text("Back"))
      ],
    );
  }

  Widget _buildOtpForm() {
    return Column(
      key: const ValueKey('otpForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verify OTP',
            style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('OTP is successfully sent to ${_emailController.text}',
            style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(255, 6, 6, 6),
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.normal)),
        TextButton(
            onPressed: () =>
                setState(() => _loginState = LoginState.enterEmail),
            child: const Text('Change email')),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) => _buildOtpBox(index)),
        ),
        const SizedBox(height: 20),
        Center(
          child: _timer != null && _timer!.isActive
              ? Text(
                  'Resend OTP in 00:${_resendTimer.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.normal))
              : TextButton(
                  onPressed: _sendOtp,
                  child: const Text('Resend OTP',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.normal))),
        ),
        const SizedBox(height: 20),
        _buildButton('Verify OTP', null, _verifyOtp,
            isPrimary: true, isLoading: _isLoading),
      ],
    );
  }


Widget _buildOtpBox(int index) {
  return SizedBox(
    width: 45,
    height: 55,
    child: TextFormField(
      controller: _otpControllers[index],
      focusNode: _otpFocusNodes[index],
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      maxLength: 1, // Keep maxLength to 1 to enforce single digit visually
      style: const TextStyle(
        color: Colors.black,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (value) {
        if (value.length == 1 && index < 5) {
          FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
        } else if (value.isEmpty && index > 0) {
          FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
        } else if (value.length > 1 && int.tryParse(value) != null) {
          if (value.length == 6) {
            for (int i = 0; i < 6; i++) {
              _otpControllers[i].text = value[i];
            }
            FocusScope.of(context).requestFocus(_otpFocusNodes[5]);

          }
        }
      },
    ),
  );
}

  Widget _buildButton(String text, IconData? icon, VoidCallback? onPressed,
      {bool isPrimary = false, bool isLoading = false}) {
    if (isPrimary) {
      return ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFDD85D),
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, size: 24),
                  if (icon != null) const SizedBox(width: 12),
                  Text(text,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
      );
    } else {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: Colors.black26),
        ),
        child: isLoading
            ? const CircularProgressIndicator()
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, size: 24),
                  if (icon != null) const SizedBox(width: 12),
                  Text(text,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
      );
    }
  }
}
