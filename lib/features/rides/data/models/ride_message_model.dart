import '../../../auth/data/models/user_model.dart';

/// A single chat message on a ride (client ↔ driver).
class RideMessage {
  const RideMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.createdAt,
    this.isMine = false,
    this.readAt,
    this.pending = false,
    this.failed = false,
  });

  final int id;
  final int rideId;
  final int senderId;
  final String senderName;
  final UserRole senderRole;
  final String body;
  final DateTime createdAt;
  final bool isMine;
  final DateTime? readAt;

  /// Optimistic local echo: shown immediately, not yet confirmed by the server.
  final bool pending;
  final bool failed;

  bool get isRead => readAt != null;

  factory RideMessage.fromJson(Map<String, dynamic> j, {int? currentUserId}) {
    final senderId = int.tryParse('${j['sender']}') ?? 0;
    final mine = j['is_mine'] is bool
        ? j['is_mine'] as bool
        : (currentUserId != null && senderId == currentUserId);
    return RideMessage(
      id: int.tryParse('${j['id']}') ?? 0,
      // REST returns `ride`, the WebSocket payload returns `ride_id`.
      rideId: int.tryParse('${j['ride'] ?? j['ride_id']}') ?? 0,
      senderId: senderId,
      senderName: '${j['sender_name'] ?? ''}',
      senderRole: UserRole.parse(j['sender_role']),
      body: '${j['body'] ?? ''}',
      isMine: mine,
      readAt: DateTime.tryParse('${j['read_at']}')?.toLocal(),
      createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }

  RideMessage copyWith({DateTime? readAt, bool? pending, bool? failed, int? id}) => RideMessage(
    id: id ?? this.id,
    rideId: rideId,
    senderId: senderId,
    senderName: senderName,
    senderRole: senderRole,
    body: body,
    createdAt: createdAt,
    isMine: isMine,
    readAt: readAt ?? this.readAt,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
  );
}
