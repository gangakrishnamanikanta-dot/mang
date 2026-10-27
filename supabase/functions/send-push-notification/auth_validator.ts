/**
 * Endpoint Authorization Validator
 * Mangalasutram — Part 2, Task 2.2
 *
 * Enforces a dedicated PUSH_DISPATCH_SECRET for internal push dispatch invocations.
 * SUPABASE_SERVICE_ROLE_KEY is intentionally NOT accepted as an endpoint caller secret.
 */

export function timingSafeEqual(a: string, b: string): boolean {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const enc = new TextEncoder();
  const aBuf = enc.encode(a);
  const bBuf = enc.encode(b);
  if (aBuf.byteLength !== bBuf.byteLength) return false;
  let diff = 0;
  for (let i = 0; i < aBuf.byteLength; i++) {
    diff |= aBuf[i] ^ bBuf[i];
  }
  return diff === 0;
}

export interface AuthValidationResult {
  authorized: boolean;
  errorStatus?: number;
  errorMessage?: string;
}

export function validatePushDispatchAuth(
  authHeader: string | null,
  pushDispatchSecret: string | undefined
): AuthValidationResult {
  if (!pushDispatchSecret || pushDispatchSecret.trim().length === 0) {
    return {
      authorized: false,
      errorStatus: 500,
      errorMessage: 'Server misconfiguration: PUSH_DISPATCH_SECRET is not configured on this server.',
    };
  }

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return {
      authorized: false,
      errorStatus: 401,
      errorMessage: 'Unauthorized: Missing or malformed Authorization header.',
    };
  }

  const token = authHeader.replace('Bearer ', '').trim();

  // Strict constant-time comparison against PUSH_DISPATCH_SECRET only.
  // Note: SUPABASE_SERVICE_ROLE_KEY is deliberately NOT accepted here.
  if (!timingSafeEqual(token, pushDispatchSecret.trim())) {
    return {
      authorized: false,
      errorStatus: 401,
      errorMessage: 'Unauthorized: Invalid dispatch credentials.',
    };
  }

  return { authorized: true };
}
