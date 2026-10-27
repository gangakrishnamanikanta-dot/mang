import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/features/profile/services/moderation_service.dart';
import 'package:mangalasutram/features/profile/widgets/safety_action_sheet.dart';

void main() {
  group('Moderation & Safety Suite Unit Tests', () {
    test('BlockedUser model parses JSON correctly', () {
      final json = {
        'id': 'user-123',
        'full_name': 'Sowmya Iyer',
        'city': 'Chennai',
        'state': 'Tamil Nadu',
        'profile_photo_url': 'https://example.com/photo.jpg',
        'blocked_at': '2026-09-14T12:00:00Z',
      };

      final blockedUser = BlockedUser.fromJson(json);

      expect(blockedUser.id, 'user-123');
      expect(blockedUser.fullName, 'Sowmya Iyer');
      expect(blockedUser.city, 'Chennai');
      expect(blockedUser.state, 'Tamil Nadu');
      expect(blockedUser.profilePhotoUrl, 'https://example.com/photo.jpg');
      expect(blockedUser.blockedAt.isUtc, isTrue);
    });

    test('BlockedUser model handles null optional fields gracefully', () {
      final json = {
        'id': 'user-456',
        'full_name': null,
        'city': null,
        'state': null,
        'profile_photo_url': null,
        'blocked_at': null,
      };

      final blockedUser = BlockedUser.fromJson(json);

      expect(blockedUser.id, 'user-456');
      expect(blockedUser.fullName, 'Member');
      expect(blockedUser.city, isNull);
      expect(blockedUser.state, isNull);
      expect(blockedUser.profilePhotoUrl, isNull);
      expect(blockedUser.blockedAt, isNotNull);
    });
  });

  group('SafetyActionSheet Widget Tests', () {
    testWidgets('Renders Trust & Safety options for the target member', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafetyActionSheet(
              profileId: 'candidate-999',
              fullName: 'Ananya Sharma',
            ),
          ),
        ),
      );

      expect(find.text('Trust & Safety'), findsOneWidget);
      expect(find.text('Options for Ananya Sharma'), findsOneWidget);
      expect(find.text('Report Member'), findsOneWidget);
      expect(find.text('Block Ananya Sharma'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    });
  });
}
