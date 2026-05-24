import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/utils/app_utils.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final Map<String, Map<String, dynamic>> _profileCache = {};

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        actions: [
          IconButton(icon: const Icon(Iconsax.edit), onPressed: () => context.push('/search')),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client.from('messages').stream(primaryKey: ['id']).order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final allMessages = snapshot.data!;
                final myMessages = allMessages.where((m) => m['sender_id'] == myId || m['receiver_id'] == myId).toList();

                final Map<String, Map<String, dynamic>> conversations = {};
                final List<String> profileIdsToFetch = [];

                for (var msg in myMessages) {
                  final otherId = msg['sender_id'] == myId ? msg['receiver_id'] : msg['sender_id'];
                  if (!conversations.containsKey(otherId)) {
                    conversations[otherId] = msg;
                    if (!_profileCache.containsKey(otherId)) {
                      profileIdsToFetch.add(otherId);
                    }
                  }
                }

                if (profileIdsToFetch.isNotEmpty) {
                  _fetchProfiles(profileIdsToFetch);
                }

                if (conversations.isEmpty) {
                  return _buildEmptyInbox();
                }

                var sortedUserIds = conversations.keys.toList();

                return ListView.builder(
                  itemCount: sortedUserIds.length,
                  itemBuilder: (context, index) {
                    final otherId = sortedUserIds[index];
                    final lastMsg = conversations[otherId]!;
                    final profile = _profileCache[otherId];
                    
                    final name = profile?['username'] ?? 'User';
                    final avatar = profile?['avatar_url'] ?? 'https://i.pravatar.cc/150?u=$otherId';

                    if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
                      return const SizedBox.shrink();
                    }

                    return Dismissible(
                      key: Key(otherId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Iconsax.trash, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        await SupabaseService.deleteConversation(otherId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conversation deleted")));
                        }
                      },
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Chat"),
                            content: const Text("Are you sure you want to delete this conversation? This cannot be undone."),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(avatar),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          lastMsg['text'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: lastMsg['receiver_id'] == myId && lastMsg['created_at'] != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          AppUtils.formatChatTime(lastMsg['created_at']),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        onTap: () => context.push('/chat_detail/$otherId'),
                      ),
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

  Future<void> _fetchProfiles(List<String> ids) async {
    try {
      final profiles = await SupabaseService.client.from('profiles').select().inFilter('id', ids);
      if (mounted) {
        setState(() {
          for (var p in profiles) {
            _profileCache[p['id']] = p;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching profiles: $e");
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: const InputDecoration(
            hintText: "Search messages...",
            prefixIcon: Icon(Iconsax.search_normal),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyInbox() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.message_notif, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No Messages Yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Text("Start a conversation with your friends!"),
        ],
      ),
    );
  }
}


