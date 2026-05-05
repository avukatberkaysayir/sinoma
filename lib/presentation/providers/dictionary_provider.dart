import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dictionary_repository.dart';
import '../../data/services/cache_service.dart';

// Overridden in main.dart after Hive is initialized.
final cacheServiceProvider = Provider<CacheService>(
  (_) => throw UnimplementedError('cacheServiceProvider not initialized'),
);

final dictionaryRepositoryProvider = Provider<DictionaryRepository>((ref) {
  return DictionaryRepository(cache: ref.read(cacheServiceProvider));
});
