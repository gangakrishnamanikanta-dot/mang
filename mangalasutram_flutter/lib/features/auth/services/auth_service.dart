import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../config/env.dart';
import '../../../models/profile.dart';
import 'supabase_service.dart';

class AuthService {
  late final GoogleSignIn _googleSignIn;

  AuthService() {
    _googleSignIn = GoogleSignIn(
      clientId: Env.googleIosClientId,
      serverClientId: Env.googleWebClientId,
    );
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Ignore disconnect failure if user wasn't signed in via Google
    }
    await SupabaseService.client.auth.signOut();
  }

  Future<Profile?> getCurrentProfile() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 10));
      return Profile.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw const AppAuthException(
        'Google Sign-In failed: No ID token received.',
      );
    }

    try {
      final response = await SupabaseService.client.auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          )
          .timeout(const Duration(seconds: 15));

      if (response.user != null) {
        await SupabaseService.client
            .from('profiles')
            .upsert(
              {
                'id': response.user!.id,
                'email': response.user!.email ?? '',
                'full_name': googleUser.displayName ?? '',
                'profile_photo_url': googleUser.photoUrl,
              },
              onConflict: 'id',
            )
            .timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
