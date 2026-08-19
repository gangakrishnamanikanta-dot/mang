import 'profile.dart';

class Interest {
  final String id;
  final String senderProfileId;
  final String receiverProfileId;
  final String status;
  final DateTime createdAt;
  final Profile?
  otherProfile; // Injected based on context (sender if received view, receiver if sent view)

  Interest({
    required this.id,
    required this.senderProfileId,
    required this.receiverProfileId,
    required this.status,
    required this.createdAt,
    this.otherProfile,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  bool isSentByMe(String currentUserId) => senderProfileId == currentUserId;

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id: json['id'],
      senderProfileId: json['sender_profile_id'],
      receiverProfileId: json['receiver_profile_id'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      // `profiles` alias will be used in the join query
      otherProfile: json['profiles'] != null
          ? Profile.fromJson(json['profiles'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_profile_id': senderProfileId,
      'receiver_profile_id': receiverProfileId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
