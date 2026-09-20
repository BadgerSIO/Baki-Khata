import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';
import 'core/supabase_client.dart';
import 'data/local/local_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // OAuth redirects on Flutter web require path URLs instead of hash URLs.
  usePathUrlStrategy();

  // 1. Initialize Supabase
  await SupabaseConfig.initialize();

  // 2. Initialize Local Database
  await LocalDatabase.instance.initialize();

  runApp(
    const ProviderScope(
      child: BakiKhataApp(),
    ),
  );
}
