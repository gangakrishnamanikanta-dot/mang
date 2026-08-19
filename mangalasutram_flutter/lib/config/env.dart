import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';

  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  static String get googleIosClientId =>
      dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

  static void validate() {
    final missing = <String>[];
    if (dotenv.env['SUPABASE_URL'] == null || dotenv.env['SUPABASE_URL']!.isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if (dotenv.env['SUPABASE_PUBLISHABLE_KEY'] == null || dotenv.env['SUPABASE_PUBLISHABLE_KEY']!.isEmpty) {
      missing.add('SUPABASE_PUBLISHABLE_KEY');
    }
    if (missing.isNotEmpty) {
      throw StateError('Missing required environment variables: ${missing.join(", ")}');
    }
  }
}
