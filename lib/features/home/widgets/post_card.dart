import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:social_media_app/features/home/widgets/comments_sheet.dart';
import 'package:social_media_app/features/home/widgets/reaction_picker.dart';
import 'package:social_media_app/features/home/widgets/share_post_sheet.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:social_media_app/core/services/api_service.dart';
import 'package:social_media_app/core/utils/app_utils.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_app/features/home/widgets/reactions_sheet.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String? heroTag;
  final bool autoOpenComments;
  
  const PostCard({
    Key? key, 
    required this.postData, 
    this.heroTag,
    this.autoOpenComments = false,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  String currentReaction = '';

  // AI state
  bool _isAILoading = false;
  Map<String, dynamic>? _detectionResult;
  Map<String, dynamic>? _authenticityResult;
  String? _aiCaption;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showComments());
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(postId: widget.postData['id']?.toString() ?? ''),
    );
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SharePostSheet(postData: widget.postData),
    );
  }

  void _showReactionsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReactionsSheet(postId: widget.postData['id']?.toString() ?? ''),
    );
  }

  Future<Uint8List> _downloadImageBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    return response.bodyBytes;
  }

  double _parseScore(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Future<void> _handleAiAction(String type) async {
    // TOGGLE OFF: If what we clicked is already showing, remove it and stop
    bool isCurrentlyShowing = false;
    if (type == 'obj' && _detectionResult != null) isCurrentlyShowing = true;
    if (type == 'fake' && _authenticityResult != null) isCurrentlyShowing = true;
    if (type == 'caption' && _aiCaption != null) isCurrentlyShowing = true;
    if (type == 'all' && (_detectionResult != null || _authenticityResult != null || _aiCaption != null)) isCurrentlyShowing = true;

    if (type == 'clear' || isCurrentlyShowing) {
      setState(() {
        _isAILoading = false;
        _detectionResult = null;
        _authenticityResult = null;
        _aiCaption = null;
      });
      return;
    }

    // Standard Loading Start
    setState(() {
      _isAILoading = true;
      _detectionResult = null;
      _authenticityResult = null;
      _aiCaption = null;
    });

    try {
      final imgUrl = widget.postData['image_url']?.toString() ?? '';
      if (imgUrl.isEmpty) throw "Image source not found";

      final imageBytes = await _downloadImageBytes(imgUrl);
      Map<String, dynamic> res;

      switch (type) {
        case 'obj':
          res = await ApiService.detectObjects(imageBytes);
          setState(() {
            _detectionResult = {
              'objects': (res['objects'] as List?)?.map((e) => (e as Map)['label']?.toString() ?? 'Object').toList() ?? [],
              'marked_image': res['marked_image']?.toString()
            };
          });
          break;
        case 'fake':
          res = await ApiService.detectDeepfake(imageBytes);
          setState(() {
            final dynamic raw = res.containsKey('deepfake') ? res['deepfake'] : res;
            _authenticityResult = (raw is Map) ? Map<String, dynamic>.from(raw) : null;
          });
          break;
        case 'caption':
          res = await ApiService.generateCaption(imageBytes);
          setState(() => _aiCaption = res['caption']?.toString());
          break;
        case 'all':
          res = await ApiService.processAll(imageBytes);
          setState(() {
            _detectionResult = {
              'objects': (res['objects'] as List?)?.map((e) => (e as Map)['label']?.toString() ?? 'Object').toList() ?? [],
              'marked_image': res['marked_image']?.toString()
            };
            final dynamic rawFake = res['deepfake'];
            _authenticityResult = (rawFake is Map) ? Map<String, dynamic>.from(rawFake) : null;
            _aiCaption = res['caption']?.toString();
          });
          break;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String imageUrl = widget.postData['image_url']?.toString() ?? '';
    final String markedImg = _detectionResult?['marked_image']?.toString() ?? '';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () {
              final uid = widget.postData['user_id']?.toString() ?? '';
              if (uid.isNotEmpty) {
                context.push('/profile/$uid');
              }
            },
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(widget.postData['avatar_url']?.toString() ?? AppUtils.defaultAvatar),
            ),
            title: Text(widget.postData['username']?.toString() ?? 'User', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(AppUtils.formatTime(widget.postData['created_at']?.toString()), 
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          if (widget.postData['caption'] != null && widget.postData['caption'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
              child: Text(
                widget.postData['caption']?.toString() ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.3),
              ),
            ),
          
          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Hero(
                      tag: widget.heroTag ?? (imageUrl.isNotEmpty ? imageUrl : UniqueKey().toString()),
                      child: (markedImg.isNotEmpty)
                          ? Image.memory(base64Decode(markedImg), 
                              fit: BoxFit.cover, width: double.infinity, height: 380)
                          : Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, height: 380),
                    ),
                    if (_isAILoading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black26,
                          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.streamReactions(widget.postData['id'].toString()),
                  builder: (context, snapshot) {
                    final reactions = snapshot.data ?? [];
                    final myId = SupabaseService.currentUser?.id;
                    final myReaction = reactions.firstWhere(
                      (r) => r['user_id'] == myId,
                      orElse: () => <String, dynamic>{},
                    );
                    final String activeReaction = myReaction['reaction_type']?.toString() ?? '';
                    
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReactionPicker(
                          currentReaction: activeReaction,
                          onReact: (reactionType) async {
                            if (activeReaction == reactionType) {
                              await SupabaseService.removeReaction(widget.postData['id']);
                            } else {
                              await SupabaseService.upsertReaction(widget.postData['id'], reactionType);
                            }
                          },
                        ),
                        if (reactions.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _showReactionsList,
                            child: Text(
                              '${reactions.length}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.streamComments(widget.postData['id'].toString()),
                  builder: (context, snapshot) {
                    final commentsCount = snapshot.data?.length ?? 0;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Iconsax.message, color: Colors.grey),
                          onPressed: _showComments,
                        ),
                        if (commentsCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              '$commentsCount',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Iconsax.send_2, color: Colors.grey),
                  onPressed: _showShareSheet,
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.blue.shade400]),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Iconsax.magic_star, color: Colors.white, size: 20),
                    onSelected: _handleAiAction,
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'all', child: Row(children: [Icon(Iconsax.flash_1, size: 18), SizedBox(width: 8), Text("Full Analysis")])),
                      const PopupMenuItem(value: 'fake', child: Row(children: [Icon(Iconsax.shield_security, size: 18), SizedBox(width: 8), Text("AI vs Real Check")])),
                      const PopupMenuItem(value: 'obj', child: Row(children: [Icon(Iconsax.scanner, size: 18), SizedBox(width: 8), Text("Detect Objects")])),
                      const PopupMenuItem(value: 'caption', child: Row(children: [Icon(Iconsax.edit, size: 18), SizedBox(width: 8), Text("AI Caption")])),
                    ],
                  ),
                ).animate().shimmer(duration: 2.seconds),
              ],
            ),
          ),

          if (_aiCaption != null || _detectionResult != null || _authenticityResult != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.cpu, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text("AI AUDIT REPORT", style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: theme.colorScheme.primary
                        )),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _handleAiAction('clear'),
                          child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    
                    if (_authenticityResult != null) ...[
                      _buildDoubleConfidenceBar(
                        realPercent: _parseScore(_authenticityResult?['real_score']),
                        aiPercent: _parseScore(_authenticityResult?['ai_score']),
                      ),
                      const SizedBox(height: 8),
                      Text("Verdict: ${_authenticityResult?['verdict']?.toString() ?? 'Unknown'}", 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                    ],

                    if (_aiCaption != null) ...[
                      Text("Description: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.primary)),
                      Text(_aiCaption ?? "", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                    ],

                    if (_detectionResult != null)
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: (_detectionResult!['objects'] as List? ?? []).map((o) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text("#${o.toString()}", style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        )).toList(),
                      ),
                  ],
                ),
              ).animate().fadeIn().scale(alignment: Alignment.bottomCenter),
            ),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDoubleConfidenceBar({required double realPercent, required double aiPercent}) {
    return Column(
      children: [
        _singleBar("Real Image", realPercent, Colors.green),
        const SizedBox(height: 8),
        _singleBar("AI Generated", aiPercent, Colors.orange),
      ],
    );
  }

  Widget _singleBar(String label, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text("${percent.toStringAsFixed(1)}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
