import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/widgets/custom_button.dart';

class AuthGuard {
  /// Executes the [action] if the user is logged in.
  /// Otherwise, it shows a beautiful bottom sheet prompting the user to Login or Register.
  static void executeWithAuth(BuildContext context, VoidCallback action) {
    if (SupabaseService.currentUser != null) {
      // User is authenticated
      action();
    } else {
      // User is a guest
      _showLoginPrompt(context);
    }
  }

  static void _showLoginPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LoginPromptSheet(),
    );
  }
}

class LoginPromptSheet extends StatelessWidget {
  const LoginPromptSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 48),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(height: 32),
          Text(
            "Join the Community",
            style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 12),
          Text(
            "Create an account or login to interact, like, and share your own moments with the world.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          CustomButton(
            text: "Create Account",
            onPressed: () {
              Navigator.pop(context);
              context.push('/register');
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: theme.colorScheme.primary),
            ),
            onPressed: () {
              Navigator.pop(context);
              context.push('/');
            },
            child: Text("Log in", style: TextStyle(fontSize: 16, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
