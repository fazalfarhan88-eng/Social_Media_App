import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/core/services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = "Checking database...";

  @override
  void initState() {
    super.initState();
    _checkDbAndNavigate();
  }

  Future<void> _checkDbAndNavigate() async {
    await Future.delayed(const Duration(seconds: 1));
    try {
      await SupabaseService.client.from('profiles').select().limit(1);
      if (mounted) setState(() => _status = "Connected!");
    } catch (e) {
      if (mounted) {
        setState(() => _status = "DB Error! Please check Supabase credentials.");
      }
      await Future.delayed(const Duration(seconds: 2));
    }

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A0845), Color(0xFF6441A5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.camera, size: 100, color: Colors.white)
                .animate()
                .scale(duration: 800.ms, curve: Curves.elasticOut)
                .then()
                .shimmer(duration: 1200.ms),
            const SizedBox(height: 24),
            const Text(
              "SOCIALAPP",
              style: TextStyle(
                color: Colors.white,
                letterSpacing: 8,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            )
            .animate()
            .fadeIn(delay: 400.ms, duration: 800.ms)
            .slideY(begin: 0.5),
            const SizedBox(height: 100),
            Text(_status, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            if (_status == "Checking database...")
              const CircularProgressIndicator(color: Colors.white)
                  .animate()
                  .fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}
