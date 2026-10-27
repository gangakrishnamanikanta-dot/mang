import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_AUTH_HOOK_SECRET = Deno.env.get("RESEND_AUTH_HOOK_SECRET")!;

async function hashCode(code: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(code + RESEND_AUTH_HOOK_SECRET);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
}

// Allowed origins
const allowedOrigins = [
  "http://localhost:3000",
  "capacitor://localhost",
  "http://localhost",
];

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("origin");
  return {
    "Access-Control-Allow-Origin": (origin && allowedOrigins.includes(origin)) ? origin : "",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const { email, code, purpose } = await req.json();

    if (!email || !code || !purpose) {
      return new Response(
        JSON.stringify({ error: "Email, code, and purpose are required" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const codeHash = await hashCode(code);
    const now = new Date().toISOString();

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Rate limiting: check attempts from this IP AND target email (max 5 failed verifications in 10 min)
    const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
    const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const cleanEmail = email.trim().toLowerCase();

    const { data: recentAttempts } = await supabaseClient
      .from("otp_rate_limits")
      .select("identifier, identifier_type, blocked_until")
      .or(`and(identifier.eq.${clientIp},identifier_type.eq.ip),and(identifier.eq.${cleanEmail},identifier_type.eq.email)`)
      .gte("last_attempt_at", tenMinAgo);

    const ipFailed = recentAttempts?.filter((r: any) => r.identifier_type === "ip" && !r.blocked_until).length || 0;
    const emailFailed = recentAttempts?.filter((r: any) => r.identifier_type === "email" && !r.blocked_until).length || 0;

    if (ipFailed >= 5 || emailFailed >= 5) {
      return new Response(
        JSON.stringify({ error: "Too many failed verification attempts. Please wait 10 minutes or request a new OTP." }),
        { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Record this verification attempt
    await supabaseClient.from("otp_rate_limits").insert([
      { identifier: email, identifier_type: "email" },
      { identifier: clientIp, identifier_type: "ip" },
    ]);

    // Step 1: Find a MATCHING valid (not expired) OTP
    const { data: match } = await supabaseClient
      .from("otps")
      .select("*")
      .eq("email", email)
      .eq("purpose", purpose)
      .eq("code_hash", codeHash)
      .gt("expires_at", now)
      .maybeSingle();

    if (match) {
      // Success! Delete OTP (one-time use) unless it's for reset_password (which needs it again)
      if (purpose !== "reset_password") {
        await supabaseClient.from("otps").delete().eq("id", match.id);
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: "Verification successful",
          purpose: match.purpose,
        }),
        { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Step 2: No match found — check why
    const { data: recentOtp } = await supabaseClient
      .from("otps")
      .select("*")
      .eq("email", email)
      .eq("purpose", purpose)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!recentOtp) {
      return new Response(
        JSON.stringify({ error: "No verification code found. Please request a new one." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    if (recentOtp.expires_at < now) {
      return new Response(
        JSON.stringify({ error: "Verification code has expired. Please request a new one." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Invalid verification code. Please try again." }),
      { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (error) {
    console.error("Server error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});
