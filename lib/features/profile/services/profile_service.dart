import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_media_app/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final _picker = ImagePicker();

  /// Pick an image from gallery or camera, crop it, then upload to Supabase
  /// Storage and update the user's profile_url in the DB.
  /// Returns the new public URL or null on failure/cancel.
  static Future<String?> pickCropAndUploadAvatar(BuildContext context) async {
    // 1. Pick
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;

    // 2. Crop (Skip on desktop platforms since image_cropper doesn't support them)
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final Uint8List fileBytes;

    if (isDesktop) {
      fileBytes = await picked.readAsBytes();
    } else {
      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (cropped == null) return null;
      fileBytes = await cropped.readAsBytes();
    }

    final user = SupabaseService.currentUser;
    if (user == null) return null;

    final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    const bucketName = 'avatars';

    try {
      // Remove old avatar if it exists
      try {
        final oldProfile = await SupabaseService.client
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .single();
        final oldUrl = oldProfile['avatar_url'] as String?;
        if (oldUrl != null && oldUrl.contains(bucketName)) {
          final oldPath = oldUrl.split('$bucketName/').last;
          await SupabaseService.client.storage
              .from(bucketName)
              .remove([oldPath]);
        }
      } catch (_) {
        // Ignore if old avatar doesn't exist
      }

      // Upload new avatar
      await SupabaseService.client.storage
          .from(bucketName)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = SupabaseService.client.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      // 4. Update the profiles table
      await SupabaseService.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      return publicUrl;
    } catch (e) {
      debugPrint('AVATAR UPLOAD ERROR: $e');
      return null;
    }
  }
}
