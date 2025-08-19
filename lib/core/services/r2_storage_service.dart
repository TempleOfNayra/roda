import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../config/r2_config.dart';
import '../utils/logger.dart';

class R2StorageService {
  static Future<String?> uploadProfilePicture({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      Logger.debug('🚀 Starting R2 upload for user: $userId');
      Logger.debug('📁 File: ${imageFile.name}, Path: ${imageFile.path}');
      Logger.debug('🌐 Worker URL: ${R2Config.uploadWorkerUrl}');
      
      final file = File(imageFile.path);
      final bytes = await file.readAsBytes();
      Logger.debug('📊 File size: ${bytes.length} bytes');
      
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
      
      Logger.debug('📤 Sending request to Worker...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      Logger.debug('📥 Response status: ${response.statusCode}');
      Logger.debug('📥 Response body: $responseBody');
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        final url = data['url'];
        Logger.debug('✅ Upload successful! URL: $url');
        return url;
      } else {
        Logger.debug('❌ Upload failed with status ${response.statusCode}: $responseBody');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.debug('❌ Error uploading profile picture: $e');
      Logger.debug('Stack trace: $stackTrace');
      return null;
    }
  }
}