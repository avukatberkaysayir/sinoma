import 'package:cloud_functions/cloud_functions.dart';

import '../../core/errors/app_exception.dart';

class CreditService {
  final FirebaseFunctions _functions;

  CreditService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<int> spendOneCredit() async {
    try {
      final result = await _functions
          .httpsCallable('decrementAiCredits')
          .call<Map<String, dynamic>>();
      return (result.data['aiCredits'] as num).toInt();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') throw const AiQuotaExceededException();
      throw FirestoreException(e.code, e.message ?? 'Credit decrement failed.');
    }
  }

  Future<int> grantCreditsFromAd({int amount = 10}) async {
    try {
      final result = await _functions
          .httpsCallable('grantAiCredits')
          .call<Map<String, dynamic>>({'amount': amount});
      return (result.data['aiCredits'] as num).toInt();
    } on FirebaseFunctionsException catch (e) {
      throw FirestoreException(e.code, e.message ?? 'Credit grant failed.');
    }
  }
}
