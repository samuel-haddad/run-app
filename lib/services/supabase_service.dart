import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static String get url => dotenv.get('SUPABASE_URL');
  static String get anonKey => dotenv.get('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    final url = dotenv.maybeGet('SUPABASE_URL');
    final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');

    if (url == null || anonKey == null) {
      throw Exception('SUPABASE_URL e SUPABASE_ANON_KEY devem estar no arquivo .env');
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
