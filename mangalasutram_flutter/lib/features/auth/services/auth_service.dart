import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../config/env.dart';
import '../../../models/profile.dart';
import 'supabase_service.dart';

import '../../../core/di.dart';
import '../../notifications/services/fcm_messaging_service.dart';
import '../../home/services/home_service.dart';
import '../../subscription/services/subscription_service.dart';
import '../../messaging/services/e2ee_crypto_service.dart';

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
    try {
      final unlinked = await getIt<FcmMessagingService>().handleSignOut();
      if (!unlinked) {
        debugPrint('[AuthService] FCM device token was not unlinked on backend (offline or already cleared). Local token invalidated.');
      }
    } catch (e) {
      debugPrint('[AuthService] Error during FCM handleSignOut: $e');
    }
    // MNC-Grade: wipe all sensitive in-memory state & subscriptions
    try {
      HomeService.instance.invalidateCache();
    } catch (_) {}
    try {
      SubscriptionService.instance.reset();
    } catch (_) {}
    try {
      getIt<E2eeCryptoService>().clearKeys();
    } catch (_) {}

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
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      if (data == null) return null;
      return Profile.fromJson(data);
    } catch (e) {
      debugPrint('[AuthService getCurrentProfile Error]: $e');
      return null;
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
        // Only insert if the profile doesn't exist to avoid overwriting custom data
        final existing = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('id', response.user!.id)
            .maybeSingle();

        if (existing == null) {
          await SupabaseService.client
              .from('profiles')
              .insert({
                'id': response.user!.id,
                'email': response.user!.email ?? '',
                'full_name': googleUser.displayName ?? '',
                'profile_photo_url': googleUser.photoUrl,
              })
              .timeout(const Duration(seconds: 10));
        }
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
