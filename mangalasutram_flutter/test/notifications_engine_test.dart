import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/features/notifications/models/notification_item.dart';

void main() {
  group('Notifications Engine Model & Category Integrity Tests', () {
    test('NotificationCategory accurately parses all lifecycle strings', () {
      expect(
        NotificationCategory.fromString('interest_received'),
        NotificationCategory.interestReceived,
      );
      expect(
        NotificationCategory.fromString('interest_accepted'),
        NotificationCategory.interestAccepted,
      );
      expect(
        NotificationCategory.fromString('interest_declined'),
        NotificationCategory.interestDeclined,
      );
      expect(
        NotificationCategory.fromString('chat_message'),
        NotificationCategory.chatMessage,
      );
      expect(
        NotificationCategory.fromString('high_guna_milan'),
        NotificationCategory.highGunaMilan,
      );
      expect(
        NotificationCategory.fromString('profile_visit'),
        NotificationCategory.profileVisit,
      );
      expect(
        NotificationCategory.fromString('unknown_event_type'),
        NotificationCategory.system,
      );
    });

    test('NotificationCategory enforces luxury Vedic design palette', () {
      expect(
        NotificationCategory.interestReceived.iconColor,
        const Color(0xFF6E1732), // Deep Royal Burgundy
      );
      expect(
        NotificationCategory.interestAccepted.iconColor,
        const Color(0xFFC99A4B), // Temple Gold
      );
      expect(
        NotificationCategory.highGunaMilan.iconColor,
        const Color(0xFFC99A4B), // Temple Gold
      );
    });

    test('NotificationItem properly deserializes from Supabase trigger payload', () {
      final json = {
        'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        'user_id': 'u1u2u3u4-u5u6-u7u8-u9u0-u1u2u3u4u5u6',
        'type': 'interest_received',
        'title': 'New Sacred Interest',
        'body': 'Priya Sharma has expressed sacred interest in your profile.',
        'payload': {
          'sender_id': 's1s2s3s4-s5s6-s7s8-s9s0-s1s2s3s4s5s6',
          'interest_id': 'i1i2i3i4-i5i6-i7i8-i9i0-i1i2i3i4i5i6',
        },
        'is_read': false,
        'read_at': null,
        'is_dismissed': false,
        'dismissed_at': null,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
      expect(item.category, NotificationCategory.interestReceived);
      expect(item.title, 'New Sacred Interest');
      expect(item.body, contains('Priya Sharma'));
      expect(item.isRead, isFalse);
      expect(item.payload['sender_id'], 's1s2s3s4-s5s6-s7s8-s9s0-s1s2s3s4s5s6');
    });

    test('NotificationItem copyWith immutability works correctly', () {
      final original = NotificationItem(
        id: '1',
        userId: 'u1',
        category: NotificationCategory.chatMessage,
        rawType: 'chat_message',
        title: 'New Message',
        body: 'Hello',
        payload: const {},
        isRead: false,
        isDismissed: false,
        createdAt: DateTime.now(),
      );

      final read = original.copyWith(isRead: true, readAt: DateTime.now());
      expect(read.isRead, isTrue);
      expect(read.readAt, isNotNull);
      expect(original.isRead, isFalse); // Immutable
    });
  });
}
