import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';

class CreditService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<int> spendOneCredit() async {
    try {
      final result = await _db.rpc('decrement_ai_credits');
      return (result as num).toInt();
    } on PostgrestException catch (e) {
      // P0001 = RAISE EXCEPTION from the stored procedure (quota exceeded)
      if (e.code == 'P0001') throw const AiQuotaExceededException();
      throw DatabaseException(e.code ?? 'unknown', e.message);
    }
  }

  Future<int> grantCreditsFromAd({int amount = 10}) async {
    try {
      final result =
          await _db.rpc('grant_ai_credits', params: {'p_amount': amount});
      return (result as num).toInt();
    } on PostgrestException catch (e) {
      throw DatabaseException(e.code ?? 'unknown', e.message);
    }
  }
}
