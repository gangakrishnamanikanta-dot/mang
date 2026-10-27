/**
 * Idempotency & Deduplication Engine
 * Mangalasutram — Part 2, Task 2.2.3: Final Idempotency Recovery Safety Review
 *
 * Implements persistent atomic and in-memory idempotency stores.
 *
 * SAFETY & RECOVERY POLICY:
 * 1. Tombstone Archival (Zero Memory Loss):
 *    - Completed records past retention window are transitioned to 'tombstone_archived',
 *      stripping their summary payload (saving disk space) while preserving primary key memory.
 *    - Replaying the same idempotency key even days later is strictly blocked (claimed: false).
 * 2. 24-Hour Event Age Gate:
 *    - Events older than 24 hours are rejected at the dispatch engine layer.
 *    - As a result, Tier 2 physical deletion of tombstones older than 30 days is 100% mathematically safe
 *      against replay attacks.
 * 3. Zero Caller Force-Retry Bypass:
 *    - Standard claim_push_idempotency RPC does NOT accept a force_retry flag.
 *    - Ambiguous 'expired_unconfirmed' records can ONLY be recovered via the privileged
 *      admin_recover_unconfirmed_push_idempotency RPC, strictly restricted to service_role.
 * 4. Atomic Row-Level Locking:
 *    - claim_push_idempotency acquires SELECT ... FOR UPDATE to eliminate concurrency races.
 *    - cleanup_expired_push_idempotency acquires FOR UPDATE SKIP LOCKED to ensure active in-flight claims
 *      are never blocked or purged.
 * 5. Production Safety:
 *    - allowFallback defaults to FALSE. In production, persistent storage failures abort dispatch
 *      with PersistentStorageUnavailableError, ensuring zero silent duplicate sends across microVMs.
 */

import type {
  IdempotencyStore,
  IdempotencyClaimResult,
  DispatchSummary,
} from './types.ts';

export class PersistentStorageUnavailableError extends Error {
  constructor(message = 'Persistent idempotency storage is unavailable.') {
    super(message);
    this.name = 'PersistentStorageUnavailableError';
  }
}

export class InMemoryIdempotencyStore implements IdempotencyStore {
  public cache = new Map<
    string,
    {
      status: 'in_flight' | 'completed' | 'expired_unconfirmed' | 'tombstone_archived';
      createdAt: number;
      expiresAt: number;
      summary?: DispatchSummary;
    }
  >();

  async claim(key: string, ttlSeconds: number): Promise<IdempotencyClaimResult> {
    const now = Date.now();
    const existing = this.cache.get(key);

    if (existing) {
      // 1. Tombstone terminal state: Key was already processed and archived. Replay permanently blocked.
      if (existing.status === 'tombstone_archived') {
        return { claimed: false, status: 'tombstone_archived' };
      }

      // 2. Completed key evaluation
      if (existing.status === 'completed') {
        if (now < existing.expiresAt) {
          // Within retention window: deduplicate and return cached summary
          return { claimed: false, status: 'completed', cachedSummary: existing.summary };
        }
        // Retention window elapsed: Transition key to tombstone_archived and purge payload summary
        existing.status = 'tombstone_archived';
        existing.summary = undefined;
        return { claimed: false, status: 'tombstone_archived' };
      }

      // 3. Active in-flight lease
      if (now < existing.expiresAt) {
        return { claimed: false, status: 'in_flight' };
      }

      // 4. Expired in-flight lease (previous isolate crashed or timed out after contacting FCM)
      // Conservative policy: mark as expired_unconfirmed, NEVER blindly redispatch
      existing.status = 'expired_unconfirmed';
      return { claimed: false, status: 'expired_unconfirmed' };
    }

    // Fresh key claim
    this.cache.set(key, {
      status: 'in_flight',
      createdAt: now,
      expiresAt: now + ttlSeconds * 1000,
    });

    return { claimed: true, status: 'in_flight' };
  }

  async adminRecover(key: string, ttlSeconds = 600): Promise<IdempotencyClaimResult> {
    const now = Date.now();
    const existing = this.cache.get(key);

    if (existing && existing.status === 'expired_unconfirmed') {
      existing.status = 'in_flight';
      existing.createdAt = now;
      existing.expiresAt = now + ttlSeconds * 1000;
      existing.summary = undefined;
      return { claimed: true, status: 'in_flight' };
    }

    return { claimed: false, status: existing?.status };
  }

  async complete(key: string, summary: DispatchSummary): Promise<void> {
    const existing = this.cache.get(key);
    if (existing && existing.status === 'in_flight') {
      existing.status = 'completed';
      existing.summary = summary;
    }
  }

  async cleanupExpired(batchSize = 1000): Promise<{
    tombstoned_completed: number;
    tombstoned_unconfirmed: number;
    purged_old_tombstones: number;
  }> {
    const now = Date.now();
    let tombstonedCompleted = 0;
    let tombstonedUnconfirmed = 0;
    let purgedOldTombstones = 0;

    for (const [key, val] of this.cache.entries()) {
      if (tombstonedCompleted + tombstonedUnconfirmed + purgedOldTombstones >= batchSize) break;

      // Tier 1A: Transition completed records past retention into tombstones (stripping payloads)
      if (val.status === 'completed' && now >= val.expiresAt) {
        val.status = 'tombstone_archived';
        val.summary = undefined;
        tombstonedCompleted++;
        continue;
      }

      // Tier 1B: Transition expired_unconfirmed records older than 24h into tombstones
      if (val.status === 'expired_unconfirmed' && now >= val.createdAt + 24 * 3600 * 1000) {
        val.status = 'tombstone_archived';
        val.summary = undefined;
        tombstonedUnconfirmed++;
        continue;
      }

      // Tier 2: Physically delete only tombstones older than 30 days
      if (val.status === 'tombstone_archived' && now >= val.createdAt + 30 * 86400 * 1000) {
        this.cache.delete(key);
        purgedOldTombstones++;
        continue;
      }
    }

    return {
      tombstoned_completed: tombstonedCompleted,
      tombstoned_unconfirmed: tombstonedUnconfirmed,
      purged_old_tombstones: purgedOldTombstones,
    };
  }
}

/**
 * DatabaseIdempotencyStore
 *
 * Connects to PostgreSQL via Supabase atomic RPCs:
 * - claim_push_idempotency(p_key, p_ttl_seconds)
 * - admin_recover_unconfirmed_push_idempotency(p_key, p_ttl_seconds)
 * - complete_push_idempotency(p_key, p_summary)
 * - cleanup_expired_push_idempotency(p_batch_size)
 */
export class DatabaseIdempotencyStore implements IdempotencyStore {
  private supabase: any;
  private allowFallback: boolean;
  private fallbackStore: InMemoryIdempotencyStore;

  constructor(supabaseClient: any, allowFallback = false) {
    this.supabase = supabaseClient;
    this.allowFallback = allowFallback;
    this.fallbackStore = new InMemoryIdempotencyStore();
  }

  async claim(key: string, ttlSeconds: number): Promise<IdempotencyClaimResult> {
    if (!this.supabase) {
      if (this.allowFallback) {
        return this.fallbackStore.claim(key, ttlSeconds);
      }
      throw new PersistentStorageUnavailableError('Database client is not initialized.');
    }

    try {
      const { data, error } = await this.supabase.rpc('claim_push_idempotency', {
        p_key: key,
        p_ttl_seconds: ttlSeconds,
      });

      if (error) {
        // Table or function does not exist (42P01 / 42883)
        if (error.code === '42P01' || error.code === '42883') {
          if (this.allowFallback) {
            console.warn('[IDEMPOTENCY] Table/RPC absent in DB. Explicit dev/test fallback to in-memory store.');
            return this.fallbackStore.claim(key, ttlSeconds);
          }
          throw new PersistentStorageUnavailableError('Persistent idempotency storage schema is not provisioned.');
        }

        if (this.allowFallback) {
          console.warn(`[IDEMPOTENCY] DB error during claim (${error.message}). Falling back to in-memory store.`);
          return this.fallbackStore.claim(key, ttlSeconds);
        }

        throw new PersistentStorageUnavailableError(`Database error during claim: ${error.message}`);
      }

      if (!data) {
        throw new PersistentStorageUnavailableError('Empty response from claim_push_idempotency RPC.');
      }

      // data is jsonb: { claimed: boolean, status: string, summary?: DispatchSummary }
      return {
        claimed: Boolean(data.claimed),
        status: data.status,
        cachedSummary: data.summary ? (data.summary as DispatchSummary) : undefined,
      };
    } catch (err) {
      if (err instanceof PersistentStorageUnavailableError) {
        throw err;
      }
      if (this.allowFallback) {
        console.warn('[IDEMPOTENCY] Unexpected exception during claim. Explicit fallback enabled:', err);
        return this.fallbackStore.claim(key, ttlSeconds);
      }
      throw new PersistentStorageUnavailableError('Persistent idempotency check failed unexpectedly.');
    }
  }

  async adminRecover(key: string, ttlSeconds = 600): Promise<IdempotencyClaimResult> {
    if (!this.supabase) {
      if (this.allowFallback) {
        return this.fallbackStore.adminRecover(key, ttlSeconds);
      }
      throw new PersistentStorageUnavailableError('Database client is not initialized.');
    }

    try {
      const { data, error } = await this.supabase.rpc('admin_recover_unconfirmed_push_idempotency', {
        p_key: key,
        p_ttl_seconds: ttlSeconds,
      });

      if (error) {
        throw new PersistentStorageUnavailableError(`Database error during admin recover: ${error.message}`);
      }

      return {
        claimed: Boolean(data?.recovered),
        status: data?.status,
      };
    } catch (err) {
      if (err instanceof PersistentStorageUnavailableError) throw err;
      throw new PersistentStorageUnavailableError('Persistent admin recover failed unexpectedly.');
    }
  }

  async complete(key: string, summary: DispatchSummary): Promise<void> {
    if (!this.supabase) {
      if (this.allowFallback) {
        return this.fallbackStore.complete(key, summary);
      }
      throw new PersistentStorageUnavailableError('Database client is not initialized.');
    }

    try {
      const { error } = await this.supabase.rpc('complete_push_idempotency', {
        p_key: key,
        p_summary: summary,
      });

      if (error) {
        if (this.allowFallback) {
          console.warn(`[IDEMPOTENCY] DB error during complete (${error.message}). Falling back.`);
          return this.fallbackStore.complete(key, summary);
        }
        throw new PersistentStorageUnavailableError(`Database error during completion: ${error.message}`);
      }
    } catch (err) {
      if (err instanceof PersistentStorageUnavailableError) {
        throw err;
      }
      if (this.allowFallback) {
        return this.fallbackStore.complete(key, summary);
      }
      throw new PersistentStorageUnavailableError('Persistent idempotency completion failed unexpectedly.');
    }
  }

  async cleanupExpired(batchSize = 1000): Promise<{
    tombstoned_completed: number;
    tombstoned_unconfirmed: number;
    purged_old_tombstones: number;
  }> {
    if (!this.supabase) {
      if (this.allowFallback) {
        return this.fallbackStore.cleanupExpired(batchSize);
      }
      throw new PersistentStorageUnavailableError('Database client is not initialized.');
    }

    try {
      const { data, error } = await this.supabase.rpc('cleanup_expired_push_idempotency', {
        p_batch_size: batchSize,
      });

      if (error) {
        if (this.allowFallback) {
          return this.fallbackStore.cleanupExpired(batchSize);
        }
        throw new PersistentStorageUnavailableError(`Database error during cleanup: ${error.message}`);
      }

      return data || { tombstoned_completed: 0, tombstoned_unconfirmed: 0, purged_old_tombstones: 0 };
    } catch (err) {
      if (err instanceof PersistentStorageUnavailableError) {
        throw err;
      }
      if (this.allowFallback) {
        return this.fallbackStore.cleanupExpired(batchSize);
      }
      throw new PersistentStorageUnavailableError('Persistent idempotency cleanup failed unexpectedly.');
    }
  }
}
