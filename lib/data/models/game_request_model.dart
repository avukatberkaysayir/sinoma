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

  factory GameRequestModel.fromMap(Map<String, dynamic> data) =>
      GameRequestModel(
        requestId: data['id'] as String? ?? '',
        fromUid: data['from_uid'] as String? ?? '',
        toUid: data['to_uid'] as String? ?? '',
        hskLevel: (data['hsk_level'] as num?)?.toInt() ?? 1,
        status: _parseStatus(data['status'] as String?),
        createdAt: data['created_at'] != null
            ? DateTime.parse(data['created_at'] as String)
            : DateTime.now(),
      );

  static GameRequestStatus _parseStatus(String? value) => switch (value) {
        'accepted' => GameRequestStatus.accepted,
        'declined' => GameRequestStatus.declined,
        'expired' => GameRequestStatus.expired,
        _ => GameRequestStatus.pending,
      };

  Map<String, dynamic> toMap() => {
        'id': requestId,
        'from_uid': fromUid,
        'to_uid': toUid,
        'hsk_level': hskLevel,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
      };
}
