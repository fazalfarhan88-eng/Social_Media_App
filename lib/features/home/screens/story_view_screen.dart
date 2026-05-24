import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/core/services/supabase_service.dart';

class StoryViewScreen extends StatefulWidget {
  final Map<String, dynamic> story;
  const StoryViewScreen({super.key, required this.story});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  int _viewerCount = 0;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    // Auto close after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) context.pop();
    });
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final story = widget.story;
    final userId = SupabaseService.currentUser?.id;
    _isOwner = (story['user_id'] ?? '') == userId;
    try {
      final count = await SupabaseService.getStoryViewersCount(story['id'].toString());
      if (mounted) setState(() => _viewerCount = count);
    } catch (_) {}
  }

  Future<void> _deleteStory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Status'),
        content: const Text('Are you sure you want to delete this status?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteStory(widget.story['id'].toString());
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final isTextStory = story['image_url'] == null;
    final bgColor = story['bg_color'] != null ? Color(int.parse(story['bg_color'])) : Colors.black;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background / Image
          Positioned.fill(
            child: isTextStory
                ? Container(
                    color: bgColor,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          story['content'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                : Image.network(story['image_url'], fit: BoxFit.cover),
          ),
          // Progress Bar
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 5),
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
            ),
          ),
          // Header (User info + actions)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(story['avatar_url'] ?? 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y'),
                ),
                const SizedBox(width: 12),
                Text(
                  story['username'] ?? 'User',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                if (_isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteStory,
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          // Viewer count overlay (bottom left)
          if (!_isOwner && _viewerCount > 0)
            Positioned(
              bottom: 30,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text('Viewed by $_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
