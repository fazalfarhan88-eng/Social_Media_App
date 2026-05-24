import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:iconsax/iconsax.dart';

class UserListTile extends StatelessWidget {
  final Map<String, dynamic> user;
  const UserListTile({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = SupabaseService.currentUser?.id;
    final isMe = user['id'] == myId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(user['avatar_url'] ?? 'https://i.pravatar.cc/150?u=${user['id']}'),
          ),
        ),
        title: Text(user['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(user['full_name'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
        trailing: isMe 
            ? null 
            : ElevatedButton.icon(
                onPressed: () => context.push('/chat_detail/${user['id']}'),
                icon: const Icon(Iconsax.message, size: 16),
                label: const Text("Message"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
        onTap: () => context.push('/profile/${user['id']}'),
      ),
    );
  }
}
