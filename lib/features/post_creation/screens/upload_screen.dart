import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_media_app/core/services/api_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;

  // Active result tracking
  String _activeTool = 'none'; // 'objects', 'deepfake', 'none'

  // AI Results
  String? _markedImageBase64;
  List<dynamic>? _objects;
  Map<String, dynamic>? _deepfakeResult;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _resetUI();
      });
    }
  }

  void _resetUI() {
    _activeTool = 'none';
    _markedImageBase64 = null;
    _objects = null;
    _deepfakeResult = null;
    _error = null;
  }

  // --- STRICTLY SEPARATED API CALLS ---

  Future<void> _detectObjects() async {
    if (_imageBytes == null) return;
    _resetUI(); // Pehle sab clear karo
    setState(() { _isLoading = true; _activeTool = 'objects'; });
    try {
      final res = await ApiService.detectObjects(_imageBytes!);
      setState(() {
        _objects = res['objects'];
        _markedImageBase64 = res['marked_image'];
      });
    } catch (e) { setState(() => _error = e.toString()); }
    finally { setState(() => _isLoading = false); }
  }

  Future<void> _checkDeepfake() async {
    if (_imageBytes == null) return;
    _resetUI(); // Pehle sab clear karo
    setState(() { _isLoading = true; _activeTool = 'deepfake'; });
    try {
      final res = await ApiService.detectDeepfake(_imageBytes!);
      setState(() { _deepfakeResult = res; });
    } catch (e) { setState(() => _error = e.toString()); }
    finally { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Laboratory")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Image Preview
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 250, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                child: _imageBytes != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                  : const Icon(Iconsax.image, size: 50, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),

            // TOOL BUTTONS - Strictly Independent
            if (_imageBytes != null && !_isLoading) ...[
              Row(
                children: [
                  Expanded(child: _buildToolBtn("Object Detection", Iconsax.scan, _detectObjects, Colors.purple, _activeTool == 'objects')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildToolBtn("Analyze Image", Iconsax.mask, _checkDeepfake, Colors.indigo, _activeTool == 'deepfake')),
                ],
              ),
            ],

            if (_isLoading) const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),

            // RESULT VIEW - Only shows the requested one
            const SizedBox(height: 24),
            if (_activeTool == 'objects' && _objects != null) _buildObjectsResult(),
            if (_activeTool == 'deepfake' && _deepfakeResult != null) _buildDeepfakeResult(),
            
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolBtn(String label, IconData icon, VoidCallback onTap, Color color, bool isActive) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? color : color.withOpacity(0.1),
        foregroundColor: isActive ? Colors.white : color,
        elevation: isActive ? 4 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(children: [Icon(icon, size: 20), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 10))]),
    );
  }

  Widget _buildObjectsResult() {
    return Column(children: [
      if (_markedImageBase64 != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(base64Decode(_markedImageBase64!), width: double.infinity, fit: BoxFit.contain)
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _objects!.map((o) => Chip(
          label: Text(o['label'] ?? 'Object'),
          backgroundColor: Colors.purple.withOpacity(0.1),
        )).toList(),
      ),
    ]);
  }

  Widget _buildDeepfakeResult() {
    bool isReal = _deepfakeResult!['is_real'] ?? false;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isReal ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isReal ? Colors.green : Colors.red),
      ),
      child: Column(children: [
        Icon(isReal ? Iconsax.verify : Iconsax.warning_2, color: isReal ? Colors.green : Colors.red, size: 40),
        const SizedBox(height: 12),
        Text(isReal ? "CONTENT IS REAL" : "AI GENERATED CONTENT", style: TextStyle(color: isReal ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
        Text("Match Confidence: ${(_deepfakeResult!['confidence'] * 100).toStringAsFixed(1)}%"),
      ]),
    );
  }
}
