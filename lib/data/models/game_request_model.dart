import 'package:cloud_firestore/cloud_firestore.dart';

enum GameRequestStatus { pending, accepted, declined, expired }

class GameRequestModel {
  final String requestId;
  final String fromUid;
  final String toUid;
  final int hskLevel;
  final GameRequestStatus status;
  final DateTime createdAt;

  const GameRequestModel({
    required this.requestId,
    required this.fromUid,
    required this.toUid,
    required this.hskLevel,
    required this.status,
    required this.createdAt,
  });

  factory GameRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameRequestModel(
      requestId: doc.id,
      fromUid: data['fromUid'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      hskLevel: (data['hskLevel'] as num?)?.toInt() ?? 1,
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static GameRequestStatus _parseStatus(String? value) => switch (value) {
        'accepted' => GameRequestStatus.accepted,
        'declined' => GameRequestStatus.declined,
        'expired' => GameRequestStatus.expired,
        _ => GameRequestStatus.pending,
      };

  Map<String, dynamic> toFirestore() => {
        'fromUid': fromUid,
        'toUid': toUid,
        'hskLevel': hskLevel,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
