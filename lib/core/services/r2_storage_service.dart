import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../config/r2_config.dart';

class R2StorageService {
  static Future<String?> uploadProfilePicture({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      print('🚀 Starting R2 upload for user: $userId');
      print('📁 File: ${imageFile.name}, Path: ${imageFile.path}');
      print('🌐 Worker URL: ${R2Config.uploadWorkerUrl}');
      
      final file = File(imageFile.path);
      final bytes = await file.readAsBytes();
      print('📊 File size: ${bytes.length} bytes');
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(R2Config.uploadWorkerUrl),
      );
      
      request.headers['Authorization'] = 'Bearer ${R2Config.uploadApiKey}';
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: imageFile.name,
        ),
      );
      
      request.fields['userId'] = userId;
      request.fields['type'] = 'profile_picture';
      
      print('📤 Sending request to Worker...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: $responseBody');
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        final url = data['url'];
        print('✅ Upload successful! URL: $url');
        return url;
      } else {
        print('❌ Upload failed with status ${response.statusCode}: $responseBody');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error uploading profile picture: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}