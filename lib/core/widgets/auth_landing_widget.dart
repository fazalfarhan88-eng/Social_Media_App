import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:social_media_app/core/widgets/custom_button.dart';

class AuthLandingWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const AuthLandingWidget({
    Key? key,
    required this.title,
    required this.message,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 32),
            Text(title, style: theme.textTheme.displayLarge?.copyWith(fontSize: 28), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            CustomButton(
              text: "Create Account",
              onPressed: () => context.push('/register'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.push('/'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Log In"),
            ),
          ],
        ),
      ),
    );
  }
}
