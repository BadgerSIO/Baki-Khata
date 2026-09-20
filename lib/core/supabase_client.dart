import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gjtlkbgopdrzdafnpymh.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGxrYmdvcGRyemRhZm5weW1oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk2OTkwNjEsImV4cCI6MjEwNTI3NTA2MX0.OQDd2VLg7ditVs1qzSzme3JrmL9Garm5CRbSMal4YbI',
  );

  static Future<void> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration!\n'
        'Both SUPABASE_URL and SUPABASE_ANON_KEY must be provided via --dart-define flags.\n'
        'Example:\n'
        'flutter run --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon-key>',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey, // ignore: deprecated_member_use
    );
  }

  static SupabaseClient get client {
    return Supabase.instance.client;
  }
}

SupabaseClient get supabase => SupabaseConfig.client;
