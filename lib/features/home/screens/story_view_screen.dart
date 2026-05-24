import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


class StoryViewScreen extends StatefulWidget {
  final Map<String, dynamic> story;
  const StoryViewScreen({super.key, required this.story});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  @override
  void initState() {
    super.initState();
    // Auto close after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final isTextStory = story['image_url'] == null;
    final bgColor = story['bg_color'] != null 
        ? Color(int.parse(story['bg_color'])) 
        : Colors.black;

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
                : Image.network(
                    story['image_url'],
                    fit: BoxFit.cover,
                  ),
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

          // Header (User info)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(story['avatar_url'] ?? 'https://i.pravatar.cc/150'),
                ),
                const SizedBox(width: 12),
                Text(
                  story['username'] ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
