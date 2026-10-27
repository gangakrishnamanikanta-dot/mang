/**
 * FCM HTTP v1 Client & Service Account Authentication
 * Mangalasutram — Part 2, Task 2.2
 *
 * Implements RFC 7519 / RFC 7523 Google OAuth2 JWT assertion exchange.
 * Strictly uses Web Crypto API (crypto.subtle) without native Node/Deno crypto bindings.
 */

import type { FcmHttpClient, FcmMessagePayload, FcmSendResult } from './types.ts';

export interface FirebaseCredentials {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

export function loadFirebaseCredentials(): {
  credentials?: FirebaseCredentials;
  missingKeys: string[];
} {
  // Support either full JSON string in FIREBASE_SERVICE_ACCOUNT or split variables
  const getEnv = (key: string): string | undefined => {
    try {
      // Deno environment
      if (typeof Deno !== 'undefined' && Deno.env) {
        return Deno.env.get(key) || undefined;
      }
    } catch (_) {
      // ignore
    }
    try {
      // Node environment fallback
      if (typeof process !== 'undefined' && process.env) {
        return process.env[key] || undefined;
      }
    } catch (_) {
      // ignore
    }
    return undefined;
  };

  const rawJson = getEnv('FIREBASE_SERVICE_ACCOUNT') || getEnv('FIREBASE_SERVICE_ACCOUNT_KEY');
  if (rawJson) {
    try {
      const parsed = JSON.parse(rawJson);
      if (parsed.project_id && parsed.client_email && parsed.private_key) {
        return {
          credentials: {
            projectId: parsed.project_id,
            clientEmail: parsed.client_email,
            privateKey: parsed.private_key,
          },
          missingKeys: [],
        };
      }
    } catch (_) {
      // Failed to parse, fall through to separate keys
    }
  }

  const projectId = getEnv('FIREBASE_PROJECT_ID') || 'mangalasutram-app';
  const clientEmail = getEnv('FIREBASE_CLIENT_EMAIL');
  const privateKey = getEnv('FIREBASE_PRIVATE_KEY');

  const missingKeys: string[] = [];
  if (!clientEmail) missingKeys.push('FIREBASE_CLIENT_EMAIL');
  if (!privateKey) missingKeys.push('FIREBASE_PRIVATE_KEY');

  if (missingKeys.length > 0) {
    return { missingKeys };
  }

  return {
    credentials: {
      projectId,
      clientEmail: clientEmail!,
      privateKey: privateKey!,
    },
    missingKeys: [],
  };
}

let cachedAccessToken: string | null = null;
let tokenExpiresAt = 0;

function base64UrlEncode(str: string): string {
  const bytes = new TextEncoder().encode(str);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function base64UrlEncodeBytes(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function pemToBinary(pem: string): Uint8Array {
  const cleanPem = pem
    .replace(/-----BEGIN [A-Z ]+-----/g, '')
    .replace(/-----END [A-Z ]+-----/g, '')
    .replace(/\s+/g, '');
  const raw = atob(cleanPem);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    bytes[i] = raw.charCodeAt(i);
  }
  return bytes;
}

export async function getGoogleOAuthAccessToken(
  creds: FirebaseCredentials
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // Return cached token if valid for at least 5 more minutes
  if (cachedAccessToken && tokenExpiresAt > now + 300) {
    return cachedAccessToken;
  }

  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  const claimSet = {
    iss: creds.clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaim = base64UrlEncode(JSON.stringify(claimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaim}`;

  const keyBytes = pemToBinary(creds.privateKey);
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes.buffer as ArrayBuffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signedJwt = `${unsignedToken}.${base64UrlEncodeBytes(new Uint8Array(signature))}`;

  // Exchange JWT assertion for OAuth access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: signedJwt,
    }).toString(),
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`Failed to obtain Google OAuth access token: ${errorText}`);
  }

  const data = await tokenResponse.json();
  cachedAccessToken = data.access_token;
  tokenExpiresAt = now + (data.expires_in || 3600);

  return cachedAccessToken!;
}

export function parseFcmErrorResponse(
  status: number,
  errorJson: any
): { errorCode: string; isUnregistered: boolean; isTransient: boolean } {
  let errorCode = `HTTP_${status}`;
  let isUnregistered = false;
  // Transient failures suitable for bounded retry
  const isTransient = status === 429 || status === 500 || status === 503;

  if (errorJson && errorJson.error) {
    if (errorJson.error.status) {
      errorCode = errorJson.error.status;
    }
    const details = errorJson.error.details || [];
    for (const d of details) {
      if (
        d['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError' &&
        d.errorCode
      ) {
        errorCode = d.errorCode;
      }
    }
  }

  // CRITICAL SECURITY & RELIABILITY:
  // FCM HTTP v1 definitive unregistration occurs ONLY when the FcmError detail
  // explicitly specifies errorCode = 'UNREGISTERED'.
  // Tokens are NEVER pruned on generic 404 (endpoint/project not found), 400 (bad argument),
  // 401 (auth failure), 403 (permission denied), or 5xx (transient gateway error).
  if (errorCode === 'UNREGISTERED') {
    isUnregistered = true;
  }

  return { errorCode, isUnregistered, isTransient };
}

export class HttpFcmClient implements FcmHttpClient {
  private creds: FirebaseCredentials;

  constructor(creds: FirebaseCredentials) {
    this.creds = creds;
  }

  async send(message: FcmMessagePayload): Promise<FcmSendResult> {
    const token = await getGoogleOAuthAccessToken(this.creds);
    const url = `https://fcm.googleapis.com/v1/projects/${this.creds.projectId}/messages:send`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ message }),
    });

    if (response.ok) {
      const data = await response.json();
      return {
        token: message.token,
        success: true,
        message_id: data.name,
      };
    }

    const status = response.status;
    let parsed = {
      errorCode: `HTTP_${status}`,
      isUnregistered: false,
      isTransient: status === 429 || status === 500 || status === 503,
    };

    try {
      const errorJson = await response.json();
      parsed = parseFcmErrorResponse(status, errorJson);
    } catch (_) {
      // Non-json response
    }

    return {
      token: message.token,
      success: false,
      error_code: parsed.errorCode,
      is_unregistered: parsed.isUnregistered,
      is_transient: parsed.isTransient,
    };
  }
}

