import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  // Authentication
  static Future<AuthResponse> signInEmail(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUpEmail(String email, String password, String username, String fullName) async {
    final response = await client.auth.signUp(
      email: email, 
      password: password,
      emailRedirectTo: 'io.supabase.socialmediaapp://login-callback/',
      data: {
        'username': username,
        'full_name': fullName,
      }
    );
    
    // We are no longer inserting manually here via Flutter to avoid RLS race conditions.
    // The insertion is handled flawlessly by the Database Trigger on the Supabase Platform.

    return response;
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  static User? get currentUser => client.auth.currentUser;

  // Streams
  static Stream<List<Map<String, dynamic>>> streamPosts() {
    final query = client.from('posts_with_profiles').stream(primaryKey: ['id']);
    
    // If logged in, hide own posts from home feed (discovery mode)
    // if (currentUser != null) {
    //   return query.neq('user_id', currentUser!.id).order('created_at', ascending: false);
    // }
    
    return query.order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> streamUserPosts(String userId) {
    return client
        .from('posts_with_profiles')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }
  
  static Stream<List<Map<String, dynamic>>> streamMessages(String otherUserId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // Profiles & Users
  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    return await client.from('profiles').select().neq('id', currentUser?.id ?? '');
  }

  static Future<void> updateProfile({String? fullName, String? bio, String? avatarUrl}) async {
    await client.from('profiles').update({
      if (fullName != null) 'full_name': fullName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', currentUser!.id);
  }

  // Follow System
  static Future<void> followUser(String targetUserId) async {
    await client.from('follows').insert({
      'follower_id': currentUser!.id,
      'following_id': targetUserId,
    });
    await _createNotification(receiverId: targetUserId, type: 'follow');
  }

  static Future<void> unfollowUser(String targetUserId) async {
    await client.from('follows').delete().eq('follower_id', currentUser!.id).eq('following_id', targetUserId);
  }

  // Notifications
  static Stream<List<Map<String, dynamic>>> streamNotifications() {
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', currentUser!.id)
        .order('created_at', ascending: false);
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await client.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  static Future<void> _createNotification({
    required String receiverId,
    required String type,
    dynamic postId,
  }) async {
    if (receiverId == currentUser!.id) return; // Don't notify self

    try {
      await client.from('notifications').insert({
        'receiver_id': receiverId,
        'sender_id': currentUser!.id,
        'type': type,
        'post_id': postId,
      });
    } catch (e) {
      debugPrint("Create Notification Error: $e");
    }
  }

  static Future<void> _notifyFollowers({required String type, dynamic postId}) async {
    try {
      final followers = await client.from('follows').select('follower_id').eq('following_id', currentUser!.id);
      if (followers.isEmpty) return;

      final List<Map<String, dynamic>> notifications = followers.map((f) => {
        'receiver_id': f['follower_id'],
        'sender_id': currentUser!.id,
        'type': type,
        'post_id': postId,
      }).toList();

      await client.from('notifications').insert(notifications);
    } catch (e) {
      debugPrint("Notify Followers Error: $e");
    }
  }

  // Storage & Inserts
  static Future<String> uploadImage(String filePath, String bucket, String pathName) async {
    await client.storage.from(bucket).upload(pathName, File(filePath));
    return client.storage.from(bucket).getPublicUrl(pathName);
  }

  static Future<void> createPost(String imagePath, String caption, {List<dynamic>? objectsJson, Map<String, dynamic>? deepfakeResult}) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${currentUser!.id}.jpg';
    final imageUrl = await uploadImage(imagePath, 'posts', fileName);

    final response = await client.from('posts').insert({
      'user_id': currentUser!.id,
      'image_url': imageUrl,
      'caption': caption,
      if (objectsJson != null) 'objects_json': objectsJson,
      if (deepfakeResult != null) 'deepfake_result': deepfakeResult,
    }).select().single();

    await _notifyFollowers(type: 'post', postId: response['id'].toString());
  }

  static Future<void> deletePost(dynamic postId) async {
    await client.from('posts').delete().eq('id', postId).eq('user_id', currentUser!.id);
  }

  static Future<void> updatePost(dynamic postId, String caption) async {
    await client.from('posts').update({'caption': caption}).eq('id', postId).eq('user_id', currentUser!.id);
  }

  static Future<void> upsertReaction(dynamic postId, String reactionType) async {
    try {
      final myId = currentUser!.id;
      // Step 1: Remove any existing reaction
      await client.from('reactions').delete().eq('post_id', postId).eq('user_id', myId);
      
      // Step 2: Insert the new reaction
      // Note: If this fails with "sender_username" error, it means your Supabase 
      // database has a broken Trigger on the 'reactions' table.
      await client.from('reactions').insert({
        'post_id': postId,
        'user_id': myId,
        'reaction_type': reactionType,
      });
      
      // Step 3: Notify post owner (Optional/Manual)
      // We wrap this in a separate try-catch so it doesn't break the reaction itself
      try {
        final post = await client.from('posts').select('user_id').eq('id', postId).maybeSingle();
        if (post != null) {
          await _createNotification(receiverId: post['user_id'], type: 'like', postId: postId);
        }
      } catch (notifyError) {
        debugPrint("Notification failed but reaction saved: $notifyError");
      }
    } catch (e) {
      debugPrint("UPSERT REACTION ERROR: $e");
      // We don't rethrow here so the UI can at least try to stay in sync
    }
  }

  static Future<void> removeReaction(dynamic postId) async {
    await client.from('reactions').delete().eq('post_id', postId).eq('user_id', currentUser!.id);
  }

  static Stream<List<Map<String, dynamic>>> streamReactions(String postId) {
    return client
        .from('reactions')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true);
  }

  // Comments
  static Stream<List<Map<String, dynamic>>> streamComments(String postId) {
    return client
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true);
  }

  static Future<void> addComment(dynamic postId, String text) async {
    await client.from('comments').insert({
      'post_id': postId,
      'user_id': currentUser!.id,
      'content': text,
    });

    // Fetch post owner to notify
    final post = await client.from('posts').select('user_id').eq('id', postId).single();
    await _createNotification(receiverId: post['user_id'], type: 'comment', postId: postId);
  }

  static Future<void> deleteComment(String commentId) async {
    await client.from('comments').delete().eq('id', commentId).eq('user_id', currentUser!.id);
  }

  static Stream<List<Map<String, dynamic>>> streamSuggestedUsers() {
    return client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .limit(10);
  }

  static Future<void> sendMessage(String receiverId, String text) async {
    await client.from('messages').insert({
      'sender_id': currentUser!.id,
      'receiver_id': receiverId,
      'text': text,
    });
    await _createNotification(receiverId: receiverId, type: 'message');
  }

  static Future<void> deleteMessage(dynamic messageId) async {
    await client.from('messages').delete().eq('id', messageId).eq('sender_id', currentUser!.id);
  }

  static Future<void> deleteConversation(String otherUserId) async {
    final myId = currentUser!.id;
    await client.from('messages').delete().or('and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)');
  }

  // Stories
  static Stream<List<Map<String, dynamic>>> streamStories() {
    return client
        .from('stories_with_profiles')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  static Future<void> createStory({String? imagePath, String? content, String? bgColor}) async {
    String? imageUrl;
    if (imagePath != null) {
      final fileName = 'story_${DateTime.now().millisecondsSinceEpoch}_${currentUser!.id}.jpg';
      imageUrl = await uploadImage(imagePath, 'stories', fileName);
    }

    final response = await client.from('stories').insert({
      'user_id': currentUser!.id,
      'image_url': imageUrl,
      'content': content,
      'bg_color': bgColor,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    }).select().single();

    await _notifyFollowers(type: 'story', postId: response['id'].toString());
  }

  static Future<void> deleteStory(String storyId) async {
    await client.from('stories').delete().eq('id', storyId).eq('user_id', currentUser!.id);
  }

  static Future<Map<String, dynamic>> fetchProfile(String userId) async {
    return await client.from('profiles').select().eq('id', userId).single();
  }
}
