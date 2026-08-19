import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../models/profile.dart';
import '../../auth/services/supabase_service.dart';
import '../../../models/partner_preference.dart';
import '../../home/services/home_service.dart';

/// ProfileService — Handles all profile CRUD and photo upload operations.
/// All writes are protected by Supabase Row Level Security (RLS).
/// Users can only read/write their own profile rows.
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final SupabaseClient _client = SupabaseService.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppAuthException('User is not authenticated.');
    }
    return user.id;
  }

  // ── FETCH ──────────────────────────────────────────────────────────────────

  /// Fetches the current user's full profile from Supabase.
  Future<Profile?> getProfile() async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', _userId)
          .maybeSingle();
      if (data == null) return null;
      return Profile.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── UPSERT (Create or Update) ─────────────────────────────────────────────

  /// Saves the full 7-step profile builder data.
  /// Upserts to avoid creating duplicates.
  /// This is called when the user taps "Complete Profile" on Step 7.
  Future<Profile> saveProfile(Map<String, dynamic> formData) async {
    final payload = _sanitizePayload(formData);
    payload['id'] = _userId;

    final data = await _client
        .from('profiles')
        .upsert(payload)
        .select()
        .single();

    return Profile.fromJson(data);
  }

  /// Saves the partner preferences to the partner_preferences table.
  Future<PartnerPreference?> getPartnerPreferences() async {
    try {
      final response = await _client
          .from('partner_preferences')
          .select()
          .eq('profile_id', _userId)
          .maybeSingle();
      if (response != null) {
        return PartnerPreference.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting partner preferences: $e');
      return null;
    }
  }

  /// Saves the partner preferences to the partner_preferences table.
  Future<void> savePartnerPreferences(PartnerPreference prefs) async {
    final payload = prefs.toJson();
    
    // Explicitly add nulls for missing lists so they are cleared in the DB
    if (!payload.containsKey('preferred_marital_status_ids')) payload['preferred_marital_status_ids'] = null;
    if (!payload.containsKey('preferred_mother_tongue_ids')) payload['preferred_mother_tongue_ids'] = null;
    if (!payload.containsKey('preferred_caste_ids')) payload['preferred_caste_ids'] = null;
    if (!payload.containsKey('preferred_food_ids')) payload['preferred_food_ids'] = null;
    if (!payload.containsKey('preferred_education_ids')) payload['preferred_education_ids'] = null;
    if (!payload.containsKey('preferred_occupation_ids')) payload['preferred_occupation_ids'] = null;
    if (!payload.containsKey('preferred_family_type_ids')) payload['preferred_family_type_ids'] = null;
    if (!payload.containsKey('preferred_smoking_ids')) payload['preferred_smoking_ids'] = null;
    if (!payload.containsKey('preferred_drinking_ids')) payload['preferred_drinking_ids'] = null;
    
    payload['profile_id'] = _userId;

    await _client
        .from('partner_preferences')
        .upsert(payload, onConflict: 'profile_id');
        
    // Notify that matches need to be re-fetched globally.
    HomeService.instance.notifyMatchesChanged();
  }

  /// Updates a partial set of profile fields.
  /// Used by Edit Profile screen to save individual sections.
  Future<Profile> updateProfileFields(Map<String, dynamic> fields) async {
    final data = await _client
        .from('profiles')
        .update(_sanitizePayload(fields))
        .eq('id', _userId)
        .select()
        .single();

    return Profile.fromJson(data);
  }

  // ── PHOTO UPLOAD ───────────────────────────────────────────────────────────

  /// Picks a photo from gallery and uploads it to Supabase Storage.
  /// Returns the public URL of the uploaded photo, or null if cancelled.
  Future<String?> pickAndUploadProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return null;

      final file = File(image.path);

      // Enforce 3MB size limit
      final fileSize = await file.length();
      if (fileSize > 3 * 1024 * 1024) {
        throw const ValidationException('Image size exceeds 3MB limit.');
      }

      final fileExt = image.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$_userId/avatar_$timestamp.$fileExt';

      await _client.storage
          .from('profile_photos')
          .upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          )
          .timeout(const Duration(seconds: 15));

      final baseUrl = _client.storage
          .from('profile_photos')
          .getPublicUrl(fileName);
      final publicUrl = '$baseUrl?t=$timestamp';

      try {
        // Save the URL back to the profile row
        await _client
            .from('profiles')
            .update({'profile_photo_url': publicUrl})
            .eq('id', _userId)
            .timeout(const Duration(seconds: 10));
      } catch (dbError) {
        // Rollback storage upload
        try {
          await _client.storage.from('profile_photos').remove([fileName]);
        } catch (cleanupError) {
          debugPrint('[ProfileService] Rollback cleanup failed: $cleanupError');
        }
        throw AppException.from(dbError);
      }

      return publicUrl;
    } catch (e) {
      debugPrint('[ProfileService] pickAndUploadProfilePhoto failed: $e');
      throw AppException.from(e);
    }
  }

  /// Picks an additional photo from gallery and uploads it to Supabase Storage.
  /// Returns the public URL of the uploaded photo, or null if cancelled.
  Future<String?> pickAndUploadAdditionalPhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return null;

      final file = File(image.path);

      // Enforce 3MB size limit
      final fileSize = await file.length();
      if (fileSize > 3 * 1024 * 1024) {
        throw const ValidationException('Image size exceeds 3MB limit.');
      }

      final fileExt = image.path.split('.').last.toLowerCase();
      // Use timestamp to ensure unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$_userId/photo_$timestamp.$fileExt';

      await _client.storage
          .from('profile_photos')
          .upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl = _client.storage
          .from('profile_photos')
          .getPublicUrl(fileName);

      // We do not save to profiles row here, as it will be saved via _formData on submit
      return publicUrl;
    } catch (e) {
      debugPrint('[ProfileService] pickAndUploadAdditionalPhoto failed: $e');
      throw AppException.from(e);
    }
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  /// Removes null/empty values to avoid overwriting existing data with blanks.
  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) {
        if (value is String && value.trim().isEmpty) return;

        // Supabase requires YYYY-MM-DD for date columns.
        if (key == 'date_of_birth' && value is String && value.contains('/')) {
          final parts = value.split('/');
          if (parts.length == 3) {
            // Assuming DD/MM/YYYY
            final day = parts[0].padLeft(2, '0');
            final month = parts[1].padLeft(2, '0');
            final year = parts[2];
            cleaned[key] = '$year-$month-$day';
            return;
          }
        }

        cleaned[key] = value;
      }
    });
    return cleaned;
  }
}
