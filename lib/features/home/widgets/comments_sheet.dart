import 'package:flutter/material.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/utils/app_utils.dart';

class CommentsSheet extends StatefulWidget {
  final dynamic postId;
  const CommentsSheet({Key? key, required this.postId}) : super(key: key);

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final Map<String, Map<String, dynamic>> _profileCache = {};
  Map<String, dynamic>? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserProfile();
  }

  Future<void> _fetchCurrentUserProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    try {
      final data = await SupabaseService.client.from('profiles').select('avatar_url').eq('id', user.id).maybeSingle();
      if (mounted) setState(() => _currentUserProfile = data);
    } catch (e) {
      debugPrint("Fetch current profile error: $e");
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    
    _commentController.clear();
    try {
      await SupabaseService.addComment(widget.postId, text);
    } catch (e) {
      debugPrint('COMMENT ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
          Text("Comments", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.streamComments(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final comments = snapshot.data ?? [];
                _batchFetchProfiles(comments);

                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.comment_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text("No comments yet. Be the first!"),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final userId = comment['user_id'];
                    final profile = _profileCache[userId];
                    final String username = profile?['username'] ?? 'User';
                    final String avatarUrl = profile?['avatar_url'] ?? 'https://i.pravatar.cc/150?u=$userId';
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(avatarUrl),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppUtils.formatTime(comment['created_at']), 
                                      style: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 11)
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(15).copyWith(topLeft: Radius.zero),
                                  ),
                                  child: Text(comment['content'] ?? '', style: const TextStyle(fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage: _currentUserProfile?['avatar_url'] != null ? NetworkImage(_currentUserProfile!['avatar_url']) : null,
                  child: _currentUserProfile?['avatar_url'] == null ? Icon(Icons.person, color: theme.colorScheme.primary, size: 20) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: "Add a comment...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _submitComment,
                  icon: Icon(Icons.send, color: theme.colorScheme.primary),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _batchFetchProfiles(List<Map<String, dynamic>> comments) async {
    final List<String> ids = [];
    for (var c in comments) {
      if (!_profileCache.containsKey(c['user_id'])) ids.add(c['user_id']);
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

