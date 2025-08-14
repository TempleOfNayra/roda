import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:roda/core/config/r2_config.dart';
import 'package:path/path.dart' as path;

class StorageService {
  // Upload profile picture
  // This assumes you have a Cloudflare Worker set up to handle uploads
  static Future<String?> uploadProfilePicture({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = 'profiles/$userId/avatar_$timestamp$extension';
      
      // Read file bytes
      final bytes = await imageFile.readAsBytes();
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(R2Config.uploadWorkerUrl),
      );
      
      // Add headers
      request.headers['Authorization'] = 'Bearer ${R2Config.uploadApiKey}';
      
      // Add file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );
      
      // Add metadata
      request.fields['userId'] = userId;
      request.fields['type'] = 'profile_picture';
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Assuming the worker returns the public URL
        return '${R2Config.publicBucketUrl}/$fileName';
      } else {
        print('Failed to upload image: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      return null;
    }
  }
  
  // Alternative: Direct upload to public bucket (if CORS is configured)
  static Future<String?> uploadProfilePictureDirectly({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = 'profiles/$userId/avatar_$timestamp$extension';
      
      // Read file bytes
      final bytes = await imageFile.readAsBytes();
      
      // Direct PUT to R2 public bucket (requires CORS configuration)
      final url = Uri.parse('${R2Config.publicBucketUrl}/$fileName');
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': _getContentType(extension),
        },
        body: bytes,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return '${R2Config.publicBucketUrl}/$fileName';
      } else {
        print('Failed to upload image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      return null;
    }
  }
  
  static String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}