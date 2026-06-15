import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/core/services/supabase_service.dart';

class ReactionsSheet extends StatefulWidget {
  final dynamic postId;
  const ReactionsSheet({Key? key, required this.postId}) : super(key: key);

  @override
  State<ReactionsSheet> createState() => _ReactionsSheetState();
}

class _ReactionsSheetState extends State<ReactionsSheet> {
  final Map<String, Map<String, dynamic>> _profileCache = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(height: 16),
          Text("Reactions", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.streamReactions(widget.postId.toString()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final reactions = snapshot.data ?? [];
                _batchFetchProfiles(reactions);

                if (reactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_emotions_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text("No reactions yet."),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: reactions.length,
                  itemBuilder: (context, index) {
                    final reaction = reactions[index];
                    final userId = reaction['user_id'];
                    final profile = _profileCache[userId];
                    final String username = profile?['username'] ?? 'User';
                    final String fullName = profile?['full_name'] ?? '';
                    final String avatarUrl = profile?['avatar_url'] ?? 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';
                    
                    final String type = reaction['reaction_type'] ?? 'like';
                    String emoji = '👍';
                    if (type == 'love') emoji = '❤️';
                    else if (type == 'haha') emoji = '😂';
                    else if (type == 'sad') emoji = '😢';
                    else if (type == 'angry') emoji = '😡';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/profile/$userId');
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(avatarUrl),
                        ),
                      ),
                      title: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/profile/$userId');
                        },
                        child: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      subtitle: Text(fullName),
                      trailing: Text(emoji, style: const TextStyle(fontSize: 24)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _batchFetchProfiles(List<Map<String, dynamic>> reactions) async {
    final List<String> ids = [];
    for (var r in reactions) {
      if (!_profileCache.containsKey(r['user_id'])) ids.add(r['user_id']);
    }
    if (ids.isEmpty) return;
    try {
      final profiles = await SupabaseService.client.from('profiles').select().inFilter('id', ids);
      if (mounted) {
        setState(() {
          for (var p in profiles) _profileCache[p['id']] = p;
        });
      }
    } catch (e) {
      debugPrint("Batch fetch profiles error: $e");
    }
  }
}
