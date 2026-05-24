import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  XFile? _selectedImage;
  final TextEditingController _captionController = TextEditingController();
  bool _isPosting = false;
  bool _isGeneratingCaption = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile; // XFile instance
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Post"),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.magic_star, color: Colors.purple),
            onPressed: () => context.push('/ai_upload'),
            tooltip: "AI Assistant",
          ),
          if (_selectedImage != null)
            TextButton(
              onPressed: _isPosting ? null : () async {
                setState(() => _isPosting = true);
                try {
                  if (kIsWeb) {
                  final bytes = await _selectedImage!.readAsBytes();
                  await SupabaseService.createPostFromBytes(bytes, _captionController.text);
                } else {
                  await SupabaseService.createPost(_selectedImage!.path, _captionController.text);
                }
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                } finally {
                  if (mounted) setState(() => _isPosting = false);
                }
              },
                child: _isPosting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text("Share", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 350,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: kIsWeb 
                              ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                              : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Iconsax.image, size: 40, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(height: 16),
                            Text("Tap to select a masterpiece", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text("Best results with high-quality images", style: theme.textTheme.labelSmall),
                          ],
                        ),
                ).animate().scale(delay: 100.ms),
              ),
              const SizedBox(height: 16),
              if (_selectedImage != null)
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingCaption ? null : () async {
                      setState(() => _isGeneratingCaption = true);
                      try {
                        final result = await ApiService.generateCaption(_selectedImage!.path);
                        if (mounted) {
                          _captionController.text = result['caption'] ?? '';
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
                      } finally {
                        if (mounted) setState(() => _isGeneratingCaption = false);
                      }
                    },
                    icon: _isGeneratingCaption
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Iconsax.magic_star),
                    label: const Text("Generate AI Caption ✨"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              FutureBuilder<Map<String, dynamic>?>(
                future: SupabaseService.client.from('profiles').select().eq('id', SupabaseService.currentUser!.id).maybeSingle(),
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  final avatarUrl = profile?['avatar_url'] ?? 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';
                  final username = profile?['username'] ?? 'You';

                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(avatarUrl),
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(username, style: const TextStyle(fontWeight: FontWeight.bold))),

                    ],
                  );
                }
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: _captionController,
                maxLines: 5,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              
              const SizedBox(height: 20),
              

            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}


