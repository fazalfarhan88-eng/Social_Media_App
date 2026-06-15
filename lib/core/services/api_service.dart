import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace this URL with your latest Google Colab Ngrok URL
  static const String baseUrl = 'https://eatable-monument-gone.ngrok-free.dev';
  static const String apiKey = 'social_media_app_2024_secure_key';

  /// Internal helper to send image and return response
  /// Uses Uint8List for full cross-platform compatibility (Web, Android, iOS)
  static Future<Map<String, dynamic>> _postImage(String endpoint, Uint8List imageBytes) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final request = http.MultipartRequest('POST', uri);

      request.headers['X-API-Key'] = apiKey;
      request.headers['Accept'] = 'application/json';
      
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'upload.jpg',
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw 'Server Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      throw 'AI Connection Error: $e';
    }
  }

  /// 1. Object Detection (Returns only 'objects' and 'marked_image')
  static Future<Map<String, dynamic>> detectObjects(Uint8List imageBytes) async {
    return await _postImage('detect_objects', imageBytes);
  }

  /// 2. Image Captioning (Returns only 'caption')
  static Future<Map<String, dynamic>> generateCaption(Uint8List imageBytes) async {
    return await _postImage('generate_caption', imageBytes);
  }

  /// 3. Deepfake Detection (Returns only authenticity results)
  static Future<Map<String, dynamic>> detectDeepfake(Uint8List imageBytes) async {
    return await _postImage('detect_deepfake', imageBytes);
  }

  /// 4. Complete Analysis (Returns everything combined)
  static Future<Map<String, dynamic>> processAll(Uint8List imageBytes) async {
    return await _postImage('process_all', imageBytes);
  }
}
