import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:social_media_app/core/widgets/custom_text_field.dart';
import 'package:social_media_app/core/widgets/custom_button.dart';
import 'package:social_media_app/core/services/supabase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.orange),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.signUpEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _usernameController.text.trim(),
        _nameController.text.trim(),
      );
      
      if (mounted) {
        _showSuccessDialog();
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message = 'Registration Failed';
        if (e.message.contains('User already registered') || e.code == 'user_already_exists') {
          message = 'This email is already taken. Please try logging in.';
        } else {
          message = e.message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Iconsax.tick_circle, color: Colors.green, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Account Created!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 12),
            const Text(
              "A verification email has been sent to your inbox. Please confirm your email to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => context.go('/'),
              child: const Text("Go to Login", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC36ACF), Color(0xFFA59441)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Iconsax.arrow_left_2),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                const SizedBox(height: 20),
                Text(
                  "Join the\nCommunity",
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                const SizedBox(height: 12),
                Text(
                  "Create an account and start sharing your best moments with the world.",
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600, fontSize: 16),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 40),

                _buildInputGroup(),

                const SizedBox(height: 32),
                CustomButton(
                  text: "Sign Up",
                  isLoading: _isLoading,
                  onPressed: _register,
                ).animate().scale(delay: 600.ms),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/'),
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          const TextSpan(text: "Already have an account? "),
                          TextSpan(
                            text: "Login",
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms),
                const SizedBox(height: 40),
              ],
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputGroup() {
    return Column(
      children: [
        CustomTextField(
          controller: _nameController,
          hintText: "Full Name",
          prefixIcon: Iconsax.user,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _usernameController,
          hintText: "Username",
          prefixIcon: Iconsax.tag,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _emailController,
          hintText: "Email Address",
          prefixIcon: Iconsax.sms,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _passwordController,
          hintText: "Password",
          prefixIcon: Iconsax.lock,
          isPassword: true,
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }
}
