import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/core/utils/logger.dart';

class GroupMedia {
  final String id;
  final String groupId;
  final String uploadedBy;
  final String url;
  final String mediaType; // 'photo' or 'video'
  final String? caption;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  GroupMedia({
    required this.id,
    required this.groupId,
    required this.uploadedBy,
    required this.url,
    required this.mediaType,
    this.caption,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory GroupMedia.fromJson(Map<String, dynamic> json) {
    return GroupMedia(
      id: json['id'],
      groupId: json['group_id'],
      uploadedBy: json['uploaded_by'],
      url: json['url'],
      mediaType: json['media_type'],
      caption: json['caption'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'uploaded_by': uploadedBy,
      'url': url,
      'media_type': mediaType,
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class GroupMediaService {
  final SupabaseClient _supabase;
  
  GroupMediaService(this._supabase);
  
  // Fetch all media for a group
  Future<List<GroupMedia>> getGroupMedia(String groupId) async {
    try {
      final response = await _supabase
          .from('group_media')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => GroupMedia.fromJson(json))
          .toList();
    } catch (e) {
      Logger.debug('Error fetching group media: $e');
      return [];
    }
  }
  
  // Save media to database
  Future<GroupMedia?> saveMedia({
    required String groupId,
    required String url,
    required String mediaType,
    String? caption,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        Logger.debug('No user logged in');
        return null;
      }
      
      final response = await _supabase
          .from('group_media')
          .insert({
            'group_id': groupId,
            'uploaded_by': userId,
            'url': url,
            'media_type': mediaType,
            'caption': caption,
          })
          .select()
          .single();
      
      return GroupMedia.fromJson(response);
    } catch (e) {
      Logger.debug('Error saving media: $e');
      return null;
    }
  }
  
  // Update media caption
  Future<bool> updateCaption(String mediaId, String caption) async {
    try {
      await _supabase
          .from('group_media')
          .update({'caption': caption})
          .eq('id', mediaId);
      
      return true;
    } catch (e) {
      Logger.debug('Error updating caption: $e');
      return false;
    }
  }
  
  // Delete media
  Future<bool> deleteMedia(String mediaId) async {
    try {
      await _supabase
          .from('group_media')
          .delete()
          .eq('id', mediaId);
      
      return true;
    } catch (e) {
      Logger.debug('Error deleting media: $e');
      return false;
    }
  }
  
  // Stream media updates for realtime
  Stream<List<GroupMedia>> streamGroupMedia(String groupId) {
    return _supabase
        .from('group_media')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => GroupMedia.fromJson(json)).toList());
  }
}

// Provider for the service
final groupMediaServiceProvider = Provider<GroupMediaService>((ref) {
  return GroupMediaService(Supabase.instance.client);
});

// Provider for fetching group media
final groupMediaProvider = FutureProvider.family<List<GroupMedia>, String>((ref, groupId) async {
  final service = ref.watch(groupMediaServiceProvider);
  return service.getGroupMedia(groupId);
});

// Provider for streaming group media
final groupMediaStreamProvider = StreamProvider.family<List<GroupMedia>, String>((ref, groupId) {
  final service = ref.watch(groupMediaServiceProvider);
  return service.streamGroupMedia(groupId);
});