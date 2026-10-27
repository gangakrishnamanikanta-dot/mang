enum SubscriptionTier {
  free,
  primeLite,
  prime;

  static SubscriptionTier fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'prime':
      case 'prime_vip':
        return SubscriptionTier.prime;
      case 'prime_lite':
      case 'primelite':
        return SubscriptionTier.primeLite;
      default:
        return SubscriptionTier.free;
    }
  }

  String get dbValue {
    switch (this) {
      case SubscriptionTier.prime:
        return 'prime';
      case SubscriptionTier.primeLite:
        return 'prime_lite';
      case SubscriptionTier.free:
        return 'free';
    }
  }

  String get displayName {
    switch (this) {
      case SubscriptionTier.prime:
        return 'Prime VIP';
      case SubscriptionTier.primeLite:
        return 'Prime Lite';
      case SubscriptionTier.free:
        return 'Free';
    }
  }
}

class SubscriptionStatus {
  final String userId;
  final SubscriptionTier tier;
  final int interestsSentToday;
  final int maxDailyInterests;
  final int remainingDailyInterests;
  final int contactsUnlockedCount;
  final int contactsUnlockedLimit;
  final int remainingContacts;
  final DateTime? expiresAt;

  const SubscriptionStatus({
    required this.userId,
    required this.tier,
    required this.interestsSentToday,
    required this.maxDailyInterests,
    required this.remainingDailyInterests,
    required this.contactsUnlockedCount,
    required this.contactsUnlockedLimit,
    required this.remainingContacts,
    this.expiresAt,
  });

  bool get isFree => tier == SubscriptionTier.free;
  bool get isPrimeLite => tier == SubscriptionTier.primeLite;
  bool get isPrime => tier == SubscriptionTier.prime;
  bool get isPaid => isPrimeLite || isPrime;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      userId: json['user_id']?.toString() ?? '',
      tier: SubscriptionTier.fromString(json['tier']?.toString()),
      interestsSentToday: (json['interests_sent_today'] as num?)?.toInt() ?? 0,
      maxDailyInterests: (json['max_daily_interests'] as num?)?.toInt() ?? 5,
      remainingDailyInterests:
          (json['remaining_daily_interests'] as num?)?.toInt() ?? 5,
      contactsUnlockedCount:
          (json['contacts_unlocked_count'] as num?)?.toInt() ?? 0,
      contactsUnlockedLimit:
          (json['contacts_unlocked_limit'] as num?)?.toInt() ?? 0,
      remainingContacts: (json['remaining_contacts'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
    );
  }

  factory SubscriptionStatus.defaultFree(String userId) {
    return SubscriptionStatus(
      userId: userId,
      tier: SubscriptionTier.free,
      interestsSentToday: 0,
      maxDailyInterests: 5,
      remainingDailyInterests: 5,
      contactsUnlockedCount: 0,
      contactsUnlockedLimit: 0,
      remainingContacts: 0,
    );
  }
}
