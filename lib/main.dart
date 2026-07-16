import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/services/cache_service.dart';
import 'data/services/remote_config_service.dart';
import 'presentation/providers/ai_provider.dart';
import 'presentation/providers/dictionary_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'supabase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Supabase.initialize(
    url: SupabaseOptions.url,
    anonKey: SupabaseOptions.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await CacheService.initialize();
  final cache = CacheService();
  // openBoxes uses IndexedDB — can hang if another tab holds a lock.
  // 4-second timeout + catch ensures app always reaches runApp().
  try {
    await cache.openBoxes().timeout(const Duration(seconds: 4));
  } catch (_) {
    // Cache unavailable — app runs fine without it (network fallback).
  }

  final remoteConfig = RemoteConfigService();
  await remoteConfig.initialize();

  final prefs = await SharedPreferences.getInstance();
  final savedCode = prefs.getString('app_locale');
  // A language the visitor picked (or restored with their account) always wins.
  // Otherwise open in the language of the country they're browsing from —
  // English when we don't ship theirs. Only first-time visitors pay the lookup.
  final initialLocale = savedCode != null && kSupportedUiLanguages.contains(savedCode)
      ? Locale(savedCode)
      : Locale(await languageFromGeo());

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => LocaleNotifier(initialLocale)),
        cacheServiceProvider.overrideWithValue(cache),
        remoteConfigProvider.overrideWithValue(remoteConfig),
      ],
      child: const SinomaApp(),
    ),
  );
}
