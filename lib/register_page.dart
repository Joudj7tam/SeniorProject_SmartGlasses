import 'package:flutter/material.dart';

import 'health_form_page.dart';


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
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _isSubmitting = false);

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/health-form');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'name@example.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'At least 8 characters',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() {
                        _obscurePassword = !_obscurePassword;
                      }),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() {
                        _obscurePassword = !_obscurePassword;
                      }),
                      icon: Icon(
                        _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 12),


                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: 'Digits only (e.g. 05xxxxxxxx)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: _validateMobile,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Account'),
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
