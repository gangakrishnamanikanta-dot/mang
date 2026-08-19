import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/env.dart';

class SupabaseService {
  static Future<void> initialize() async {
    Env.validate();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabasePublishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
