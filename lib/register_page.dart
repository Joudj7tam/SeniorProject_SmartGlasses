import 'package:flutter/material.dart';

import 'health_form_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'login_page.dart';

const String backendBaseUrl = 'http://10.0.2.2:8080';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Confirm password is required';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  String? _validateMobile(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Mobile number is required';
    final digitsOnly = RegExp(r'^\d{9,15}$');
    if (!digitsOnly.hasMatch(v)) return 'Enter digits only (9–15 numbers)';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _isSubmitting = true);

    try {
      final email = _emailController.text.trim();
      final pass = _passwordController.text;
      final phone = _mobileController.text.trim();

      // 1) Create Firebase user (main account)
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final user = cred.user;
      if (user == null) throw 'Signup failed';

      // 2) Register main account in MongoDB
      final uri = Uri.parse('$backendBaseUrl/api/users/register-main');

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': user.uid,
          'email': email,
          'phone': phone,
          'fcm_token': fcmToken,
        }),
      );

      if (res.statusCode != 200) {
        final decoded = jsonDecode(res.body);
        final msg = (decoded is Map && decoded['detail'] != null)
            ? decoded['detail'].toString()
            : 'Register failed (code: ${res.statusCode})';
        throw msg;
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final mainAccountId = (data['id'] ?? '').toString();

      if (mainAccountId.isEmpty) throw 'Backend did not return mainAccountId';

      if (!mounted) return;

      // 3) open health forn after successful registration and send mainAccountId
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HealthFormPage(
            mainAccountId: mainAccountId,
            firebaseUid: user.uid,
            goHomeAfterSave: true,
          ),
        ),
      );
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot connect to server. Make sure backend is running.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;

  return Scaffold(
    backgroundColor: const Color(0xFFF8EFE5),
    body: Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFBF6),
                Color(0xFFF8EFE5),
                Color(0xFFFFE7BF),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),

        Positioned(top: -90, left: -110, child: _outlineCircle(300)),
        Positioned(top: -125, right: -70, child: _outlineCircle(230)),

        Positioned(
          top: 52,
          left: 58,
          child: _circle(18, const Color(0xFFEFAA4B), opacity: 0.95),
        ),
        Positioned(
          top: 34,
          right: 130,
          child: _circle(42, const Color(0xFF2E9EA0), opacity: 0.95),
        ),
        Positioned(
          top: 125,
          right: 68,
          child: _circle(38, const Color(0xFFEFAA4B), opacity: 0.95),
        ),
        Positioned(
          bottom: size.height * 0.18,
          left: -36,
          child: _softCircle(150, const Color(0xFFEFAA4B), 0.20),
        ),
        Positioned(
          bottom: -80,
          right: -65,
          child: _softCircle(210, const Color(0xFFEFAA4B), 0.15),
        ),
        Positioned(
          top: size.height * 0.48,
          right: -18,
          child: _circle(42, const Color(0xFF2E9EA0), opacity: 0.90),
        ),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 390),
                padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.62),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.78),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 26,
                      spreadRadius: -8,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: _buildRegisterCard(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildRegisterCard() {
  return Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2E9EA0),
                Color(0xFF43B8B8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E9EA0).withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Create Account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: -0.6,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'Join Smart Glasses and personalize your eye-health experience',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8F8880),
            fontSize: 13.2,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 30),

        _inputField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: _validateEmail,
        ),

        const SizedBox(height: 14),

        _inputField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _obscurePassword,
          toggleObscure: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          textInputAction: TextInputAction.next,
          validator: _validatePassword,
        ),

        const SizedBox(height: 14),

        _inputField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.verified_user_outlined,
          isPassword: true,
          obscure: _obscurePassword,
          toggleObscure: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          textInputAction: TextInputAction.next,
          validator: _validateConfirmPassword,
        ),

        const SizedBox(height: 14),

        _inputField(
          controller: _mobileController,
          label: 'Mobile Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          validator: _validateMobile,
          onFieldSubmitted: (_) => _submit(),
        ),

        const SizedBox(height: 30),

        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFEFAA4B),
              disabledBackgroundColor: const Color(0xFFEFAA4B).withOpacity(0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account? ',
              style: TextStyle(
                color: Color(0xFF8F8880),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            GestureDetector(
              onTap: _isSubmitting
                  ? null
                  : () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    },
              child: const Text(
                'Login',
                style: TextStyle(
                  color: Color(0xFF2E9EA0),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _inputField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  bool isPassword = false,
  bool obscure = false,
  VoidCallback? toggleObscure,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
  Function(String)? onFieldSubmitted,
}) {
  return TextFormField(
    controller: controller,
    validator: validator,
    obscureText: obscure,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onFieldSubmitted: onFieldSubmitted,
    cursorColor: const Color(0xFF2E9EA0),
    style: const TextStyle(
      color: Colors.black,
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF9B9690),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF9B9690),
        size: 21,
      ),
      suffixIcon: isPassword
          ? IconButton(
              onPressed: toggleObscure,
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF9B9690),
                size: 21,
              ),
            )
          : null,
      filled: true,
      fillColor: const Color(0xFFFFFAF4).withOpacity(0.88),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFE4DDD4), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFF2E9EA0), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    ),
  );
}

Widget _circle(double size, Color color, {double opacity = 1}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(opacity),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.22),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, 5),
        ),
      ],
    ),
  );
}

Widget _outlineCircle(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.black.withOpacity(0.12),
        width: 1,
      ),
    ),
  );
}

Widget _softCircle(double size, Color color, double opacity) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(opacity),
      shape: BoxShape.circle,
    ),
  );
}

}
