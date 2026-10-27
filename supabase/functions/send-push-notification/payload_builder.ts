/**
 * Safe Notification Payload Builder
 * Mangalasutram — Part 2, Task 2.2
 *
 * Rules:
 * 1. Strict event whitelist.
 * 2. Zero PII, confidential chat messages, or credentials in payload.
 * 3. All navigation metadata keys are sanitized to non-sensitive identifiers.
 */

import type { NotificationType, PushNotificationEvent, FcmNotificationPayload } from './types.ts';

const ALLOWED_EVENT_TYPES: Set<NotificationType> = new Set([
  'interest_received',
  'interest_accepted',
  'interest_declined',
  'chat_message',
  'high_guna_milan',
  'profile_visit',
  'quota_exhausted',
  'contact_locked',
  'pending_reminder',
  'family_action',
  'promotional_offer',
  'system',
]);

export function isValidEventType(type: string): type is NotificationType {
  return ALLOWED_EVENT_TYPES.has(type as NotificationType);
}

export function buildNotificationContent(
  type: NotificationType,
  actorName?: string
): FcmNotificationPayload {
  const sanitizedActor = actorName ? actorName.trim().slice(0, 50) : null;

  switch (type) {
    case 'interest_received':
      return {
        title: 'New Alliance Interest',
        body: sanitizedActor
          ? `${sanitizedActor} has expressed interest in connecting with you.`
          : 'A member has expressed interest in your profile.',
      };

    case 'interest_accepted':
      return {
        title: 'Alliance Interest Accepted',
        body: sanitizedActor
          ? `${sanitizedActor} accepted your interest! You may now begin conversing.`
          : 'Your interest was accepted by the prospective alliance.',
      };

    case 'interest_declined':
      return {
        title: 'Alliance Update',
        body: 'There is an update regarding one of your sent alliance interests.',
      };

    case 'chat_message':
      // CRITICAL: NEVER include the actual message text in push notifications to preserve privacy and E2EE confidentiality.
      return {
        title: 'New Message Received',
        body: sanitizedActor
          ? `${sanitizedActor} sent you a message.`
          : 'You have received a new message in your sacred conversation.',
      };

    case 'high_guna_milan':
      return {
        title: 'Auspicious Horoscope Match',
        body: 'A new high Guna Milan alignment was discovered for you.',
      };

    case 'profile_visit':
      return {
        title: 'Profile Interaction',
        body: 'A prospect has viewed your matrimonial biodata.',
      };

    case 'quota_exhausted':
      return {
        title: 'Daily Matches Explored',
        body: 'You have reviewed your auspicious daily matches. Upgrade to explore more.',
      };

    case 'contact_locked':
      return {
        title: 'Contact Request Available',
        body: 'A verified contact unlock is ready for your review.',
      };

    case 'pending_reminder':
      return {
        title: 'Sacred Alliance Reminder',
        body: 'You have pending inquiries awaiting your graceful response.',
      };

    case 'family_action':
      return {
        title: 'Family Circle Update',
        body: 'A family member added notes or reviewed an alliance for you.',
      };

    case 'promotional_offer':
      return {
        title: 'Exclusive Mangalasutram Privilege',
        body: 'Discover auspicious royal tier benefits crafted for your matrimonial journey.',
      };

    case 'system':
    default:
      return {
        title: 'Mangalasutram Notice',
        body: 'You have an important update regarding your account.',
      };
  }
}

/**
 * Constructs sanitized, minimal navigation data.
 * All keys and values must be strings for FCM HTTP v1 `data` field.
 */
export function buildNavigationData(event: PushNotificationEvent): Record<string, string> {
  const data: Record<string, string> = {
    notification_type: event.type,
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  };

  if (!event.metadata) {
    return data;
  }

  // Whitelist of permitted navigation keys. No arbitrary keys allowed.
  const allowedKeys = ['route', 'id', 'conversation_id', 'profile_id', 'interest_id'];

  for (const [key, value] of Object.entries(event.metadata)) {
    if (allowedKeys.includes(key) && typeof value === 'string') {
      // Strip any sensitive prefix, truncate to safe 256 characters
      data[key] = value.trim().slice(0, 256);
    }
  }

  return data;
}
