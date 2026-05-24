import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_media_app/core/services/api_service.dart';
import 'package:social_media_app/core/services/supabase_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _imageFile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  // AI Results
  String? _caption;
  String? _markedImageBase64;
  List<dynamic>? _objects;
  Map<String, dynamic>? _deepfakeResult;

  final TextEditingController _captionController = TextEditingController();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _error = null;
        _caption = null;
        _markedImageBase64 = null;
        _objects = null;
        _deepfakeResult = null;
        _captionController.clear();
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await ApiService.processAll(_imageFile!.path);
      setState(() {
        _caption = results['caption'];
        _captionController.text = _caption ?? '';
        _markedImageBase64 = results['marked_image'];
        _objects = results['objects'];
        _deepfakeResult = results['deepfake'];
      });
    } catch (e) {
      setState(() {
        _error = "Server unreachable or analysis failed: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePost() async {
    if (_imageFile == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await SupabaseService.createPost(
        _imageFile!.path,
        _captionController.text,
        objectsJson: _objects,
        deepfakeResult: _deepfakeResult,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = "Failed to save post: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Widget _buildAnalysisResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "AI Analysis Results",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_markedImageBase64 != null) ...[
          const Text("Marked Image:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(_markedImageBase64!),
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_deepfakeResult != null) ...[
          const Text("Authenticity:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          (() {
            final isReal = _deepfakeResult!['is_real'] == true;
            final double realPercent = _deepfakeResult!['real_percent']?.toDouble() ?? 
                (isReal ? (_deepfakeResult!['confidence'] * 100).toDouble() : (100 - _deepfakeResult!['confidence'] * 100).toDouble());
            final double aiPercent = _deepfakeResult!['ai_percent']?.toDouble() ?? 
                (!isReal ? (_deepfakeResult!['confidence'] * 100).toDouble() : (100 - _deepfakeResult!['confidence'] * 100).toDouble());
            
            final int realFlex = realPercent.round().clamp(1, 100);
            final int aiFlex = aiPercent.round().clamp(1, 100);
            
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isReal ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isReal ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isReal ? Icons.verified : Icons.warning_amber_rounded,
                        color: isReal ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isReal ? "Verdict: Real (Human Created)" : "Verdict: AI Generated (Deepfake)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isReal ? Colors.green : Colors.red,
                          ),
                        ),
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
            );
          }()),
          const SizedBox(height: 16),
        ],
        if (_objects != null && _objects!.isNotEmpty) ...[
          const Text("Detected Objects:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _objects!.map((obj) {
              return Chip(
                label: Text(obj['label'] ?? 'Unknown'),
                avatar: const Icon(Iconsax.scan, size: 16),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        const Text("Generated Caption:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _captionController,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: "Edit your caption...",
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _savePost,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Save Post"),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Upload"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.image, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text("Tap to select image", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_imageFile != null && _caption == null && !_isLoading)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _analyzeImage,
                  icon: const Icon(Iconsax.magic_star),
                  label: const Text("Analyze Image with AI"),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Analyzing image..."),
                    ],
                  ),
                ),
              ),
            if (_caption != null) _buildAnalysisResults(),
          ],
        ),
      ),
    );
  }
}
