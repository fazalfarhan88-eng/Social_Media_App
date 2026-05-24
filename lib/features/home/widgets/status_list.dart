import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/utils/auth_guard.dart';
import 'package:social_media_app/core/utils/app_utils.dart';

class StatusList extends StatefulWidget {
  const StatusList({Key? key}) : super(key: key);

  @override
  State<StatusList> createState() => _StatusListState();
}

class _StatusListState extends State<StatusList> {
  String? _myAvatar;

  @override
  void initState() {
    super.initState();
    _fetchMyAvatar();
  }

  Future<void> _fetchMyAvatar() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    try {
      final data = await SupabaseService.client.from('profiles').select('avatar_url').eq('id', user.id).maybeSingle();
      if (mounted) setState(() => _myAvatar = data?['avatar_url']);
    } catch (e) {
      debugPrint("Fetch my avatar error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.streamStories(),
        builder: (context, snapshot) {
          final stories = snapshot.data ?? [];
          final bool isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: isLoading ? 5 : (stories.length + 1), // +1 for "Your Status"
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              if (index == 0) return _buildMyStatus(context);
              
              if (isLoading) return _buildPlaceholder();

              final story = stories[index - 1];
              final String username = story['username'] ?? 'User';
              final String? avatarUrl = story['avatar_url'];
              final String userId = story['user_id'];

              return _buildCreatorItem(context, username, avatarUrl, userId, story);
            },
          );
        },
      ),
    );
  }

  Widget _buildMyStatus(BuildContext context) {
    return GestureDetector(
      onTap: () => AuthGuard.executeWithAuth(context, () => context.push('/create_story')),
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      backgroundImage: _myAvatar != null ? NetworkImage(_myAvatar!) : null,
                      child: _myAvatar == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 20, color: Colors.white),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            const Text("Your Status", style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorItem(BuildContext context, String name, String? avatar, String userId, Map<String, dynamic> story) {
    return Padding(
      padding: const EdgeInsets.only(right: 18.0),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              context.push('/story_view', extra: story);
            },
            onLongPress: () {
              context.push('/profile/$userId');
            },
            child: Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFF833AB4), // Purple
                    Color(0xFFFD1D1D), // Red
                    Color(0xFFF56040), // Orange
                    Color(0xFFFCAF45), // Yellow
                    Color(0xFF833AB4), // Back to Purple
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundImage: NetworkImage(avatar ?? '${AppUtils.defaultAvatar}$name'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push('/profile/$userId'),
            child: SizedBox(
              width: 76,
              child: Text(
                name,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Padding(
      padding: const EdgeInsets.only(right: 18.0),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.withOpacity(0.1)),
          ),
          const SizedBox(height: 8),
          Container(width: 40, height: 8, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }
}

