import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../models/app_settings.dart';

class SettingsRemoteSource {
  final SupabaseClient _client;

  SettingsRemoteSource({SupabaseClient? client}) : _client = client ?? supabase;

  Future<AppSettings?> fetchSettings(String userId) async {
    final response = await _client
        .from('settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return AppSettings.fromJson(response);
  }

  Future<AppSettings> upsertSettings(AppSettings settings) async {
    final response = await _client
        .from('settings')
        .upsert(settings.toJson())
        .select()
        .single();

    return AppSettings.fromJson(response);
  }
}
