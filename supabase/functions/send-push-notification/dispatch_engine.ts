/**
 * Secure FCM Push Dispatch Engine
 * Mangalasutram — Part 2, Task 2.2
 *
 * Core dispatch coordinator implementing:
 * - Event validation & recipient checks
 * - In-memory idempotency deduplication
 * - Multi-token dispatching per recipient
 * - Bounded retries on transient FCM errors
 * - Definitive invalid token purging
 * - Redacted token logging (zero credential/PII leakage)
 */

import type {
  PushNotificationEvent,
  DispatchSummary,
  FcmSendResult,
  FcmMessagePayload,
  TokenRepository,
  FcmHttpClient,
  IdempotencyStore,
} from './types.ts';
import {
  isValidEventType,
  buildNotificationContent,
  buildNavigationData,
} from './payload_builder.ts';
import { InMemoryIdempotencyStore } from './idempotency.ts';

/**
 * Masks an FCM token for safe logging.
 * Example: 'fcm_12345678abcdef...9999' -> 'fcm_1234...9999'
 */
export function maskToken(token: string): string {
  if (!token || token.length < 12) return '***';
  return `${token.slice(0, 8)}...${token.slice(-4)}`;
}

// UUID validation regex (accepts all standard 128-bit hex UUID formats)
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Maximum permitted event age for push notification dispatch (24 hours)
export const MAX_EVENT_AGE_MS = 24 * 60 * 60 * 1000;

export class PushDispatchEngine {
  private tokenRepo: TokenRepository;
  private fcmClient: FcmHttpClient;
  private idempotencyStore: IdempotencyStore;
  private maxRetries: number;

  constructor(
    tokenRepo: TokenRepository,
    fcmClient: FcmHttpClient,
    idempotencyStore?: IdempotencyStore,
    maxRetries = 2
  ) {
    this.tokenRepo = tokenRepo;
    this.fcmClient = fcmClient;
    this.idempotencyStore = idempotencyStore || new InMemoryIdempotencyStore();
    this.maxRetries = maxRetries;
  }

  async dispatch(event: PushNotificationEvent): Promise<DispatchSummary> {
    // 1. Validate recipient UUID
    if (!event.recipient_user_id || !UUID_REGEX.test(event.recipient_user_id)) {
      throw new Error(`Invalid recipient_user_id: '${event.recipient_user_id}' is not a valid UUID.`);
    }

    // 2. Validate event type against whitelist
    if (!isValidEventType(event.type)) {
      throw new Error(`Unsupported notification event type: '${event.type}'.`);
    }

    // 2.5. Event Age Gate: Reject stale events older than 24 hours
    if (event.event_timestamp) {
      const eventTime = new Date(event.event_timestamp).getTime();
      if (isNaN(eventTime)) {
        throw new Error(`Invalid event_timestamp: '${event.event_timestamp}' is not a valid date string.`);
      }
      if (Date.now() - eventTime > MAX_EVENT_AGE_MS) {
        throw new Error('Stale event rejected: event_timestamp exceeds maximum 24-hour dispatch window.');
      }
    }

    // 3. Deduplication / Idempotency check via persistent/in-memory store
    if (event.idempotency_key) {
      const claimResult = await this.idempotencyStore.claim(event.idempotency_key, 600);
      if (!claimResult.claimed) {
        if (claimResult.cachedSummary) {
          return {
            ...claimResult.cachedSummary,
            deduplicated: true,
          };
        }
        // In-flight concurrent request, tombstone_archived, or expired_unconfirmed deduplication
        return {
          event_type: event.type,
          recipient_user_id: event.recipient_user_id,
          total_tokens: 0,
          successful_deliveries: 0,
          failed_deliveries: 0,
          cleaned_tokens: 0,
          results: [],
          deduplicated: true,
        };
      }
    }

    // 4. Look up registered device tokens for recipient
    const tokens = await this.tokenRepo.getTokensForUser(event.recipient_user_id);
    if (!tokens || tokens.length === 0) {
      const emptySummary: DispatchSummary = {
        event_type: event.type,
        recipient_user_id: event.recipient_user_id,
        total_tokens: 0,
        successful_deliveries: 0,
        failed_deliveries: 0,
        cleaned_tokens: 0,
        results: [],
      };
      if (event.idempotency_key) {
        await this.idempotencyStore.complete(event.idempotency_key, emptySummary);
      }
      return emptySummary;
    }

    // 5. Construct safe, sanitized notification content & navigation data
    const content = buildNotificationContent(event.type, event.actor_name);
    const navData = buildNavigationData(event);

    // 6. Dispatch to all recipient devices with bounded retry
    const results: FcmSendResult[] = [];
    let cleanedTokens = 0;

    await Promise.all(
      tokens.map(async (device) => {
        const payload: FcmMessagePayload = {
          token: device.fcm_token,
          notification: content,
          data: navData,
          android: {
            priority: 'high',
            notification: {
              channel_id: 'mangalasutram_high_importance',
              icon: 'ic_notification',
              color: '#6E1732',
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: content.title,
                  body: content.body,
                },
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        // Bounded retry loop for transient failures
        let result: FcmSendResult = { token: device.fcm_token, success: false };
        let attempt = 0;

        while (attempt <= this.maxRetries) {
          try {
            result = await this.fcmClient.send(payload);
            if (result.success || !result.is_transient) {
              break;
            }
          } catch (err) {
            result = {
              token: device.fcm_token,
              success: false,
              is_transient: true,
              error_code: String(err),
            };
          }

          attempt++;
          if (attempt <= this.maxRetries) {
            // Exponential backoff: 50ms, 150ms
            const backoffMs = attempt * 50;
            await new Promise((resolve) => setTimeout(resolve, backoffMs));
          }
        }

        // 7. Cleanup invalid or unregistered tokens
        if (!result.success && result.is_unregistered) {
          try {
            await this.tokenRepo.removeToken(device.fcm_token, event.recipient_user_id);
            cleanedTokens++;
          } catch (_) {
            // Log failure to remove token safely
          }
        }

        results.push(result);
      })
    );

    const successfulDeliveries = results.filter((r) => r.success).length;
    const failedDeliveries = results.length - successfulDeliveries;

    const summary: DispatchSummary = {
      event_type: event.type,
      recipient_user_id: event.recipient_user_id,
      total_tokens: tokens.length,
      successful_deliveries: successfulDeliveries,
      failed_deliveries: failedDeliveries,
      cleaned_tokens: cleanedTokens,
      results,
    };

    // Record completion in idempotency store
    if (event.idempotency_key) {
      await this.idempotencyStore.complete(event.idempotency_key, summary);
    }

    return summary;
  }
}
