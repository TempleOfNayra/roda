import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/data/core/base_repository.dart';
import 'package:roda/data/core/supabase_client.dart';
import 'package:roda/data/core/db_exceptions.dart';
import 'package:roda/core/utils/logger.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(ref);
});

class StorageRepository extends BaseRepository {
  StorageRepository(super.ref);
  
  SupabaseStorageClient get _storage => ref.read(supabaseStorageClientProvider);
  
  static const String profilePicturesBucket = 'profile-pictures';
  static const String groupImagesBucket = 'group-images';
  static const String announcementImagesBucket = 'announcement-images';
  
  Future<String> uploadProfilePicture({
    required String userId,
    required Uint8List imageData,
    required String fileExtension,
  }) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Uploading profile picture for user: $userId');
        
        final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final filePath = '$userId/$fileName';
        
        await _storage.from(profilePicturesBucket).uploadBinary(
          filePath,
          imageData,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$fileExtension',
          ),
        );
        
        final publicUrl = _storage
            .from(profilePicturesBucket)
            .getPublicUrl(filePath);
        
        Logger.debug('Profile picture uploaded successfully: $publicUrl');
        return publicUrl;
      },
      operationName: 'Upload Profile Picture',
    );
  }
  
  Future<String> uploadGroupImage({
    required String groupId,
    required Uint8List imageData,
    required String fileExtension,
    required String imageType, // 'header' or 'logo'
  }) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Uploading $imageType image for group: $groupId');
        
        final fileName = '$imageType-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final filePath = '$groupId/$fileName';
        
        await _storage.from(groupImagesBucket).uploadBinary(
          filePath,
          imageData,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$fileExtension',
          ),
        );
        
        final publicUrl = _storage
            .from(groupImagesBucket)
            .getPublicUrl(filePath);
        
        Logger.debug('Group image uploaded successfully: $publicUrl');
        return publicUrl;
      },
      operationName: 'Upload Group Image',
    );
  }
  
  Future<void> deleteProfilePicture(String userId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Deleting profile pictures for user: $userId');
        
        final files = await _storage
            .from(profilePicturesBucket)
            .list(path: userId);
        
        if (files.isNotEmpty) {
          final filePaths = files.map((file) => '$userId/${file.name}').toList();
          await _storage.from(profilePicturesBucket).remove(filePaths);
          Logger.debug('Deleted ${filePaths.length} profile picture files');
        }
      },
      operationName: 'Delete Profile Picture',
    );
  }
  
  Future<void> deleteGroupImages(String groupId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Deleting images for group: $groupId');
        
        final files = await _storage
            .from(groupImagesBucket)
            .list(path: groupId);
        
        if (files.isNotEmpty) {
          final filePaths = files.map((file) => '$groupId/${file.name}').toList();
          await _storage.from(groupImagesBucket).remove(filePaths);
          Logger.debug('Deleted ${filePaths.length} group image files');
        }
      },
      operationName: 'Delete Group Images',
    );
  }
  
  Future<List<String>> listUserProfilePictures(String userId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Listing profile pictures for user: $userId');
        
        final files = await _storage
            .from(profilePicturesBucket)
            .list(path: userId);
        
        final urls = files.map((file) {
          return _storage
              .from(profilePicturesBucket)
              .getPublicUrl('$userId/${file.name}');
        }).toList();
        
        Logger.debug('Found ${urls.length} profile pictures');
        return urls;
      },
      operationName: 'List Profile Pictures',
    );
  }
  
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    required int expiresIn,
  }) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Getting signed URL for: $bucket/$path');
        
        final signedUrl = await _storage
            .from(bucket)
            .createSignedUrl(path, expiresIn);
        
        Logger.debug('Signed URL created successfully');
        return signedUrl;
      },
      operationName: 'Get Signed URL',
    );
  }
}