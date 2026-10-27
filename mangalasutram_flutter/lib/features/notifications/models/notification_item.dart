import 'package:flutter/material.dart';

/// Notification category types supported by Mangalasutram
enum NotificationCategory {
  interestReceived,
  interestAccepted,
  interestDeclined,
  chatMessage,
  highGunaMilan,
  profileVisit,
  quotaExhausted,
  contactLocked,
  pendingReminder,
  familyAction,
  promotionalOffer,
  system;

  static NotificationCategory fromString(String? type) {
    switch (type) {
      case 'interest_received':
        return NotificationCategory.interestReceived;
      case 'interest_accepted':
        return NotificationCategory.interestAccepted;
      case 'interest_declined':
        return NotificationCategory.interestDeclined;
      case 'chat_message':
        return NotificationCategory.chatMessage;
      case 'high_guna_milan':
        return NotificationCategory.highGunaMilan;
      case 'profile_visit':
        return NotificationCategory.profileVisit;
      case 'quota_exhausted':
        return NotificationCategory.quotaExhausted;
      case 'contact_locked':
        return NotificationCategory.contactLocked;
      case 'pending_reminder':
        return NotificationCategory.pendingReminder;
      case 'family_action':
        return NotificationCategory.familyAction;
      case 'promotional_offer':
        return NotificationCategory.promotionalOffer;
      case 'system':
      default:
        return NotificationCategory.system;
    }
  }

  String toDbString() {
    switch (this) {
      case NotificationCategory.interestReceived:
        return 'interest_received';
      case NotificationCategory.interestAccepted:
        return 'interest_accepted';
      case NotificationCategory.interestDeclined:
        return 'interest_declined';
      case NotificationCategory.chatMessage:
        return 'chat_message';
      case NotificationCategory.highGunaMilan:
        return 'high_guna_milan';
      case NotificationCategory.profileVisit:
        return 'profile_visit';
      case NotificationCategory.quotaExhausted:
        return 'quota_exhausted';
      case NotificationCategory.contactLocked:
        return 'contact_locked';
      case NotificationCategory.pendingReminder:
        return 'pending_reminder';
      case NotificationCategory.familyAction:
        return 'family_action';
      case NotificationCategory.promotionalOffer:
        return 'promotional_offer';
      case NotificationCategory.system:
        return 'system';
    }
  }

  /// Appropriate icon for Vedic Matrimonial notifications
  IconData get icon {
    switch (this) {
      case NotificationCategory.interestReceived:
        return Icons.favorite_rounded;
      case NotificationCategory.interestAccepted:
        return Icons.celebration_rounded;
      case NotificationCategory.interestDeclined:
        return Icons.heart_broken_outlined;
      case NotificationCategory.chatMessage:
        return Icons.chat_bubble_rounded;
      case NotificationCategory.highGunaMilan:
        return Icons.auto_awesome_rounded;
      case NotificationCategory.profileVisit:
        return Icons.visibility_rounded;
      case NotificationCategory.quotaExhausted:
        return Icons.hourglass_bottom_rounded;
      case NotificationCategory.contactLocked:
        return Icons.lock_outline_rounded;
      case NotificationCategory.pendingReminder:
        return Icons.alarm_rounded;
      case NotificationCategory.familyAction:
        return Icons.diversity_3_rounded;
      case NotificationCategory.promotionalOffer:
        return Icons.card_giftcard_rounded;
      case NotificationCategory.system:
        return Icons.info_outline_rounded;
    }
  }

  /// Color accents for the icon container adhering to the Vedic Luxury system
  Color get iconColor {
    switch (this) {
      case NotificationCategory.interestReceived:
      case NotificationCategory.chatMessage:
      case NotificationCategory.familyAction:
        return const Color(0xFF6E1732); // Deep Royal Burgundy
      case NotificationCategory.interestAccepted:
      case NotificationCategory.highGunaMilan:
      case NotificationCategory.promotionalOffer:
        return const Color(0xFFC99A4B); // Temple Gold
      case NotificationCategory.profileVisit:
        return const Color(0xFF9E2A4B); // Rose Burgundy
      case NotificationCategory.quotaExhausted:
      case NotificationCategory.contactLocked:
      case NotificationCategory.pendingReminder:
        return const Color(0xFFD97706); // Amber Warm Gold
      case NotificationCategory.interestDeclined:
      case NotificationCategory.system:
        return const Color(0xFF6B7280); // Muted Slate
    }
  }

  Color get iconBackgroundColor {
    switch (this) {
      case NotificationCategory.interestReceived:
      case NotificationCategory.chatMessage:
      case NotificationCategory.familyAction:
        return const Color(0xFFFBECEF);
      case NotificationCategory.interestAccepted:
      case NotificationCategory.highGunaMilan:
      case NotificationCategory.promotionalOffer:
        return const Color(0xFFFDF6E9);
      case NotificationCategory.profileVisit:
        return const Color(0xFFF9EAEF);
      case NotificationCategory.quotaExhausted:
      case NotificationCategory.contactLocked:
      case NotificationCategory.pendingReminder:
        return const Color(0xFFFEF3C7);
      case NotificationCategory.interestDeclined:
      case NotificationCategory.system:
        return const Color(0xFFF3F4F6);
    }
  }
}

/// Represents an in-app notification item fetched from public.notifications
class NotificationItem {
  final String id;
  final String userId;
  final NotificationCategory category;
  final String rawType;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime? readAt;
  final bool isDismissed;
  final DateTime? dismissedAt;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.category,
    required this.rawType,
    required this.title,
    required this.body,
    required this.payload,
    required this.isRead,
    this.readAt,
    required this.isDismissed,
    this.dismissedAt,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'system';
    return NotificationItem(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      category: NotificationCategory.fromString(typeStr),
      rawType: typeStr,
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      isDismissed: json['is_dismissed'] as bool? ?? false,
      dismissedAt: json['dismissed_at'] != null
          ? DateTime.tryParse(json['dismissed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': rawType,
      'title': title,
      'body': body,
      'payload': payload,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'is_dismissed': isDismissed,
      'dismissed_at': dismissedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationItem copyWith({
    String? id,
    String? userId,
    NotificationCategory? category,
    String? rawType,
    String? title,
    String? body,
    Map<String, dynamic>? payload,
    bool? isRead,
    DateTime? readAt,
    bool? isDismissed,
    DateTime? dismissedAt,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      rawType: rawType ?? this.rawType,
      title: title ?? this.title,
      body: body ?? this.body,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isDismissed: isDismissed ?? this.isDismissed,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Compact human-readable time ago formatter
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${createdAt.day} ${months[createdAt.month - 1]}';
    }
  }

  /// Safe route extractor from payload
  String? get targetRoute => payload['route'] as String?;

  /// Safe target ID extractor from payload
  String? get targetId => payload['id'] as String?;
}
