import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception('SUPABASE_URL e SUPABASE_ANON_KEY devem ser configuradas via --dart-define');
    }
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
