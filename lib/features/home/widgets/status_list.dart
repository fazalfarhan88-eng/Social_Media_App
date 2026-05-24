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
      final data = await SupabaseService.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) setState(() => _myAvatar = data?['avatar_url']);
    } catch (e) {
      debugPrint('Fetch my avatar error: $e');
    }
  }

  /// Group raw stories list by user_id → one entry per user
  List<Map<String, dynamic>> _groupByUser(List<Map<String, dynamic>> stories) {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final story in stories) {
      final uid = story['user_id'] as String;
      if (!grouped.containsKey(uid)) {
        grouped[uid] = {
          'user_id': uid,
          'username': story['username'] ?? 'User',
          'avatar_url': story['avatar_url'],
          'stories': <Map<String, dynamic>>[story],
        };
      } else {
        (grouped[uid]!['stories'] as List<Map<String, dynamic>>).add(story);
      }
    }
    return grouped.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.streamStories(),
        builder: (context, snapshot) {
          final allStories = snapshot.data ?? [];
          final bool isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

          // Separate my own stories from others
          final myId = SupabaseService.currentUser?.id ?? '';
          final myStories = allStories
              .where((s) => s['user_id'] == myId)
              .toList();
          final otherStories =
              allStories.where((s) => s['user_id'] != myId).toList();
          final grouped = _groupByUser(otherStories);

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: isLoading ? 5 : (1 + grouped.length),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildMyStatus(context, myStories);
              }
              if (isLoading) return _buildPlaceholder();
              final group = grouped[index - 1];
              return _buildGroupItem(context, group);
            },
          );
        },
      ),
    );
  }

  // ── My Status bubble ────────────────────────────────────────────────────────
  Widget _buildMyStatus(
      BuildContext context, List<Map<String, dynamic>> myStories) {
    final hasStories = myStories.isNotEmpty;
    return GestureDetector(
      onTap: () {
        if (hasStories) {
          // Show own stories + option to add more
          _showStoryPicker(context, {
            'user_id': SupabaseService.currentUser?.id ?? '',
            'username': 'Your Status',
            'avatar_url': _myAvatar,
            'stories': myStories,
          }, isOwn: true);
        } else {
          AuthGuard.executeWithAuth(
              context, () => context.push('/create_story'));
        }
      },
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
                    border: Border.all(
                      color: hasStories
                          ? const Color(0xFF833AB4)
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.4),
                      width: hasStories ? 3 : 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      backgroundImage: _myAvatar != null
                          ? NetworkImage(_myAvatar!)
                          : null,
                      child: _myAvatar == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => AuthGuard.executeWithAuth(
                        context, () => context.push('/create_story')),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2),
                      ),
                      child: const Icon(Icons.add, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Your Status', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── Other user grouped bubble ────────────────────────────────────────────────
  Widget _buildGroupItem(
      BuildContext context, Map<String, dynamic> group) {
    final String name = group['username'] ?? 'User';
    final String? avatar = group['avatar_url'];
    final String userId = group['user_id'];
    final List<Map<String, dynamic>> stories =
        List<Map<String, dynamic>>.from(group['stories'] as List);
    final int count = stories.length;

    return GestureDetector(
      onTap: () => _showStoryPicker(context, group, isOwn: false),
      onLongPress: () => context.push('/profile/$userId'),
      child: Padding(
        padding: const EdgeInsets.only(right: 18.0),
        child: Column(
          children: [
            Stack(
              children: [
                // Gradient ring
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFF833AB4),
                        Color(0xFFFD1D1D),
                        Color(0xFFF56040),
                        Color(0xFFFCAF45),
                        Color(0xFF833AB4),
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
                          backgroundImage: NetworkImage(
                              avatar ?? '${AppUtils.defaultAvatar}$name'),
                        ),
                      ),
                    ),
                  ),
                ),
                // Story count badge
                if (count > 1)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF833AB4),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 76,
              child: Text(
                name,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Story Picker Bottom Sheet ────────────────────────────────────────────────
  void _showStoryPicker(
      BuildContext context, Map<String, dynamic> group,
      {required bool isOwn}) {
    final List<Map<String, dynamic>> stories =
        List<Map<String, dynamic>>.from(group['stories'] as List);
    final String username = group['username'] ?? 'User';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: group['avatar_url'] != null
                        ? NetworkImage(group['avatar_url'])
                        : null,
                    child: group['avatar_url'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    username,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (isOwn)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        AuthGuard.executeWithAuth(
                            context, () => context.push('/create_story'));
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${stories.length} Status${stories.length > 1 ? 'es' : ''}',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              // Stories grid / list
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: stories.length,
                  itemBuilder: (_, i) {
                    final story = stories[i];
                    final bool isImg = story['image_url'] != null;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/story_view', extra: story);
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: story['bg_color'] != null
                              ? Color(int.tryParse(
                                      story['bg_color'].toString()) ??
                                  0xFF333333)
                              : Colors.grey.shade800,
                          image: isImg
                              ? DecorationImage(
                                  image:
                                      NetworkImage(story['image_url']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: Stack(
                          children: [
                            if (!isImg)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    story['content'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11),
                                    textAlign: TextAlign.center,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            // Delete button for own stories
                            if (isOwn)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () async {
                                    // Capture navigator references BEFORE any async gap
                                    final sheetNavigator = Navigator.of(ctx);
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                                    // Show confirmation dialog using the outer (scaffold) context
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (d) => AlertDialog(
                                        title: const Text('Delete Status'),
                                        content: const Text(
                                            'Are you sure you want to delete this status?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(d, false),
                                              child: const Text('Cancel')),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(d, true),
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      // Pop the bottom sheet using the pre-captured navigator
                                      if (sheetNavigator.canPop()) {
                                        sheetNavigator.pop();
                                      }
                                      try {
                                        await SupabaseService.deleteStory(
                                            story['id']);
                                        scaffoldMessenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Status deleted ✅'),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } catch (e) {
                                        debugPrint('Delete failed: $e');
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Delete failed: $e'),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.delete,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ── Skeleton placeholder ─────────────────────────────────────────────────────
  Widget _buildPlaceholder() {
    return Padding(
      padding: const EdgeInsets.only(right: 18.0),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withOpacity(0.1)),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 8,
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }
}
