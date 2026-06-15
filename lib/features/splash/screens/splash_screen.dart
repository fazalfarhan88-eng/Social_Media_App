import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    // Immediate transition to fix "late load" issue.
    // Native splash handles the initial visibility.
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Matches the native splash screen background to prevent flicker
    return const Scaffold(
      backgroundColor: Color(0xFF2A0845),
      body: SizedBox.shrink(),
    );
  }
}
