/**
 * Push Notification Types & Event Schema
 * Mangalasutram — Part 2, Task 2.2: Secure FCM Push Dispatch Foundation
 */

export type NotificationType =
  | 'interest_received'
  | 'interest_accepted'
  | 'interest_declined'
  | 'chat_message'
  | 'high_guna_milan'
  | 'profile_visit'
  | 'quota_exhausted'
  | 'contact_locked'
  | 'pending_reminder'
  | 'family_action'
  | 'promotional_offer'
  | 'system';

export interface PushNotificationEvent {
  recipient_user_id: string;
  type: NotificationType;
  actor_name?: string;
  metadata?: Record<string, string>;
  idempotency_key?: string;
  event_timestamp?: string; // ISO 8601 string representing original event generation timestamp
}

export interface DeviceTokenRecord {
  id: string;
  user_id: string;
  fcm_token: string;
  platform: 'android' | 'ios' | 'web';
  device_info?: Record<string, unknown>;
}

export interface FcmNotificationPayload {
  title: string;
  body: string;
}

export interface FcmMessagePayload {
  token: string;
  notification: FcmNotificationPayload;
  data: Record<string, string>;
  android?: {
    priority: 'high' | 'normal';
    notification?: {
      channel_id: string;
      icon?: string;
      color?: string;
    };
  };
  apns?: {
    payload?: {
      aps?: {
        alert: {
          title: string;
          body: string;
        };
        sound?: string;
        badge?: number;
      };
    };
  };
}

export interface FcmSendResult {
  token: string;
  success: boolean;
  message_id?: string;
  error_code?: string;
  is_unregistered?: boolean;
  is_transient?: boolean;
}

export interface DispatchSummary {
  event_type: NotificationType;
  recipient_user_id: string;
  total_tokens: number;
  successful_deliveries: number;
  failed_deliveries: number;
  cleaned_tokens: number;
  results: FcmSendResult[];
  deduplicated?: boolean;
}

export interface TokenRepository {
  getTokensForUser(userId: string): Promise<DeviceTokenRecord[]>;
  removeToken(fcmToken: string, userId: string): Promise<boolean>;
}

export interface FcmHttpClient {
  send(message: FcmMessagePayload): Promise<FcmSendResult>;
}

export interface IdempotencyClaimResult {
  claimed: boolean;
  status?: 'in_flight' | 'completed' | 'expired_unconfirmed' | 'tombstone_archived';
  cachedSummary?: DispatchSummary;
}

export interface IdempotencyStore {
  /**
   * Atomically claims an idempotency key.
   * - If key was completed within retention window, returns { claimed: false, status: 'completed', cachedSummary }.
   * - If key is tombstoned or completed past retention, transitions to tombstone and returns { claimed: false, status: 'tombstone_archived' }.
   * - If key is in-flight or expired_unconfirmed, returns { claimed: false, status: 'in_flight' | 'expired_unconfirmed' }.
   * - If key is freshly claimed, returns { claimed: true, status: 'in_flight' }.
   *
   * Note: Standard notification callers cannot force-retry.
   */
  claim(key: string, ttlSeconds: number): Promise<IdempotencyClaimResult>;

  /**
   * Records the final completion summary for the idempotency key.
   */
  complete(key: string, summary: DispatchSummary): Promise<void>;

  /**
   * Privileged administrative recovery for expired_unconfirmed records.
   * Must not be exposed to or callable by normal client dispatch flows.
   */
  adminRecover?(key: string, ttlSeconds?: number): Promise<IdempotencyClaimResult>;

  /**
   * Two-tier cleanup: converts expired completed/unconfirmed records into tombstones (stripping payloads)
   * and purges only tombstones older than 30 days.
   */
  cleanupExpired?(batchSize?: number): Promise<any>;
}

