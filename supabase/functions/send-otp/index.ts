import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const RESEND_AUTH_HOOK_SECRET = Deno.env.get("RESEND_AUTH_HOOK_SECRET")!;
const FROM_EMAIL = "Mangalasutram <noreply@send.mangalsutram.me>";

function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

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
    const { email, purpose } = await req.json();

    if (!email || !purpose) {
      return new Response(
        JSON.stringify({ error: "Email and purpose are required" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    if (!["signup", "reset_password", "verify_email"].includes(purpose)) {
      return new Response(
        JSON.stringify({ error: "Invalid purpose. Must be signup, reset_password, or verify_email" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Anti-Bot: Block disposable/throwaway email domains
    const DISPOSABLE_DOMAINS = new Set([
      "mailinator.com", "guerrillamail.com", "10minutemail.com", "tempmail.com",
      "trashmail.com", "yopmail.com", "dispostable.com", "sharklasers.com",
      "getnada.com", "burnermail.io", "fakemailgenerator.com", "temp-mail.org",
      "disposablemail.com", "throwawaymail.com", "generator.email"
    ]);
    const emailDomain = email.split("@")[1]?.toLowerCase()?.trim();
    if (emailDomain && DISPOSABLE_DOMAINS.has(emailDomain)) {
      return new Response(
        JSON.stringify({ error: "Temporary and disposable email addresses are not permitted." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // 2. Global Platform Circuit Breaker (protects against distributed proxy bot swarms)
    const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    const { count: globalRecentOtpCount } = await supabaseClient
      .from("otp_rate_limits")
      .select("*", { count: "exact", head: true })
      .gte("last_attempt_at", fiveMinAgo);

    if (globalRecentOtpCount && globalRecentOtpCount > 300) {
      console.warn(`[CIRCUIT BREAKER]: Global OTP volume spike detected: ${globalRecentOtpCount} requests in 5m.`);
      return new Response(
        JSON.stringify({ error: "System is experiencing unusually high traffic. Please try again shortly." }),
        { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // 3. Anti-Enumeration: For password reset, if account does not exist, return uniform response with calibrated timing
    if (purpose === "reset_password") {
      const { data: profile } = await supabaseClient
        .from("profiles")
        .select("id")
        .eq("email", email)
        .maybeSingle();

      if (!profile) {
        // Calibrated timing delay to match normal hashing + db write execution time
        await new Promise((resolve) => setTimeout(resolve, 150));
        return new Response(
          JSON.stringify({
            success: true,
            message: "If this email is registered, a verification code has been dispatched.",
            expires_in_minutes: 15,
          }),
          { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }
    }

    // 4. Rate limiting via otp_rate_limits table
    const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";

    // Check per-email limits (max 3 OTPs in 10 minutes)
    const { data: emailLimits } = await supabaseClient
      .from("otp_rate_limits")
      .select("*")
      .eq("identifier", email)
      .eq("identifier_type", "email")
      .order("last_attempt_at", { ascending: false })
      .limit(5);

    const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const recentEmailAttempts = emailLimits?.filter(
      (r: any) => r.last_attempt_at > tenMinAgo && !r.blocked_until
    ) || [];

    if (recentEmailAttempts.length >= 3) {
      const oldest = recentEmailAttempts[recentEmailAttempts.length - 1];
      const blockUntil = new Date(oldest.first_attempt_at).getTime() + 10 * 60 * 1000;
      const remainingMin = Math.max(1, Math.ceil((blockUntil - Date.now()) / 60000));

      return new Response(
        JSON.stringify({ error: `Too many OTP requests. Please try again in ${remainingMin} minutes.` }),
        { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Check per-IP limits (max 10 OTPs in 10 minutes)
    const { data: ipLimits } = await supabaseClient
      .from("otp_rate_limits")
      .select("*")
      .eq("identifier", clientIp)
      .eq("identifier_type", "ip")
      .order("last_attempt_at", { ascending: false })
      .limit(15);

    const recentIpAttempts = ipLimits?.filter(
      (r: any) => r.last_attempt_at > tenMinAgo && !r.blocked_until
    ) || [];

    if (recentIpAttempts.length >= 10) {
      const oldest = recentIpAttempts[recentIpAttempts.length - 1];
      const blockUntil = new Date(oldest.first_attempt_at).getTime() + 10 * 60 * 1000;
      const remainingMin = Math.max(1, Math.ceil((blockUntil - Date.now()) / 60000));

      return new Response(
        JSON.stringify({ error: `Too many requests from this network. Please try again in ${remainingMin} minutes.` }),
        { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Record OTP attempt for rate limiting
    await supabaseClient.from("otp_rate_limits").insert([
      { identifier: email, identifier_type: "email" },
      { identifier: clientIp, identifier_type: "ip" },
    ]);

    // 60-second cooldown between sends (secondary check using otps table)
    const { data: recentOtp } = await supabaseClient
      .from("otps")
      .select("created_at")
      .eq("email", email)
      .eq("purpose", purpose)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (recentOtp?.created_at) {
      const lastSent = new Date(recentOtp.created_at).getTime();
      const secondsSinceLast = (Date.now() - lastSent) / 1000;

      if (secondsSinceLast < 60) {
        return new Response(
          JSON.stringify({ error: "Please wait 60 seconds before requesting another OTP" }),
          { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }
    }

    // Generate OTP
    const otpCode = generateOTP();
    const codeHash = await hashCode(otpCode);
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString(); // 15 minutes

    // Delete any existing OTPs for this email + purpose
    await supabaseClient
      .from("otps")
      .delete()
      .eq("email", email)
      .eq("purpose", purpose);

    // Store hashed OTP in database
    const { error: dbError } = await supabaseClient
      .from("otps")
      .insert({
        email,
        code_hash: codeHash,
        purpose,
        expires_at: expiresAt,
      });

    if (dbError) {
      console.error("Database error:", dbError);
      return new Response(
        JSON.stringify({ error: "Failed to store OTP. Please try again." }),
        { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Send OTP email via Resend
    const emailContent = purpose === "reset_password"
      ? {
          subject: "Reset your Mangalasutram password",
          html: `
            <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
              <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
              <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

              <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">Reset Your Password</h2>
              <p style="color: #666; line-height: 1.6; margin-bottom: 30px;">
                You requested to reset your password. Use the verification code below to proceed.
              </p>

              <div style="background: #FFF8F0; border: 2px dashed #D4AF37; padding: 30px; border-radius: 8px; margin: 30px 0;">
                <p style="color: #999; font-size: 12px; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 10px;">Your verification code</p>
                <div style="font-size: 36px; font-weight: bold; color: #8B0000; letter-spacing: 8px; font-family: monospace;">
                  ${otpCode}
                </div>
              </div>

              <p style="color: #999; font-size: 13px; margin-top: 30px;">
                This code will expire in 15 minutes.<br>
                Do not share this code with anyone.
              </p>

              <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
                <p style="color: #ccc; font-size: 10px;">You received this email because a password reset was requested for your account.</p>
              </div>
            </div>
          `,
        }
      : purpose === "verify_email"
      ? {
          subject: "Verify your Mangalasutram email",
          html: `
            <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
              <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
              <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

              <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">Verify Your Email</h2>
              <p style="color: #666; line-height: 1.6; margin-bottom: 30px;">
                Please verify your email address to complete your registration.
              </p>

              <div style="background: #FFF8F0; border: 2px dashed #D4AF37; padding: 30px; border-radius: 8px; margin: 30px 0;">
                <p style="color: #999; font-size: 12px; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 10px;">Your verification code</p>
                <div style="font-size: 36px; font-weight: bold; color: #8B0000; letter-spacing: 8px; font-family: monospace;">
                  ${otpCode}
                </div>
              </div>

              <p style="color: #999; font-size: 13px; margin-top: 30px;">
                This code will expire in 15 minutes.<br>
                Do not share this code with anyone.
              </p>

              <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
                <p style="color: #ccc; font-size: 10px;">You received this email because you registered on Mangalasutram.</p>
              </div>
            </div>
          `,
        }
      : {
          subject: "Welcome to Mangalasutram - Verify Your Email",
          html: `
            <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
              <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
              <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

              <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">Welcome to Mangalasutram</h2>
              <p style="color: #666; line-height: 1.6; margin-bottom: 30px;">
                Thank you for beginning your journey with us. Please use the sacred code below to verify your email address and complete your profile.
              </p>

              <div style="background: #FFF8F0; border: 2px dashed #D4AF37; padding: 30px; border-radius: 8px; margin: 30px 0;">
                <p style="color: #999; font-size: 12px; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 10px;">Your verification code</p>
                <div style="font-size: 36px; font-weight: bold; color: #8B0000; letter-spacing: 8px; font-family: monospace;">
                  ${otpCode}
                </div>
              </div>

              <p style="color: #999; font-size: 13px; margin-top: 30px;">
                This code will expire in 15 minutes.<br>
                Do not share this code with anyone.
              </p>

              <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
                <p style="color: #ccc; font-size: 10px;">You received this email because of a request made to your account.</p>
              </div>
            </div>
          `,
        };

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: email,
        subject: emailContent.subject,
        html: emailContent.html,
      }),
    });

    if (!resendResponse.ok) {
      const error = await resendResponse.text();
      console.error("Resend error:", error);

      // Clean up OTP from DB if email fails
      await supabaseClient
        .from("otps")
        .delete()
        .eq("email", email)
        .eq("purpose", purpose);

      return new Response(
        JSON.stringify({ error: "Failed to send email. Please try again." }),
        { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "OTP sent successfully",
        expires_in_minutes: 15,
      }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (error) {
    console.error("Server error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});
