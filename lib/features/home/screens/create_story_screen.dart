import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:social_media_app/core/widgets/custom_button.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _textController = TextEditingController();
  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  String _selectedBgColor = '0xFF6C63FF'; // Default purple-ish

  final List<String> _bgColors = [
    '0xFF6C63FF',
    '0xFFFF6584',
    '0xFF43E97B',
    '0xFFFA709A',
    '0xFF38F9D7',
    '0xFF000000',
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageFile = pickedFile;
        _selectedImageBytes = bytes;
        _textController.clear();
      });
    }
  }

  Future<void> _postStory() async {
    if (_selectedImageBytes == null && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an image or text for your story')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.createStory(
        imageBytes: _selectedImageBytes,
        content: _selectedImageBytes == null ? _textController.text.trim() : null,
        bgColor: _selectedImageBytes == null ? _selectedBgColor : null,
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story posted!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Story'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: CustomButton(
              text: 'Post',
              isLoading: _isLoading,
              onPressed: _postStory,
              width: 80,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_selectedImageBytes != null) ...[
              Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    height: 400,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        _selectedImageBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    right: 24,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() {
                          _selectedImageFile = null;
                          _selectedImageBytes = null;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                margin: const EdgeInsets.all(16),
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(int.parse(_selectedBgColor)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Type something...',
                        hintStyle: TextStyle(color: Colors.white60),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Pick a Background Color', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _bgColors.length,
                  itemBuilder: (context, index) {
                    final color = _bgColors[index];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedBgColor = color),
                      child: Container(
                        width: 50,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Color(int.parse(color)),
                          shape: BoxShape.circle,
                          border: _selectedBgColor == color
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  icon: Iconsax.image,
                  label: 'Gallery',
                  onPressed: _pickImage,
                  theme: theme,
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  icon: Iconsax.camera,
                  label: 'Camera',
                  onPressed: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.camera);
                    if (pickedFile != null) {
                      final bytes = await pickedFile.readAsBytes();
                      setState(() {
                        _selectedImageFile = pickedFile;
                        _selectedImageBytes = bytes;
                        _textController.clear();
                      });
                    }
                  },
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
