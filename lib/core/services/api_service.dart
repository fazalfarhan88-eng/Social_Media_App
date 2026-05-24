import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace this URL with your Google Colab Cloudflare URL (e.g., 'https://xxx.trycloudflare.com')
  static const String baseUrl = 'https://eatable-monument-gone.ngrok-free.dev';
  static const String apiKey = 'social_media_app_2024_secure_key';

  static Future<Map<String, dynamic>> processAll(String imagePath) async {
    final uri = Uri.parse('$baseUrl/process_all');
    final request = http.MultipartRequest('POST', uri);
    
    request.headers['X-API-Key'] = apiKey;
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      return json.decode(responseData);
    } else {
      throw Exception('Failed to process image: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> detectObjects(String imagePath) async {
    final uri = Uri.parse('$baseUrl/detect_objects');
    final request = http.MultipartRequest('POST', uri);
    
    request.headers['X-API-Key'] = apiKey;
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      return json.decode(responseData);
    } else {
      throw Exception('Failed to detect objects: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> generateCaption(String imagePath) async {
    final uri = Uri.parse('$baseUrl/generate_caption');
    final request = http.MultipartRequest('POST', uri);
    
    request.headers['X-API-Key'] = apiKey;
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      return json.decode(responseData);
    } else {
      throw Exception('Failed to generate caption: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> detectDeepfake(String imagePath) async {
    final uri = Uri.parse('$baseUrl/detect_deepfake');
    final request = http.MultipartRequest('POST', uri);
    
    request.headers['X-API-Key'] = apiKey;
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      return json.decode(responseData);
    } else {
      throw Exception('Failed to detect deepfake: ${response.statusCode}');
    }
  }

  static Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
