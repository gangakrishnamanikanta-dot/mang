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

  static const Set<String> _allowedProfileColumns = {
    'id',
    'phone',
    'email',
    'full_name',
    'gender',
    'date_of_birth',
    'height_inches',
    'marital_status_id',
    'mother_tongue_id',
    'caste_id',
    'sub_caste',
    'gothram_id',
    'pravara',
    'veda_shakha_id',
    'nakshatra_id',
    'rashi_id',
    'pada_id',
    'time_of_birth',
    'place_of_birth',
    'is_manglik',
    'horoscope_url',
    'highest_education_id',
    'college',
    'occupation_id',
    'company',
    'annual_income_id',
    'work_location',
    'father_name',
    'father_occupation',
    'mother_name',
    'mother_occupation',
    'family_type_id',
    'native_place',
    'brothers_count',
    'sisters_count',
    'food_preference_id',
    'smoking_id',
    'drinking_id',
    'hobbies',
    'about_me',
    'profile_photo_url',
    'additional_photo_urls',
    'hide_mobile',
    'hide_email',
    'show_horoscope',
    'profile_visibility_id',
    'terms_accepted',
    'created_for',
    'welcome_email_sent',
    'country_id',
    'state_id',
    'city_id',
    'citizenship_id',
    'state',
    'city',
    'is_verified',
    'kuja_dosham',
    'last_active_at',
    'sampradayam',
    'kuladevata',
    'sandhyavandanam',
    'daily_pooja',
    'sloka_chanting',
    'temple_visits',
    'festival_participation',
    'work_type',
    'career_preference',
    'fitness_habits',
    'personality_type',
    'spiritual_level',
    'cultural_interests',
    'family_values',
    'family_description',
  };

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

  /// Fetches any candidate's public profile from Supabase by ID.
  /// Reads from public_profiles view — sensitive columns (phone, email,
  /// horoscope_url, family details) are excluded by design.
  Future<Profile?> getProfileById(String profileId) async {
    try {
      final data = await _client
          .from('public_profiles')
          .select()
          .eq('id', profileId)
          .maybeSingle();
      if (data == null) return null;
      return Profile.fromJson(data);
    } catch (e) {
      debugPrint('[ProfileService getProfileById Error]: $e');
      return null;
    }
  }

  // ── UPSERT (Create or Update) ─────────────────────────────────────────────

  /// Saves profile data (full onboarding or partial section edit).
  /// Upserts to avoid creating duplicates and refreshes the match cache.
  Future<Profile> saveProfile(
    Map<String, dynamic> formData, {
    bool allowNulls = true,
  }) async {
    final payload = _sanitizePayload(formData, allowNulls: allowNulls);
    payload['id'] = _userId;
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final data = await _client
        .from('profiles')
        .upsert(payload)
        .select()
        .single();

    // Invalidate local matching cache so recalculation happens immediately
    HomeService.instance.invalidateCache();
    try {
      await _client.rpc('refresh_user_match_cache', params: {
        'p_user_id': _userId,
        'p_force': true,
      });
    } catch (e) {
      debugPrint('[ProfileService saveProfile match refresh notice]: $e');
    }
    HomeService.instance.notifyMatchesChanged();

    return Profile.fromJson(data);
  }

  /// Gets the partner preferences for current user
  Future<PartnerPreference?> getPartnerPreferences() => getPartnerPreferencesByProfileId(_userId);

  /// Gets the partner preferences for any profile by ID.
  Future<PartnerPreference?> getPartnerPreferencesByProfileId(String profileId) async {
    try {
      final response = await _client
          .from('partner_preferences')
          .select()
          .eq('profile_id', profileId)
          .maybeSingle();
      if (response != null) {
        return PartnerPreference.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('[ProfileService getPartnerPreferencesByProfileId Error]: $e');
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
    if (!payload.containsKey('preferred_country_ids')) payload['preferred_country_ids'] = null;
    
    payload['profile_id'] = _userId;
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await _client
        .from('partner_preferences')
        .upsert(payload, onConflict: 'profile_id');

    HomeService.instance.invalidateCache();
    try {
      await _client.rpc(
        'refresh_user_match_cache',
        params: {
          'p_user_id': _userId,
          'p_force': true,
        },
      );
    } catch (_) {}

    // Notify that matches need to be re-fetched globally.
    HomeService.instance.notifyMatchesChanged();
  }

  /// Updates a partial set of profile fields.
  /// Used by Edit Profile screens to save individual sections and refresh match cache.
  Future<Profile> updateProfileFields(Map<String, dynamic> fields) async {
    final sanitized = _sanitizePayload(fields, allowNulls: true);
    sanitized['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final data = await _client
        .from('profiles')
        .update(sanitized)
        .eq('id', _userId)
        .select()
        .single();

    HomeService.instance.invalidateCache();
    try {
      await _client.rpc(
        'refresh_user_match_cache',
        params: {
          'p_user_id': _userId,
          'p_force': true,
        },
      );
    } catch (_) {}
    HomeService.instance.notifyMatchesChanged();

    return Profile.fromJson(data);
  }

  // ── PHOTO UPLOAD ───────────────────────────────────────────────────────────

  /// Picks a photo from gallery and uploads it to Supabase Storage.
  /// Picks a profile avatar from Camera or Gallery and uploads it to Supabase Storage.
  /// Returns the public URL of the uploaded photo, or null if cancelled.
  Future<String?> pickAndUploadProfilePhoto({ImageSource source = ImageSource.gallery}) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
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

  /// Picks an additional photo from Camera or Gallery and uploads it to Supabase Storage.
  /// Returns the public URL of the uploaded photo, or null if cancelled.
  Future<String?> pickAndUploadAdditionalPhoto({ImageSource source = ImageSource.gallery}) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
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

      return publicUrl;
    } catch (e) {
      debugPrint('[ProfileService] pickAndUploadAdditionalPhoto failed: $e');
      throw AppException.from(e);
    }
  }

  /// Deletes a photo from the Supabase Storage bucket.
  Future<void> deletePhoto(String photoUrl) async {
    try {
      final uri = Uri.parse(photoUrl);
      final pathSegments = uri.pathSegments;
      final bucketIdx = pathSegments.indexOf('profile_photos');
      if (bucketIdx != -1 && bucketIdx < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIdx + 1).join('/');
        await _client.storage.from('profile_photos').remove([filePath]);
      }
    } catch (e) {
      debugPrint('[ProfileService deletePhoto Error]: $e');
    }
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  static const Set<String> _nonNullableColumns = {
    'id',
    'is_verified',
    'account_type',
  };

  /// Sanitizes profile payloads before upserting/updating.
  /// When [allowNulls] is true (e.g. section edits), empty strings and explicit
  /// nulls on nullable columns are preserved as `null` so users can clear optional fields.
  Map<String, dynamic> _sanitizePayload(
    Map<String, dynamic> data, {
    bool allowNulls = false,
  }) {
    final cleaned = <String, dynamic>{};
    data.forEach((key, value) {
      if (!_allowedProfileColumns.contains(key)) return;
      if (value == null) {
        if (allowNulls && !_nonNullableColumns.contains(key)) {
          cleaned[key] = null;
        }
        return;
      }

      if (value is String && value.trim().isEmpty) {
        if (allowNulls && !_nonNullableColumns.contains(key)) {
          cleaned[key] = null;
        }
        return;
      }

      // Supabase requires valid YYYY-MM-DD for date columns.
      if (key == 'date_of_birth') {
        if (value is String) {
          String dob = value.trim();
          if (dob.contains('/')) {
            final parts = dob.split('/');
            if (parts.length == 3) {
              final day = parts[0].padLeft(2, '0');
              final month = parts[1].padLeft(2, '0');
              final year = parts[2];
              dob = '$year-$month-$day';
            }
          }
          final dobRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
          if (!dobRegex.hasMatch(dob)) {
            return; // omit invalid date format
          }
          cleaned[key] = dob;
          return;
        }
      }

      cleaned[key] = value;
    });
    return cleaned;
  }
}
