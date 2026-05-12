import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/services/cache_service.dart';
import 'data/services/remote_config_service.dart';
import 'presentation/providers/ai_provider.dart';
import 'presentation/providers/dictionary_provider.dart';
import 'supabase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Supabase.initialize(
    url: SupabaseOptions.url,
    anonKey: SupabaseOptions.anonKey,
  );

  await CacheService.initialize();
  final cache = CacheService();
  await cache.openBoxes();

  final remoteConfig = RemoteConfigService();
  await remoteConfig.initialize();

  runApp(
    ProviderScope(
      overrides: [
        cacheServiceProvider.overrideWithValue(cache),
        remoteConfigProvider.overrideWithValue(remoteConfig),
      ],
      child: const SinomaApp(),
    ),
  );
}
