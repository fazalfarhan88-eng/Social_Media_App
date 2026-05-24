import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/utils/auth_guard.dart';
import 'package:social_media_app/features/home/widgets/comments_sheet.dart';
import 'package:social_media_app/features/home/widgets/reaction_picker.dart';
import 'package:social_media_app/features/home/widgets/share_post_sheet.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:social_media_app/core/services/api_service.dart';

import 'package:social_media_app/core/utils/app_utils.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String? heroTag;
  final bool autoOpenComments;
  const PostCard({Key? key, required this.postData, this.heroTag, this.autoOpenComments = false}) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  bool showHeartAnim = false;
  String currentReaction = '';

  // AI state
  bool _isDetecting = false;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _detectionResult;
  Map<String, dynamic>? _authenticityResult;


  @override
  void initState() {
    super.initState();
    _fetchMyReaction();
    if (widget.autoOpenComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showComments();
      });
    }
  }

  Future<void> _fetchMyReaction() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    
    try {
      final response = await SupabaseService.client
          .from('reactions')
          .select('reaction_type')
          .eq('post_id', widget.postData['id'])
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null && mounted) {
        setState(() {
          currentReaction = response['reaction_type'] as String;
          isLiked = true;
        });
      }
    } catch (e) {
      debugPrint("FETCH REACTION ERROR: $e");
    }
  }

  void handleReaction(String reaction) {
    AuthGuard.executeWithAuth(context, () {
      if (currentReaction == reaction) {
        // Remove reaction if clicking the same one again
        setState(() {
          isLiked = false;
          currentReaction = '';
        });
        SupabaseService.removeReaction(widget.postData['id']);
      } else {
        setState(() {
          isLiked = true;
          currentReaction = reaction;
        });
        SupabaseService.upsertReaction(widget.postData['id'], reaction);
      }
    });
  }

  void handleDoubleTap() {
    if (currentReaction != 'like') handleReaction('like');
    setState(() => showHeartAnim = true);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => showHeartAnim = false);
    });
  }



  void showReactionsList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: SupabaseService.client
              .from('reactions_with_profiles')
              .select()
              .eq('post_id', widget.postData['id'])
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final reactions = snapshot.data!;
            if (reactions.isEmpty) return const Center(child: Text("No reactions yet."));

            return ListView.builder(
              itemCount: reactions.length,
              itemBuilder: (context, index) {
                final r = reactions[index];
                String emoji = '👍';
                if (r['reaction_type'] == 'love') emoji = '❤️';
                if (r['reaction_type'] == 'haha') emoji = '😂';
                if (r['reaction_type'] == 'sad') emoji = '😢';
                if (r['reaction_type'] == 'angry') emoji = '😡';

                return ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(r['avatar_url'] ?? '')),
                  title: Text(r['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(emoji, style: const TextStyle(fontSize: 24)),
                );
              },
            );
          },
        );
      },
    );
  }

  void showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(postId: widget.postData['id']),
    );
  }

  Future<String> _downloadImageToTemp(String url) async {
    final response = await http.get(Uri.parse(url));
    final bytes = response.bodyBytes;
    final file = File('${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _detectObjects() async {
    setState(() {
      _isDetecting = true;
      _detectionResult = null;
      _authenticityResult = null;
    });
    try {
      final imageUrl = widget.postData['image_url'] ?? 'https://picsum.photos/500/500';
      final tempPath = await _downloadImageToTemp(imageUrl);
      final result = await ApiService.detectObjects(tempPath);
      if (mounted) setState(() => _detectionResult = result);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  Future<void> _analyzeAuthenticity() async {
    setState(() {
      _isAnalyzing = true;
      _authenticityResult = null;
      _detectionResult = null;
    });
    try {
      final imageUrl = widget.postData['image_url'] ?? 'https://picsum.photos/500/500';
      final tempPath = await _downloadImageToTemp(imageUrl);
      final result = await ApiService.detectDeepfake(tempPath);
      final isReal = result['is_real'] == true;
      final confidence = result['confidence'] != null ? (result['confidence'] * 100).toInt() : 0;
      final double realPercent = result['real_percent']?.toDouble() ?? 
          (isReal ? (result['confidence'] * 100).toDouble() : (100 - result['confidence'] * 100).toDouble());
      final double aiPercent = result['ai_percent']?.toDouble() ?? 
          (!isReal ? (result['confidence'] * 100).toDouble() : (100 - result['confidence'] * 100).toDouble());
      
      final formattedResult = {
        'is_real': isReal,
        'confidence': confidence,
        'real_percent': realPercent,
        'ai_percent': aiPercent,
        'verdict': isReal ? 'Verdict: Real (Human Created)' : 'Verdict: AI Generated (Deepfake)',
      };
      
      if (mounted) setState(() => _authenticityResult = formattedResult);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String imageUrl = widget.postData['image_url'] ?? 'https://picsum.photos/500/500';
    final String caption = widget.postData['caption'] ?? '';
    final String avatarUrl = widget.postData['avatar_url'] ?? '${AppUtils.defaultAvatar}${widget.postData['user_id']}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 12, right: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile/${widget.postData['user_id']}'),
                  child: Hero(
                    tag: 'avatar_${widget.postData['id']}',
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(avatarUrl),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.postData['username'] ?? "Anonymous",
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text("Verified Creator", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                          const SizedBox(width: 4),
                          Text("•", style: TextStyle(color: Colors.grey.withOpacity(0.5))),
                          const SizedBox(width: 4),
                          Text(
                            AppUtils.formatTime(widget.postData['created_at']),
                            style: TextStyle(fontSize: 10, color: Colors.grey.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.postData['user_id'] == SupabaseService.currentUser?.id)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_horiz),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text("Edit Caption")),
                      const PopupMenuItem(value: 'delete', child: Text("Delete Post", style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (val) async {
                      if (val == 'delete') {
                        final confirm = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Post"),
                            content: const Text("Are you sure? This cannot be undone."),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await SupabaseService.deletePost(widget.postData['id'].toString());
                        }
                      } else if (val == 'edit') {
                        final controller = TextEditingController(text: widget.postData['caption']);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Edit Caption"),
                            content: TextField(controller: controller, maxLines: 3),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await SupabaseService.updatePost(widget.postData['id'].toString(), controller.text);
                                },
                                child: const Text("Save"),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {},
                  )
              ],
            ),
          ),
          
          // Caption ABOVE the image
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge,
                  children: [
                    TextSpan(
                      text: '${widget.postData['username'] ?? 'User'} ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: caption),
                  ],
                ),
              ),
            ),

          // Image
          GestureDetector(
            onDoubleTap: handleDoubleTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: widget.heroTag ?? 'post_${widget.postData['id']}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: (_detectionResult != null && _detectionResult!['marked_image'] != null)
                          ? Image.memory(
                              base64Decode(_detectionResult!['marked_image']!),
                              width: double.infinity,
                              height: 400,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: 400,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  if (showHeartAnim)
                    const Icon(Icons.favorite, color: Colors.white, size: 80)
                        .animate()
                        .scale(duration: 200.ms, begin: const Offset(0.5, 0.5), end: const Offset(1.2, 1.2))
                        .then()
                        .shake(duration: 300.ms)
                        .fadeOut(delay: 400.ms),
                ],
              ),
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                ReactionPicker(
                  onReact: handleReaction,
                  currentReaction: currentReaction,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: showReactionsList,
                  child: Text(
                    "Reactions",
                    style: theme.textTheme.labelSmall?.copyWith(
                      decoration: TextDecoration.underline,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const Spacer(),
                // Comment
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: showComments,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Iconsax.message_2, size: 20, color: theme.iconTheme.color),
                  ),
                ),
                // Share
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    AuthGuard.executeWithAuth(context, () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SharePostSheet(postData: widget.postData),
                      );
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Iconsax.send_1, size: 20, color: theme.iconTheme.color),
                  ),
                ),
                // AI Tools compact popup
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Iconsax.magic_star,
                    size: 20,
                    color: (_detectionResult != null || _authenticityResult != null)
                        ? Colors.purple
                        : theme.iconTheme.color,
                  ),
                  onSelected: (value) {
                    if (value == 'detect') _detectObjects();
                    if (value == 'analyze') _analyzeAuthenticity();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'detect', child: Text("Detect Objects")),
                    const PopupMenuItem(value: 'analyze', child: Text("Analyze Image")),
                  ],
                ),
              ],
            ),
          ),


          
          // AI Results shown inline below image
          if (_isDetecting || _isAnalyzing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text("AI is thinking...", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
          
          if (_detectionResult != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.purple.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.scan, size: 16, color: Colors.purple),
                        const SizedBox(width: 6),
                        const Text("AI Detected Objects", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _detectionResult = null),
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: List<String>.from(_detectionResult!['objects'])
                          .map((obj) => Chip(
                                label: Text(obj),
                                backgroundColor: Colors.purple.withOpacity(0.1),
                                labelStyle: const TextStyle(fontSize: 12),
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

          if (_authenticityResult != null)
            (() {
              final isReal = _authenticityResult!['is_real'] == true;
              final double realPercent = _authenticityResult!['real_percent']?.toDouble() ?? 
                  (isReal ? (_authenticityResult!['confidence']).toDouble() : (100 - _authenticityResult!['confidence']).toDouble());
              final double aiPercent = _authenticityResult!['ai_percent']?.toDouble() ?? 
                  (!isReal ? (_authenticityResult!['confidence']).toDouble() : (100 - _authenticityResult!['confidence']).toDouble());
              
              final int realFlex = realPercent.round().clamp(1, 100);
              final int aiFlex = aiPercent.round().clamp(1, 100);
              
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isReal ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isReal ? Colors.green.withOpacity(0.25) : Colors.red.withOpacity(0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isReal ? Iconsax.verify5 : Iconsax.warning_25,
                            color: isReal ? Colors.green : Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _authenticityResult!['verdict'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isReal ? Colors.green : Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _authenticityResult = null),
                            child: const Icon(Icons.close, size: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Premium Dual Progress Bar
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: Colors.grey.withOpacity(0.2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Row(
                            children: [
                              Expanded(
                                flex: realFlex,
                                child: Container(
                                  color: Colors.green,
                                ),
                              ),
                              Expanded(
                                flex: aiFlex,
                                child: Container(
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Real: ${realPercent.toStringAsFixed(1)}%",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            "AI: ${aiPercent.toStringAsFixed(1)}%",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }()),

          // View all comments link
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: GestureDetector(
              onTap: showComments,
              child: Text(
                "View all comments",
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}


