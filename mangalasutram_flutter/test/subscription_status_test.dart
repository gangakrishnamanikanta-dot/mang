import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/features/subscription/models/subscription_status.dart';

void main() {
  group('SubscriptionStatus & Tier Unit Tests', () {
    test('SubscriptionTier string parsing works across cases and aliases', () {
      expect(SubscriptionTier.fromString('free'), SubscriptionTier.free);
      expect(SubscriptionTier.fromString('FREE'), SubscriptionTier.free);
      expect(SubscriptionTier.fromString('prime_lite'), SubscriptionTier.primeLite);
      expect(SubscriptionTier.fromString('PrimeLite'), SubscriptionTier.primeLite);
      expect(SubscriptionTier.fromString('prime'), SubscriptionTier.prime);
      expect(SubscriptionTier.fromString('prime_vip'), SubscriptionTier.prime);
      expect(SubscriptionTier.fromString(null), SubscriptionTier.free);
      expect(SubscriptionTier.fromString('unknown_tier'), SubscriptionTier.free);
    });

    test('SubscriptionTier dbValue and displayName mappings', () {
      expect(SubscriptionTier.free.dbValue, 'free');
      expect(SubscriptionTier.free.displayName, 'Free');

      expect(SubscriptionTier.primeLite.dbValue, 'prime_lite');
      expect(SubscriptionTier.primeLite.displayName, 'Prime Lite');

      expect(SubscriptionTier.prime.dbValue, 'prime');
      expect(SubscriptionTier.prime.displayName, 'Prime VIP');
    });

    test('SubscriptionStatus defaultFree factory initializes with correct limits', () {
      final freeStatus = SubscriptionStatus.defaultFree('user-101');
      expect(freeStatus.userId, 'user-101');
      expect(freeStatus.tier, SubscriptionTier.free);
      expect(freeStatus.isFree, isTrue);
      expect(freeStatus.isPaid, isFalse);
      expect(freeStatus.maxDailyInterests, 5);
      expect(freeStatus.remainingDailyInterests, 5);
      expect(freeStatus.contactsUnlockedLimit, 0);
      expect(freeStatus.remainingContacts, 0);
    });

    test('SubscriptionStatus json parsing correctly captures paid quota attributes', () {
      final json = {
        'user_id': 'user-202',
        'tier': 'prime_lite',
        'interests_sent_today': 3,
        'max_daily_interests': 15,
        'remaining_daily_interests': 12,
        'contacts_unlocked_count': 5,
        'contacts_unlocked_limit': 25,
        'remaining_contacts': 20,
        'expires_at': '2026-09-28T00:00:00.000Z',
      };

      final status = SubscriptionStatus.fromJson(json);
      expect(status.userId, 'user-202');
      expect(status.tier, SubscriptionTier.primeLite);
      expect(status.isPrimeLite, isTrue);
      expect(status.isPaid, isTrue);
      expect(status.interestsSentToday, 3);
      expect(status.maxDailyInterests, 15);
      expect(status.remainingDailyInterests, 12);
      expect(status.contactsUnlockedCount, 5);
      expect(status.contactsUnlockedLimit, 25);
      expect(status.remainingContacts, 20);
      expect(status.expiresAt, isNotNull);
    });
  });
}
