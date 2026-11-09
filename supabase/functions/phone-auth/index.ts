import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MSG91_WIDGET_ID = Deno.env.get("MSG91_WIDGET_ID") || "366b62693452303433313336";
const MSG91_AUTH_TOKEN = Deno.env.get("MSG91_AUTH_TOKEN") || "586282TgAlDShmz0jX6ae8a40dP1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function sanitizePhone(rawPhone: string): string {
  let clean = String(rawPhone || "").replace(/\D/g, "");
  if (clean.startsWith("0")) clean = clean.substring(1);
  if (clean.startsWith("91") && clean.length === 12) {
    clean = clean.substring(2);
  }
  return clean;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const action = body.action || (body.otp ? "verify" : "send");
    const { phone, reqId, otp, retryChannel } = body;

    const cleanPhone = sanitizePhone(phone);
    if (!cleanPhone || cleanPhone.length !== 10 || !/^[6-9]\d{9}$/.test(cleanPhone)) {
      return new Response(
        JSON.stringify({ error: "Please enter a valid 10-digit Indian mobile number" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";

    // =========================================================================
    // ACTION 1: SEND OTP (Server-Mediated MSG91 Dispatch with Anti-Abuse Rate Limiting)
    // =========================================================================
    if (action === "send") {
      const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
      const oneMinAgo = new Date(Date.now() - 60 * 1000).toISOString();

      // 1. Enforce 60-second cooldown between sends for the same phone
      const { data: recentSends } = await supabaseClient
        .from("otp_rate_limits")
        .select("last_attempt_at")
        .eq("identifier", cleanPhone)
        .eq("identifier_type", "phone_send")
        .gte("last_attempt_at", oneMinAgo)
        .limit(1);

      if (recentSends && recentSends.length > 0) {
        return new Response(
          JSON.stringify({ error: "Please wait 60 seconds before requesting another SMS OTP." }),
          { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      // 2. Enforce max 4 sends per 10 minutes per phone
      const { data: phoneTenMinSends } = await supabaseClient
        .from("otp_rate_limits")
        .select("id")
        .eq("identifier", cleanPhone)
        .eq("identifier_type", "phone_send")
        .gte("last_attempt_at", tenMinAgo);

      if (phoneTenMinSends && phoneTenMinSends.length >= 4) {
        return new Response(
          JSON.stringify({ error: "Too many SMS requests for this number. Please wait 10 minutes." }),
          { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      // 3. Enforce max 12 sends per 10 minutes per IP
      const { data: ipTenMinSends } = await supabaseClient
        .from("otp_rate_limits")
        .select("id")
        .eq("identifier", clientIp)
        .eq("identifier_type", "ip_send")
        .gte("last_attempt_at", tenMinAgo);

      if (ipTenMinSends && ipTenMinSends.length >= 12) {
        return new Response(
          JSON.stringify({ error: "Too many requests from this network. Please try again later." }),
          { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      // 4. Dispatch SMS OTP via MSG91 Mobile Widget API
      const msg91SendUrl = "https://control.msg91.com/api/v5/widget/sendOtpMobile";
      const sendPayload = {
        widgetId: MSG91_WIDGET_ID,
        tokenAuth: MSG91_AUTH_TOKEN,
        identifier: `91${cleanPhone}`,
      };

      const msg91Res = await fetch(msg91SendUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body: JSON.stringify(sendPayload),
        redirect: "follow",
      });

      const msg91Text = await msg91Res.text();
      let msg91Data: any = {};
      try {
        msg91Data = JSON.parse(msg91Text);
      } catch (_) {}

      const isSuccess =
        msg91Data.type === "success" ||
        msg91Res.status === 200 ||
        (typeof msg91Data.message === "string" && msg91Data.message.length > 10);

      if (!isSuccess) {
        console.error("[phone-auth send error]:", msg91Data);
        return new Response(
          JSON.stringify({ error: msg91Data.message || "Failed to dispatch SMS OTP. Please try again." }),
          { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      // Record successful send for rate limiting
      await supabaseClient.from("otp_rate_limits").insert([
        { identifier: cleanPhone, identifier_type: "phone_send" },
        { identifier: clientIp, identifier_type: "ip_send" },
      ]);

      const dispatchedReqId = msg91Data.message || msg91Data.reqId || msg91Data.data?.reqId || "";

      return new Response(
        JSON.stringify({
          success: true,
          reqId: dispatchedReqId,
          message: "SMS OTP dispatched successfully.",
        }),
        { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // =========================================================================
    // ACTION 2: RESEND / RETRY OTP
    // =========================================================================
    if (action === "resend" || action === "retry") {
      if (!reqId) {
        return new Response(
          JSON.stringify({ error: "reqId is required to resend OTP" }),
          { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      const msg91RetryUrl = "https://control.msg91.com/api/v5/widget/retryOtp";
      const retryPayload = {
        widgetId: MSG91_WIDGET_ID,
        tokenAuth: MSG91_AUTH_TOKEN,
        reqId: String(reqId).trim(),
        retryChannel: retryChannel || 11, // 11 = SMS
      };

      const msg91Res = await fetch(msg91RetryUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body: JSON.stringify(retryPayload),
        redirect: "follow",
      });

      const msg91Text = await msg91Res.text();
      let msg91Data: any = {};
      try {
        msg91Data = JSON.parse(msg91Text);
      } catch (_) {}

      const isSuccess =
        msg91Data.type === "success" ||
        msg91Res.status === 200 ||
        (typeof msg91Data.message === "string" && !msg91Data.message.toLowerCase().includes("error"));

      if (!isSuccess) {
        return new Response(
          JSON.stringify({ error: msg91Data.message || "Failed to resend SMS OTP." }),
          { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          reqId: String(reqId).trim(),
          message: "SMS OTP resent successfully.",
        }),
        { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // =========================================================================
    // ACTION 3: VERIFY OTP & SESSION PROVISIONING
    // =========================================================================
    if (!reqId || !otp) {
      return new Response(
        JSON.stringify({ error: "Both reqId and 6-digit OTP code are required for verification." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // 1. Anti-Brute-Force Rate Limiting (Max 5 failed attempts in 10 minutes)
    const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const { data: recentAttempts } = await supabaseClient
      .from("otp_rate_limits")
      .select("id")
      .or(`and(identifier.eq.${clientIp},identifier_type.eq.ip),and(identifier.eq.${cleanPhone},identifier_type.eq.phone)`)
      .gte("last_attempt_at", tenMinAgo);

    if (recentAttempts && recentAttempts.length >= 5) {
      return new Response(
        JSON.stringify({ error: "Too many failed attempts. Please wait 10 minutes before retrying." }),
        { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // 2. Verify OTP with MSG91 Mobile Widget API
    const msg91VerifyUrl = "https://control.msg91.com/api/v5/widget/verifyOtp";
    const msg91Res = await fetch(msg91VerifyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify({
        widgetId: MSG91_WIDGET_ID,
        tokenAuth: MSG91_AUTH_TOKEN,
        reqId: String(reqId).trim(),
        otp: String(otp).trim(),
      }),
      redirect: "follow",
    });

    const msg91Text = await msg91Res.text();
    let msg91Data: any = {};
    try {
      msg91Data = JSON.parse(msg91Text);
    } catch (_) {}

    const isSuccess =
      msg91Data.type === "success" ||
      (typeof msg91Data.message === "string" &&
        msg91Data.message.toLowerCase().includes("success"));

    if (!isSuccess) {
      // Record failed verification attempt for rate limiting
      await supabaseClient.from("otp_rate_limits").insert([
        { identifier: cleanPhone, identifier_type: "phone" },
        { identifier: clientIp, identifier_type: "ip" },
      ]);

      const errMsg = msg91Data.message || "Invalid or expired OTP. Please try again.";
      return new Response(
        JSON.stringify({ error: errMsg }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // 3. Clear rate limits on successful verification
    await supabaseClient
      .from("otp_rate_limits")
      .delete()
      .or(`identifier.eq.${cleanPhone},identifier.eq.${clientIp}`);

    // 4. Intelligent Account Matching: Safe lookup without .maybeSingle() crash on duplicates
    const formattedPhone = `+91${cleanPhone}`;
    const syntheticEmail = `phone_${cleanPhone}@phone.mangalsutram.in`;

    const { data: matchedProfiles } = await supabaseClient
      .from("profiles")
      .select("id, email, phone")
      .or(`phone.eq.${cleanPhone},phone.eq.${formattedPhone},phone.eq.91${cleanPhone},phone.eq.0${cleanPhone}`)
      .order("created_at", { ascending: false })
      .limit(1);

    const existingProfile = matchedProfiles && matchedProfiles.length > 0 ? matchedProfiles[0] : null;

    let targetEmail = syntheticEmail;
    let userId: string | null = null;

    if (existingProfile && existingProfile.email && existingProfile.email.includes("@")) {
      targetEmail = existingProfile.email.trim();
      userId = existingProfile.id;
    } else if (existingProfile) {
      userId = existingProfile.id;
    } else {
      // Check auth.users for existing account under synthetic email
      const { data: existingUid } = await supabaseClient.rpc(
        "get_auth_user_id_by_email",
        { p_email: syntheticEmail }
      );
      if (existingUid) {
        userId = existingUid;
      }
    }

    // 5. Provision auth user if not present
    if (!userId) {
      const { data: newUser, error: createErr } =
        await supabaseClient.auth.admin.createUser({
          email: syntheticEmail,
          email_confirm: true,
          user_metadata: {
            phone: cleanPhone,
            is_phone_verified: true,
          },
        });

      if (createErr && !newUser?.user) {
        console.error("Supabase user creation error:", createErr);
        const { data: retryUid } = await supabaseClient.rpc(
          "get_auth_user_id_by_email",
          { p_email: syntheticEmail }
        );
        userId = retryUid;
      } else {
        userId = newUser?.user?.id ?? null;
      }
    }

    if (!userId) {
      return new Response(
        JSON.stringify({ error: "Failed to provision authentication account" }),
        { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // 6. Ensure profile record exists
    const { data: checkProfList } = await supabaseClient
      .from("profiles")
      .select("id, phone")
      .eq("id", userId)
      .limit(1);

    const checkProf = checkProfList && checkProfList.length > 0 ? checkProfList[0] : null;

    if (!checkProf) {
      await supabaseClient.from("profiles").upsert(
        {
          id: userId,
          phone: cleanPhone,
          account_type: "candidate",
          terms_accepted: true,
        },
        { onConflict: "id" }
      );
    } else if (!checkProf.phone || checkProf.phone.trim() === "") {
      await supabaseClient
        .from("profiles")
        .update({ phone: cleanPhone })
        .eq("id", userId);
    }

    // 7. Generate one-time session token via magiclink for targetEmail
    const { data: linkData, error: linkErr } =
      await supabaseClient.auth.admin.generateLink({
        type: "magiclink",
        email: targetEmail,
      });

    if (linkErr || !linkData?.properties?.email_otp) {
      console.error("generateLink error:", linkErr);
      return new Response(
        JSON.stringify({ error: "Failed to generate session credential" }),
        { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        email: targetEmail,
        token: linkData.properties.email_otp,
        userId: userId,
        phone: cleanPhone,
      }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (error: any) {
    console.error("[phone-auth] Server error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});
