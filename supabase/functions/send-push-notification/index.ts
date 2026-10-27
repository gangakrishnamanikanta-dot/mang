/**
 * Supabase Edge Function: send-push-notification
 * Mangalasutram — Part 2, Task 2.2: Secure FCM Push Dispatch Foundation
 *
 * Security Directives:
 * 1. Strictly internal server-side invocation. Protected by SUPABASE_SERVICE_ROLE_KEY or PUSH_DISPATCH_SECRET.
 * 2. Never accepts arbitrary FCM tokens or unverified recipient IDs from client callers.
 * 3. Sanitized navigation payloads — zero PII, passwords, or confidential chat bodies in notification data.
 * 4. Automatic invalid/unregistered token purging on definitive FCM errors.
 * 5. Bounded retries and idempotency deduplication.
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import type {
  PushNotificationEvent,
  TokenRepository,
  DeviceTokenRecord,
} from "./types.ts";
import {
  loadFirebaseCredentials,
  HttpFcmClient,
} from "./fcm_auth.ts";
import {
  PushDispatchEngine,
  maskToken,
} from "./dispatch_engine.ts";
import { validatePushDispatchAuth } from "./auth_validator.ts";
import {
  DatabaseIdempotencyStore,
  PersistentStorageUnavailableError,
} from "./idempotency.ts";


class SupabaseTokenRepository implements TokenRepository {
  private supabase: any;

  constructor(supabase: any) {
    this.supabase = supabase;
  }

  async getTokensForUser(userId: string): Promise<DeviceTokenRecord[]> {
    const { data, error } = await this.supabase
      .from("device_tokens")
      .select("id, user_id, fcm_token, platform, device_info")
      .eq("user_id", userId);

    if (error) {
      console.error(`[PUSH_DISPATCH] Failed to fetch device tokens: ${error.message}`);
      return [];
    }

    return (data || []) as DeviceTokenRecord[];
  }

  async removeToken(fcmToken: string, userId: string): Promise<boolean> {
    console.log(`[PUSH_DISPATCH] Purging invalid/unregistered token ${maskToken(fcmToken)} for user ${userId}`);
    const { error } = await this.supabase
      .from("device_tokens")
      .delete()
      .eq("fcm_token", fcmToken)
      .eq("user_id", userId);

    if (error) {
      console.error(`[PUSH_DISPATCH] Error removing invalid token: ${error.message}`);
      return false;
    }
    return true;
  }
}

serve(async (req: Request) => {
  // Only accept POST requests
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type, x-client-info",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    // 1. Authorization: Only allow internal trusted server-side callers via dedicated PUSH_DISPATCH_SECRET
    const pushSecret = Deno.env.get("PUSH_DISPATCH_SECRET");
    const authResult = validatePushDispatchAuth(req.headers.get("Authorization"), pushSecret);

    if (!authResult.authorized) {
      return new Response(
        JSON.stringify({ error: authResult.errorMessage }),
        { status: authResult.errorStatus || 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // 2. Parse and validate push event payload
    const body = await req.json();
    const event: PushNotificationEvent = {
      recipient_user_id: body.recipient_user_id,
      type: body.type,
      actor_name: body.actor_name,
      metadata: body.metadata,
      idempotency_key: body.idempotency_key,
    };

    if (!event.recipient_user_id || !event.type) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: recipient_user_id and type are required." }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // 3. Load Firebase credentials
    const { credentials, missingKeys } = loadFirebaseCredentials();
    if (!credentials) {
      console.warn(`[PUSH_DISPATCH] Missing Firebase credentials: ${missingKeys.join(", ")}`);
      return new Response(
        JSON.stringify({
          error: "Push dispatch service unconfigured.",
          missing_configuration: missingKeys,
        }),
        { status: 503, headers: { "Content-Type": "application/json" } }
      );
    }

    // 4. Initialize Supabase Admin client and repositories
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
    const tokenRepo = new SupabaseTokenRepository(supabaseAdmin);
    // In production, allowFallback defaults to FALSE to prevent unsafe in-memory degradation across isolates
    const allowFallback = Deno.env.get("ALLOW_IN_MEMORY_IDEMPOTENCY_FALLBACK") === "true";
    const idempotencyStore = new DatabaseIdempotencyStore(supabaseAdmin, allowFallback);
    const fcmClient = new HttpFcmClient(credentials);
    const engine = new PushDispatchEngine(tokenRepo, fcmClient, idempotencyStore);

    // 5. Execute secure dispatch
    const summary = await engine.dispatch(event);

    return new Response(JSON.stringify({ success: true, summary }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: any) {
    if (
      error instanceof PersistentStorageUnavailableError ||
      error.name === "PersistentStorageUnavailableError"
    ) {
      console.error("[PUSH_DISPATCH] Persistent idempotency failure:", error.message);
      return new Response(
        JSON.stringify({ error: "Push dispatch service temporarily unavailable due to storage configuration." }),
        { status: 503, headers: { "Content-Type": "application/json" } }
      );
    }

    console.error(`[PUSH_DISPATCH] Unexpected error: ${error.message || error}`);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
});
