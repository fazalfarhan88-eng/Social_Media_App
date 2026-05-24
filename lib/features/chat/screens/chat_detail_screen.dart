import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/utils/app_utils.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId; 
  const ChatDetailScreen({Key? key, required this.chatId}) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();

  final List<Map<String, dynamic>> _optimisticMessages = [];

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final myId = SupabaseService.currentUser?.id;
    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': myId,
      'receiver_id': widget.chatId,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
      'is_optimistic': true,
    };

    setState(() {
      _optimisticMessages.insert(0, tempMsg);
      _msgController.clear();
    });

    try {
      await SupabaseService.sendMessage(widget.chatId, text);
      // We don't need to manually remove it because the Stream will refresh 
      // and we can filter out duplicates or just wait for it.
    } catch (e) {
      debugPrint('CHAT SEND ERROR: $e');
      setState(() {
        _optimisticMessages.remove(tempMsg);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = SupabaseService.currentUser?.id;

    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseService.client.from('profiles').select().eq('id', widget.chatId).maybeSingle(),
      builder: (context, snapshot) {
        final friend = snapshot.data;
        final name = friend?['username'] ?? "Friend";
        final avatar = friend?['avatar_url'] ?? 'https://i.pravatar.cc/150?u=${widget.chatId}';

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(avatar),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("Active now", style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, color: Colors.green)),
                  ],
                ),
              ],
            ),
            actions: [

              const SizedBox(width: 8),
            ],
          ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.streamMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData && _optimisticMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Merge stream messages with optimistic ones
                final streamMessages = snapshot.data ?? [];
                
                // Filter and deduplicate
                final filteredStream = streamMessages.where((m) {
                  final sender = m['sender_id'];
                  final receiver = m['receiver_id'];
                  return (sender == myId && receiver == widget.chatId) || 
                         (sender == widget.chatId && receiver == myId);
                }).toList();

                // Combine: Stream messages + Optimistic ones that aren't in the stream yet
                final List<Map<String, dynamic>> messages = [
                  ..._optimisticMessages.where((opt) {
                    // Only show optimistic message if it's NOT already in the stream
                    return !filteredStream.any((stream) => 
                      stream['text'] == opt['text'] && 
                      stream['sender_id'] == opt['sender_id']
                    );
                  }),
                  ...filteredStream
                ];
                
                // Deduplicate by text and sender if they are very close in time (simple heuristic)
                // Actually, just showing them is fine, the stream is usually fast enough.

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircleAvatar(radius: 40, backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=friend')),
                        const SizedBox(height: 16),
                        const Text("No messages yet", style: TextStyle(fontWeight: FontWeight.bold)),
                        const Text("Start the conversation!"),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    bool isMe = msg['sender_id'] == myId;
                    bool isOptimistic = msg['is_optimistic'] == true;

                    return GestureDetector(
                      onLongPress: isMe ? () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Message"),
                            content: const Text("Are you sure you want to delete this message?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await SupabaseService.deleteMessage(msg['id']);
                                },
                                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      } : null,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(radius: 12, backgroundImage: NetworkImage(avatar)),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Opacity(
                                    opacity: isOptimistic ? 0.7 : 1.0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isMe ? theme.colorScheme.primary : theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(20).copyWith(
                                          bottomRight: isMe ? const Radius.circular(4) : null,
                                          bottomLeft: !isMe ? const Radius.circular(4) : null,
                                        ),
                                        border: isMe ? null : Border.all(color: theme.dividerColor),
                                      ),
                                      child: Text(
                                        msg['text'] ?? '',
                                        style: TextStyle(
                                          color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppUtils.formatChatTime(msg['created_at']),
                                    style: TextStyle(fontSize: 10, color: Colors.grey.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                  child: const Icon(Iconsax.camera, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: "Message...",
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Iconsax.send_2, color: theme.colorScheme.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          )
        ],
      ),
        );
      },
    );
  }
}
