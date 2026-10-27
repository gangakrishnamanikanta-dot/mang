/**
 * Comprehensive Unit Test Suite for Secure FCM Push Dispatch Foundation
 * Mangalasutram — Part 2, Task 2.2 Final Reliability & Security Corrections
 *
 * Verifies:
 * 1. Definitive unregistered token parsing & pruning vs generic 404/400/401/403/5xx non-pruning.
 * 2. Dedicated PUSH_DISPATCH_SECRET authorization & service_role_key rejection.
 * 3. Persistent & In-memory Idempotency Store contract & fallback.
 * 4. Transient FCM failure & bounded retry recovery without token pruning.
 * 5. Multi-device delivery & partial pruning.
 * 6. Safe payload construction & token masking.
 */

import assert from 'node:assert/strict';
import { test, describe } from 'node:test';
import type {
  PushNotificationEvent,
  TokenRepository,
  DeviceTokenRecord,
  FcmHttpClient,
  FcmMessagePayload,
  FcmSendResult,
} from '../types.ts';
import {
  isValidEventType,
  buildNotificationContent,
  buildNavigationData,
} from '../payload_builder.ts';
import {
  PushDispatchEngine,
  maskToken,
} from '../dispatch_engine.ts';
import { parseFcmErrorResponse } from '../fcm_auth.ts';
import {
  validatePushDispatchAuth,
  timingSafeEqual,
} from '../auth_validator.ts';
import {
  InMemoryIdempotencyStore,
  DatabaseIdempotencyStore,
  PersistentStorageUnavailableError,
} from '../idempotency.ts';

// In-Memory Mock Token Repository
class MockTokenRepository implements TokenRepository {
  public store: Map<string, DeviceTokenRecord[]> = new Map();
  public removedTokens: { token: string; userId: string }[] = [];

  setTokens(userId: string, tokens: DeviceTokenRecord[]) {
    this.store.set(userId, tokens);
  }

  async getTokensForUser(userId: string): Promise<DeviceTokenRecord[]> {
    return this.store.get(userId) || [];
  }

  async removeToken(fcmToken: string, userId: string): Promise<boolean> {
    this.removedTokens.push({ token: fcmToken, userId });
    const userTokens = this.store.get(userId) || [];
    this.store.set(
      userId,
      userTokens.filter((t) => t.fcm_token !== fcmToken)
    );
    return true;
  }
}

// Mock FCM HTTP Client
class MockFcmHttpClient implements FcmHttpClient {
  public sentMessages: FcmMessagePayload[] = [];
  public mockResponses: FcmSendResult[] = [];
  public callCount = 0;

  queueResponse(response: FcmSendResult) {
    this.mockResponses.push(response);
  }

  async send(message: FcmMessagePayload): Promise<FcmSendResult> {
    this.callCount++;
    this.sentMessages.push(message);
    if (this.mockResponses.length > 0) {
      return this.mockResponses.shift()!;
    }
    return { token: message.token, success: true, message_id: `msg_${this.callCount}` };
  }
}

const TEST_USER_ID = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const TEST_TOKEN_1 = 'fcm_tok_111122223333444455556666777788889999aaaa';
const TEST_TOKEN_2 = 'fcm_tok_aaaabbbbccccddddeeeeffff000011112222bbbb';

describe('Mangalasutram Push Dispatch Foundation & Security Hardening Tests', () => {

  // --- 1. FCM Error Structure & Definitive Token Cleanup Tests ---
  describe('1. FCM Error Parsing & Definitive Cleanup', () => {
    test('1a. Definitive UNREGISTERED FcmError detail marks isUnregistered = true', () => {
      const fcmError = {
        error: {
          code: 404,
          message: 'Requested entity was not found.',
          status: 'NOT_FOUND',
          details: [
            {
              '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
              errorCode: 'UNREGISTERED',
            },
          ],
        },
      };

      const result = parseFcmErrorResponse(404, fcmError);
      assert.equal(result.errorCode, 'UNREGISTERED');
      assert.equal(result.isUnregistered, true);
      assert.equal(result.isTransient, false);
    });

    test('1b. Generic HTTP 404 without UNREGISTERED detail does NOT mark isUnregistered', () => {
      const generic404 = {
        error: {
          code: 404,
          message: 'Project "mangalasutram-bad" not found.',
          status: 'NOT_FOUND',
        },
      };

      const result = parseFcmErrorResponse(404, generic404);
      assert.equal(result.errorCode, 'NOT_FOUND');
      // Crucial: generic 404 must NOT delete the device token!
      assert.equal(result.isUnregistered, false);
      assert.equal(result.isTransient, false);
    });

    test('1c. Authentication failure (HTTP 401) does NOT mark isUnregistered', () => {
      const auth401 = {
        error: {
          code: 401,
          message: 'Request had invalid authentication credentials.',
          status: 'UNAUTHENTICATED',
        },
      };

      const result = parseFcmErrorResponse(401, auth401);
      assert.equal(result.errorCode, 'UNAUTHENTICATED');
      assert.equal(result.isUnregistered, false);
      assert.equal(result.isTransient, false);
    });

    test('1d. Project misconfiguration or sender ID mismatch (HTTP 403) does NOT mark isUnregistered', () => {
      const forbidden403 = {
        error: {
          code: 403,
          message: 'SenderId mismatch or permission denied.',
          status: 'PERMISSION_DENIED',
          details: [
            {
              '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
              errorCode: 'SENDER_ID_MISMATCH',
            },
          ],
        },
      };

      const result = parseFcmErrorResponse(403, forbidden403);
      assert.equal(result.errorCode, 'SENDER_ID_MISMATCH');
      assert.equal(result.isUnregistered, false);
      assert.equal(result.isTransient, false);
    });

    test('1e. Transient FCM errors (HTTP 500, 503, 429) mark isTransient = true, isUnregistered = false', () => {
      const transient503 = {
        error: {
          code: 503,
          message: 'The service is temporarily unavailable.',
          status: 'UNAVAILABLE',
        },
      };

      const res503 = parseFcmErrorResponse(503, transient503);
      assert.equal(res503.isTransient, true);
      assert.equal(res503.isUnregistered, false);

      const res500 = parseFcmErrorResponse(500, null);
      assert.equal(res500.isTransient, true);
      assert.equal(res500.isUnregistered, false);

      const res429 = parseFcmErrorResponse(429, null);
      assert.equal(res429.isTransient, true);
      assert.equal(res429.isUnregistered, false);
    });

    test('1f. Dispatch engine cleans token ONLY on definitive is_unregistered', async () => {
      const mockRepo = new MockTokenRepository();
      mockRepo.setTokens(TEST_USER_ID, [
        { id: 'dev_1', user_id: TEST_USER_ID, fcm_token: TEST_TOKEN_1, platform: 'android' },
      ]);
      const mockFcm = new MockFcmHttpClient();
      mockFcm.queueResponse({
        token: TEST_TOKEN_1,
        success: false,
        error_code: 'UNREGISTERED',
        is_unregistered: true,
      });

      const engine = new PushDispatchEngine(mockRepo, mockFcm);
      const summary = await engine.dispatch({
        recipient_user_id: TEST_USER_ID,
        type: 'chat_message',
        actor_name: 'Raghav',
      });

      assert.equal(summary.cleaned_tokens, 1);
      assert.equal(mockRepo.removedTokens.length, 1);
      assert.equal(mockRepo.removedTokens[0].token, TEST_TOKEN_1);
    });

    test('1g. Dispatch engine does NOT clean token on generic 404 or transient failure', async () => {
      const mockRepo = new MockTokenRepository();
      mockRepo.setTokens(TEST_USER_ID, [
        { id: 'dev_1', user_id: TEST_USER_ID, fcm_token: TEST_TOKEN_1, platform: 'android' },
      ]);
      const mockFcm = new MockFcmHttpClient();
      mockFcm.queueResponse({
        token: TEST_TOKEN_1,
        success: false,
        error_code: 'NOT_FOUND',
        is_unregistered: false,
      });

      const engine = new PushDispatchEngine(mockRepo, mockFcm);
      const summary = await engine.dispatch({
        recipient_user_id: TEST_USER_ID,
        type: 'system',
      });

      assert.equal(summary.cleaned_tokens, 0);
      assert.equal(mockRepo.removedTokens.length, 0);
      const remaining = await mockRepo.getTokensForUser(TEST_USER_ID);
      assert.equal(remaining.length, 1);
    });
  });

  // --- 2. Hardened Endpoint Authentication Tests ---
  describe('2. Hardened Endpoint Authentication', () => {
    const PUSH_SECRET = 'super_secure_push_secret_key_888999';
    const SERVICE_ROLE_KEY = 'service_role_secret_key_111222';

    test('2a. Missing Authorization header is rejected (401)', () => {
      const res = validatePushDispatchAuth(null, PUSH_SECRET);
      assert.equal(res.authorized, false);
      assert.equal(res.errorStatus, 401);
      assert.match(res.errorMessage!, /Missing or malformed/);
    });

    test('2b. Malformed Authorization header without Bearer is rejected (401)', () => {
      const res = validatePushDispatchAuth(`Basic ${PUSH_SECRET}`, PUSH_SECRET);
      assert.equal(res.authorized, false);
      assert.equal(res.errorStatus, 401);
    });

    test('2c. SUPABASE_SERVICE_ROLE_KEY is strictly REJECTED as an endpoint caller password (401)', () => {
      const res = validatePushDispatchAuth(`Bearer ${SERVICE_ROLE_KEY}`, PUSH_SECRET);
      assert.equal(res.authorized, false);
      assert.equal(res.errorStatus, 401);
      assert.match(res.errorMessage!, /Invalid dispatch credentials/);
    });

    test('2d. Wrong secret token is rejected (401)', () => {
      const res = validatePushDispatchAuth('Bearer wrong_secret_token_1234', PUSH_SECRET);
      assert.equal(res.authorized, false);
      assert.equal(res.errorStatus, 401);
    });

    test('2e. Unconfigured server secret returns server error (500)', () => {
      const res = validatePushDispatchAuth(`Bearer ${PUSH_SECRET}`, undefined);
      assert.equal(res.authorized, false);
      assert.equal(res.errorStatus, 500);
      assert.match(res.errorMessage!, /PUSH_DISPATCH_SECRET is not configured/);
    });

    test('2f. Valid PUSH_DISPATCH_SECRET is successfully accepted (200)', () => {
      const res = validatePushDispatchAuth(`Bearer ${PUSH_SECRET}`, PUSH_SECRET);
      assert.equal(res.authorized, true);
      assert.equal(res.errorStatus, undefined);
    });

    test('2g. Timing-safe comparison operates reliably without leakage', () => {
      assert.equal(timingSafeEqual('exact_match_123', 'exact_match_123'), true);
      assert.equal(timingSafeEqual('exact_match_123', 'exact_match_124'), false);
      assert.equal(timingSafeEqual('short', 'longer_string'), false);
    });
  });

  // --- 3. Persistent & In-Memory Idempotency Store Tests ---
  describe('3. Idempotency Store & Production Fallback Prevention', () => {
    test('3a. InMemoryIdempotencyStore claims fresh key and reports in-flight/completed', async () => {
      const store = new InMemoryIdempotencyStore();
      const claim1 = await store.claim('key_1', 60);
      assert.equal(claim1.claimed, true);

      // Concurrent attempt while in-flight
      const claim2 = await store.claim('key_1', 60);
      assert.equal(claim2.claimed, false);
      assert.equal(claim2.cachedSummary, undefined);

      // Complete execution
      const dummySummary = {
        event_type: 'interest_received' as const,
        recipient_user_id: TEST_USER_ID,
        total_tokens: 1,
        successful_deliveries: 1,
        failed_deliveries: 0,
        cleaned_tokens: 0,
        results: [],
      };
      await store.complete('key_1', dummySummary);

      // Subsequent attempt returns cached summary
      const claim3 = await store.claim('key_1', 60);
      assert.equal(claim3.claimed, false);
      assert.equal(claim3.cachedSummary?.successful_deliveries, 1);
    });

    test('3b. DatabaseIdempotencyStore in PRODUCTION (allowFallback: false) fails safely with PersistentStorageUnavailableError when table/RPC 42P01 is absent', async () => {
      const mockSupabaseMissingTable = {
        rpc: async (_fn: string, _args: any) => ({
          data: null,
          error: { code: '42P01', message: 'relation "push_dispatch_idempotency" does not exist' },
        }),
      };

      const prodStore = new DatabaseIdempotencyStore(mockSupabaseMissingTable, false);
      await assert.rejects(
        async () => {
          await prodStore.claim('key_prod_test', 60);
        },
        PersistentStorageUnavailableError
      );
    });

    test('3c. Production dispatch engine aborts dispatch and DOES NOT SEND push when persistent store fails', async () => {
      const mockRepo = new MockTokenRepository();
      mockRepo.setTokens(TEST_USER_ID, [
        { id: 'dev_1', user_id: TEST_USER_ID, fcm_token: TEST_TOKEN_1, platform: 'android' },
      ]);
      const mockFcm = new MockFcmHttpClient();

      const mockSupabaseMissingTable = {
        rpc: async () => ({
          data: null,
          error: { code: '42P01', message: 'relation does not exist' },
        }),
      };

      const prodStore = new DatabaseIdempotencyStore(mockSupabaseMissingTable, false);
      const engine = new PushDispatchEngine(mockRepo, mockFcm, prodStore);

      await assert.rejects(
        async () => {
          await engine.dispatch({
            recipient_user_id: TEST_USER_ID,
            type: 'interest_received',
            idempotency_key: 'prod_safety_key',
          });
        },
        PersistentStorageUnavailableError
      );

      // CRITICAL ASSERTION: Zero push messages sent to FCM!
      assert.equal(mockFcm.callCount, 0);
    });

    test('3d. Development fallback works ONLY when explicitly enabled (allowFallback: true)', async () => {
      const mockSupabaseMissingTable = {
        rpc: async () => ({
          data: null,
          error: { code: '42P01', message: 'relation does not exist' },
        }),
      };

      const devStore = new DatabaseIdempotencyStore(mockSupabaseMissingTable, true);
      const claim = await devStore.claim('key_dev_fallback', 60);
      assert.equal(claim.claimed, true);

      // Concurrent duplicate uses fallback memory store
      const claim2 = await devStore.claim('key_dev_fallback', 60);
      assert.equal(claim2.claimed, false);
    });

    test('3e. Atomic database RPC claim: concurrent claims for same key permit at most ONE successful claim', async () => {
      // Mock simulating PostgreSQL atomic insert with ON CONFLICT
      let keyState: 'none' | 'in_flight' | 'completed' = 'none';
      let cachedSummary: any = null;

      const mockSupabaseAtomicRpc = {
        rpc: async (fn: string, args: any) => {
          if (fn === 'claim_push_idempotency') {
            if (keyState === 'none') {
              keyState = 'in_flight';
              return { data: { claimed: true, status: 'in_flight' }, error: null };
            }
            if (keyState === 'completed') {
              return { data: { claimed: false, status: 'completed', summary: cachedSummary }, error: null };
            }
            return { data: { claimed: false, status: 'in_flight' }, error: null };
          }
          if (fn === 'complete_push_idempotency') {
            keyState = 'completed';
            cachedSummary = args.p_summary;
            return { data: true, error: null };
          }
          return { data: null, error: null };
        },
      };

      const dbStore = new DatabaseIdempotencyStore(mockSupabaseAtomicRpc, false);

      // Simulate 2 competing concurrent requests claiming the same key
      const [result1, result2] = await Promise.all([
        dbStore.claim('race_condition_key', 60),
        dbStore.claim('race_condition_key', 60),
      ]);

      // Exactly ONE claim succeeded!
      assert.equal(result1.claimed !== result2.claimed, true);
      const successfulClaim = result1.claimed ? result1 : result2;
      const rejectedClaim = result1.claimed ? result2 : result1;
      assert.equal(successfulClaim.claimed, true);
      assert.equal(rejectedClaim.claimed, false);

      // Complete the operation
      await dbStore.complete('race_condition_key', {
        event_type: 'chat_message',
        recipient_user_id: TEST_USER_ID,
        total_tokens: 1,
        successful_deliveries: 1,
        failed_deliveries: 0,
        cleaned_tokens: 0,
        results: [],
      });

      // Subsequent claim within retention period returns cached summary
      const subsequentClaim = await dbStore.claim('race_condition_key', 60);
      assert.equal(subsequentClaim.claimed, false);
      assert.equal(subsequentClaim.cachedSummary?.successful_deliveries, 1);
    });

    test('3f. Completed key is rejected while still within its retention period', async () => {
      const store = new InMemoryIdempotencyStore();
      await store.claim('key_retention_check', 3600); // 1 hour TTL
      await store.complete('key_retention_check', {
        event_type: 'interest_received',
        recipient_user_id: TEST_USER_ID,
        total_tokens: 1,
        successful_deliveries: 1,
        failed_deliveries: 0,
        cleaned_tokens: 0,
        results: [],
      });

      const reClaim = await store.claim('key_retention_check', 3600);
      assert.equal(reClaim.claimed, false);
      assert.equal(reClaim.status, 'completed');
      assert.equal(reClaim.cachedSummary?.successful_deliveries, 1);
    });

    test('3g. Expiration policy: Completed key past retention window transitions to tombstone_archived and rejects replay', async () => {
      const store = new InMemoryIdempotencyStore();
      await store.claim('key_expired_completed', -10); // already expired
      await store.complete('key_expired_completed', {
        event_type: 'system',
        recipient_user_id: TEST_USER_ID,
        total_tokens: 1,
        successful_deliveries: 1,
        failed_deliveries: 0,
        cleaned_tokens: 0,
        results: [],
      });

      // Claiming an expired completed key must NOT re-dispatch: it transitions to tombstone_archived
      const reClaim = await store.claim('key_expired_completed', 60);
      assert.equal(reClaim.claimed, false);
      assert.equal(reClaim.status, 'tombstone_archived');
      assert.equal(reClaim.cachedSummary, undefined);

      // Verify payload was stripped to prevent memory/storage bloat
      const rawEntry = store.cache.get('key_expired_completed');
      assert.equal(rawEntry?.status, 'tombstone_archived');
      assert.equal(rawEntry?.summary, undefined);
    });

    test('3h. Conservative policy: Expired in_flight claim transitions to expired_unconfirmed and rejects automatic retry', async () => {
      const store = new InMemoryIdempotencyStore();
      // Simulate crashed worker: in_flight claim with past expiration
      await store.claim('key_crashed_worker', -10);

      // Subsequent automated retry: conservative policy returns claimed: false to prevent duplicate external FCM send
      const retryResult = await store.claim('key_crashed_worker', 60);
      assert.equal(retryResult.claimed, false);
      assert.equal(retryResult.status, 'expired_unconfirmed');

      // Ordinary callers cannot force retry via claim(). Privileged adminRecover is required:
      const adminRecoverResult = await store.adminRecover('key_crashed_worker', 60);
      assert.equal(adminRecoverResult.claimed, true);
      assert.equal(adminRecoverResult.status, 'in_flight');
    });

    test('3i. Two-tier cleanup: tombstones expired completed & stale unconfirmed (stripping payloads) and purges only 30-day tombstones', async () => {
      const store = new InMemoryIdempotencyStore();
      const now = Date.now();

      // Record A: Completed and expired (past retention) -> Should be transitioned to tombstone_archived (summary stripped)
      store.cache.set('rec_expired_completed', {
        status: 'completed',
        createdAt: now - 7200 * 1000,
        expiresAt: now - 3600 * 1000,
        summary: { event_type: 'system' } as any,
      });

      // Record B: Expired unconfirmed older than 24 hours -> Should be transitioned to tombstone_archived
      store.cache.set('rec_stale_unconfirmed', {
        status: 'expired_unconfirmed',
        createdAt: now - 25 * 3600 * 1000,
        expiresAt: now - 24 * 3600 * 1000,
      });

      // Record C: Active in_flight claim (lease valid for next 10 minutes) -> MUST NOT be modified or deleted
      store.cache.set('rec_active_inflight', {
        status: 'in_flight',
        createdAt: now,
        expiresAt: now + 600 * 1000,
      });

      // Record D: Active completed record (retention valid for next 24h) -> MUST NOT be modified or deleted
      store.cache.set('rec_active_completed', {
        status: 'completed',
        createdAt: now,
        expiresAt: now + 86400 * 1000,
        summary: { event_type: 'system' } as any,
      });

      // Record E: Tombstone older than 30 days -> MUST be physically purged
      store.cache.set('rec_ancient_tombstone', {
        status: 'tombstone_archived',
        createdAt: now - 31 * 86400 * 1000,
        expiresAt: now - 31 * 86400 * 1000,
      });

      // Record F: Recent tombstone (5 days old) -> MUST be preserved
      store.cache.set('rec_recent_tombstone', {
        status: 'tombstone_archived',
        createdAt: now - 5 * 86400 * 1000,
        expiresAt: now - 5 * 86400 * 1000,
      });

      const cleanupStats = await store.cleanupExpired(100);
      assert.equal(cleanupStats.tombstoned_completed, 1);
      assert.equal(cleanupStats.tombstoned_unconfirmed, 1);
      assert.equal(cleanupStats.purged_old_tombstones, 1);

      // Record A & B are preserved as tombstones with null/undefined summary
      assert.equal(store.cache.get('rec_expired_completed')?.status, 'tombstone_archived');
      assert.equal(store.cache.get('rec_expired_completed')?.summary, undefined);
      assert.equal(store.cache.get('rec_stale_unconfirmed')?.status, 'tombstone_archived');

      // Active records are untouched
      assert.equal(store.cache.get('rec_active_inflight')?.status, 'in_flight');
      assert.equal(store.cache.get('rec_active_completed')?.status, 'completed');

      // Ancient tombstone is purged, recent tombstone remains
      assert.equal(store.cache.has('rec_ancient_tombstone'), false);
      assert.equal(store.cache.has('rec_recent_tombstone'), true);
    });

    test('3j. Event Age Gate: Dispatch engine rejects stale events older than 24 hours', async () => {
      const mockRepo = new MockTokenRepository();
      mockRepo.setTokens(TEST_USER_ID, [
        { id: 'dev_1', user_id: TEST_USER_ID, fcm_token: TEST_TOKEN_1, platform: 'android' },
      ]);
      const mockFcm = new MockFcmHttpClient();
      const engine = new PushDispatchEngine(mockRepo, mockFcm);

      // Stale event (25 hours old)
      const staleTimestamp = new Date(Date.now() - 25 * 3600 * 1000).toISOString();
      await assert.rejects(
        async () => {
          await engine.dispatch({
            recipient_user_id: TEST_USER_ID,
            type: 'interest_received',
            event_timestamp: staleTimestamp,
          });
        },
        { message: /Stale event rejected: event_timestamp exceeds maximum 24-hour dispatch window/ }
      );
      assert.equal(mockFcm.callCount, 0);

      // Fresh event (2 hours old) succeeds
      const freshTimestamp = new Date(Date.now() - 2 * 3600 * 1000).toISOString();
      const summary = await engine.dispatch({
        recipient_user_id: TEST_USER_ID,
        type: 'interest_received',
        event_timestamp: freshTimestamp,
      });
      assert.equal(summary.successful_deliveries, 1);
      assert.equal(mockFcm.callCount, 1);
    });

    test('3k. Tombstone replay prevention: Attempting to dispatch an archived tombstone returns deduplicated: true with zero sends', async () => {
      const mockRepo = new MockTokenRepository();
      mockRepo.setTokens(TEST_USER_ID, [
        { id: 'dev_1', user_id: TEST_USER_ID, fcm_token: TEST_TOKEN_1, platform: 'android' },
      ]);
      const mockFcm = new MockFcmHttpClient();
      const store = new InMemoryIdempotencyStore();

      // Pre-populate key as tombstone_archived
      store.cache.set('tombstone_test_key', {
        status: 'tombstone_archived',
        createdAt: Date.now() - 48 * 3600 * 1000,
        expiresAt: Date.now() - 47 * 3600 * 1000,
      });

      const engine = new PushDispatchEngine(mockRepo, mockFcm, store);
      const summary = await engine.dispatch({
        recipient_user_id: TEST_USER_ID,
        type: 'interest_received',
        idempotency_key: 'tombstone_test_key',
      });

      assert.equal(summary.deduplicated, true);
      assert.equal(summary.successful_deliveries, 0);
      assert.equal(mockFcm.callCount, 0);
    });

    test('3l. DatabaseIdempotencyStore with privileged admin_recover RPC successfully restores ambiguous expired_unconfirmed claim', async () => {
      let rpcCalled = '';
      const mockSupabase = {
        rpc: async (fn: string, _args: any) => {
          rpcCalled = fn;
          if (fn === 'admin_recover_unconfirmed_push_idempotency') {
            return { data: { recovered: true, status: 'in_flight' }, error: null };
          }
          return { data: null, error: null };
        },
      };

      const dbStore = new DatabaseIdempotencyStore(mockSupabase, false);
      const res = await dbStore.adminRecover('key_to_recover', 600);

      assert.equal(rpcCalled, 'admin_recover_unconfirmed_push_idempotency');
      assert.equal(res.claimed, true);
      assert.equal(res.status, 'in_flight');
    });
  });

  // --- 4. Dispatch Engine Delivery, Retry & Edge Case Tests ---
  describe('4. Dispatch Engine Core & Edge Cases', () => {
    test('4a. Successful delivery to registered device', async () => {
      const mockRepo = new MockTokenRepository();
      mockRepo.setTokens(TEST_USER_ID, [
        { id: 'dev_1', user_id: TEST_USER_ID, fcm_token: TEST_TOKEN_1, platform: 'android' },
      ]);
      const mockFcm = new MockFcmHttpClient();
      mockFcm.queueResponse({
        token: TEST_TOKEN_1,
        success: true,
        message_id: 'msg_valid_01',
      });

      const engine = new PushDispatchEngine(mockRepo, mockFcm);
      const summary = await engine.dispatch({
        recipient_user_id: TEST_USER_ID,
        type: 'interest_received',
        actor_name: 'Ananya Sharma',
        metadata: { route: '/interests', id: 'interest_123' },
      });

      assert.equal(summary.total_tokens, 1);
      assert.equal(summary.successful_deliveries, 1);
      assert.equal(summary.failed_deliveries, 0);
      assert.equal(summary.cleaned_tokens, 0);
      assert.equal(mockFcm.sentMessages[0].notification.title, 'New Alliance Interest');
      assert.match(mockFcm.sentMessages[0].notification.body, /Ananya Sharma/);
    });

    test('4b. Transient failure undergoes bounded retry and recovers', async () => {
      const mockRepo = new MockTokenRepository();
      mockRepo.setTokens(TEST_USER_ID, [
        { id: 'dev_1', user_id: TEST_USER_ID, fcm_token: TEST_TOKEN_1, platform: 'android' },
      ]);
      const mockFcm = new MockFcmHttpClient();
      mockFcm.queueResponse({ token: TEST_TOKEN_1, success: false, error_code: 'UNAVAILABLE', is_transient: true });
      mockFcm.queueResponse({ token: TEST_TOKEN_1, success: true, message_id: 'msg_recovered' });

      const engine = new PushDispatchEngine(mockRepo, mockFcm, undefined, 2);
      const summary = await engine.dispatch({
        recipient_user_id: TEST_USER_ID,
        type: 'high_guna_milan',
      });

      assert.equal(mockFcm.callCount, 2);
      assert.equal(summary.successful_deliveries, 1);
      assert.equal(summary.failed_deliveries, 0);
      assert.equal(summary.cleaned_tokens, 0);
    });

    test('4c. Multi-device dispatch sends to all devices and prunes only unregistered ones', async () => {
      const mockRepo = new MockTokenRepository();
      mockRepo.setTokens(TEST_USER_ID, [
        { id: 'dev_1', user_id: TEST_USER_ID, fcm_token: TEST_TOKEN_1, platform: 'android' },
        { id: 'dev_2', user_id: TEST_USER_ID, fcm_token: TEST_TOKEN_2, platform: 'ios' },
      ]);
      const mockFcm = new MockFcmHttpClient();
      mockFcm.queueResponse({ token: TEST_TOKEN_1, success: true, message_id: 'msg_phone_ok' });
      mockFcm.queueResponse({ token: TEST_TOKEN_2, success: false, is_unregistered: true, error_code: 'UNREGISTERED' });

      const engine = new PushDispatchEngine(mockRepo, mockFcm);
      const summary = await engine.dispatch({
        recipient_user_id: TEST_USER_ID,
        type: 'family_action',
        actor_name: 'Father',
      });

      assert.equal(summary.total_tokens, 2);
      assert.equal(summary.successful_deliveries, 1);
      assert.equal(summary.failed_deliveries, 1);
      assert.equal(summary.cleaned_tokens, 1);
      assert.equal(mockRepo.removedTokens.length, 1);
      assert.equal(mockRepo.removedTokens[0].token, TEST_TOKEN_2);

      const remaining = await mockRepo.getTokensForUser(TEST_USER_ID);
      assert.equal(remaining.length, 1);
      assert.equal(remaining[0].fcm_token, TEST_TOKEN_1);
    });

    test('4d. Malformed recipient UUID or unsupported event type is strictly rejected', async () => {
      const mockRepo = new MockTokenRepository();
      const mockFcm = new MockFcmHttpClient();
      const engine = new PushDispatchEngine(mockRepo, mockFcm);

      await assert.rejects(
        async () => {
          await engine.dispatch({ recipient_user_id: 'not-a-valid-uuid', type: 'interest_received' });
        },
        { message: /is not a valid UUID/ }
      );

      await assert.rejects(
        async () => {
          await engine.dispatch({ recipient_user_id: TEST_USER_ID, type: 'unsupported_type' as any });
        },
        { message: /Unsupported notification event type/ }
      );
    });

    test('4e. Safe payload construction sanitizes navigation data and redacts private chat content', () => {
      const chatContent = buildNotificationContent('chat_message', 'Vikram');
      assert.equal(chatContent.title, 'New Message Received');
      assert.equal(chatContent.body, 'Vikram sent you a message.');
      assert.ok(!chatContent.body.includes('Confidential message text'));

      const eventWithSensitiveData: PushNotificationEvent = {
        recipient_user_id: TEST_USER_ID,
        type: 'chat_message',
        metadata: {
          route: '/chat',
          conversation_id: 'conv_12345',
          raw_message_text: 'Should never appear!',
          user_password: 'SecretPassword123',
          phone_number: '+919999999999',
        },
      };

      const navData = buildNavigationData(eventWithSensitiveData);
      assert.equal(navData.route, '/chat');
      assert.equal(navData.conversation_id, 'conv_12345');
      assert.equal(navData.notification_type, 'chat_message');
      assert.equal((navData as any).raw_message_text, undefined);
      assert.equal((navData as any).user_password, undefined);
      assert.equal((navData as any).phone_number, undefined);

      const rawTok = 'fcm_abcdef1234567890abcdef1234567890abcdef9999';
      const masked = maskToken(rawTok);
      assert.equal(masked, 'fcm_abcd...9999');
      assert.ok(!masked.includes('1234567890'));
    });
  });
});
