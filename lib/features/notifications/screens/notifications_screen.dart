import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/widgets/auth_landing_widget.dart';
import 'package:social_media_app/core/utils/app_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Map<String, Map<String, dynamic>> _profileCache = {};
  final Map<String, String?> _postImageCache = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<AuthState>(
      stream: SupabaseService.client.auth.onAuthStateChange,
      builder: (context, authSnapshot) {
        if (SupabaseService.currentUser == null) {
          return const Scaffold(
            body: AuthLandingWidget(
              title: "Activity",
              message: "",
              icon: Iconsax.notification,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Activity"),
            actions: [
              IconButton(icon: const Icon(Iconsax.setting_5), onPressed: () {}),
            ],
          ),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.streamNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return const Center(child: Text("Something went wrong"));
              }
              
              final notifications = snapshot.data ?? [];
              
              // Trigger batch fetches
              _batchFetchData(notifications);

              if (notifications.isEmpty) {
                return _buildEmptyState(theme);
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final type = notification['type'];
                  final senderId = notification['sender_id'];
                  final postId = notification['post_id']?.toString();
                  
                  final profile = _profileCache[senderId];
                  final avatar = profile?['avatar_url'] ?? 'https://i.pravatar.cc/150?u=$senderId';
                  final username = profile?['username'] ?? 'Someone';
                  final postImage = postId != null ? _postImageCache[postId] : null;

                  final notificationInfo = _getNotificationInfo(type);
                  final bool isRead = notification['is_read'] ?? false;

                  return GestureDetector(
                    onTap: () async {
                      if (!isRead) {
                        SupabaseService.markNotificationAsRead(notification['id'].toString());
                      }
                      
                      if (postId != null) {
                        try {
                          final postData = await SupabaseService.client
                              .from('posts_with_profiles')
                              .select()
                              .eq('id', postId)
                              .single();
                          
                          if (mounted) {
                            context.push('/home/post', extra: {
                              'postData': postData,
                              'heroTag': 'notification_$postId',
                              'autoOpenComments': type == 'comment',
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post not found or deleted')),
                            );
                          }
                        }
                      } else {
                        context.push('/profile/$senderId');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRead ? theme.colorScheme.surface : theme.colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: isRead ? null : Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                        boxShadow: isRead ? [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                        ] : [],
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(avatar, notificationInfo.icon, notificationInfo.iconColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNotificationText(theme, username, notificationInfo.message, isRead, notification['created_at']),
                          ),
                          if (postImage != null)
                            _buildPostThumbnail(postImage),
                        ],
                      ),
                    ),
                  );
                },
              ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _batchFetchData(List<Map<String, dynamic>> notifications) async {
    final List<String> profileIds = [];
    final List<String> postIds = [];

    for (var n in notifications) {
      final senderId = n['sender_id'];
      final postId = n['post_id']?.toString();
      if (!_profileCache.containsKey(senderId)) profileIds.add(senderId);
      if (postId != null && !_postImageCache.containsKey(postId)) postIds.add(postId);
    }

    if (profileIds.isEmpty && postIds.isEmpty) return;

    try {
      if (profileIds.isNotEmpty) {
        final profiles = await SupabaseService.client.from('profiles').select().inFilter('id', profileIds);
        for (var p in profiles) _profileCache[p['id']] = p;
      }
      if (postIds.isNotEmpty) {
        final posts = await SupabaseService.client.from('posts').select('id, image_url').inFilter('id', postIds);
        for (var p in posts) _postImageCache[p['id'].toString()] = p['image_url'];
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Batch fetch error: $e");
    }
  }

  Widget _buildAvatar(String avatar, IconData icon, Color iconColor) {
    return Stack(
      children: [
        CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatar)),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 12, color: iconColor),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationText(ThemeData theme, String username, String message, bool isRead, String? createdAt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyLarge,
            children: [
              TextSpan(text: "$username ", style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: message),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (!isRead) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(
              AppUtils.formatTime(createdAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostThumbnail(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.cover),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Iconsax.notification_bing, size: 60, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  _NotificationInfo _getNotificationInfo(String type) {
    switch (type) {
      case 'like': return _NotificationInfo(Iconsax.heart5, Colors.red, "liked your post.");
      case 'comment': return _NotificationInfo(Iconsax.message_text5, Colors.blue, "commented on your post.");
      case 'follow': return _NotificationInfo(Iconsax.user_add, Colors.green, "added you as a friend.");
      case 'message': return _NotificationInfo(Iconsax.message_2, Colors.orange, "sent you a message.");
      case 'post': return _NotificationInfo(Iconsax.image, Colors.purple, "shared a new post.");
      case 'story': return _NotificationInfo(Iconsax.flash, Colors.amber, "added to their story.");
      default: return _NotificationInfo(Iconsax.notification, Colors.grey, "interacted with you.");
    }
  }
}

class _NotificationInfo {
  final IconData icon;
  final Color iconColor;
  final String message;
  _NotificationInfo(this.icon, this.iconColor, this.message);
}

