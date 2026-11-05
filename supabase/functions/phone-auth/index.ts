import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MSG91_WIDGET_ID = Deno.env.get("MSG91_WIDGET_ID") || "366b62693452303433313336";
const MSG91_AUTH_TOKEN = Deno.env.get("MSG91_AUTH_TOKEN") || "586282TgAlDShmz0jX6ae8a40dP1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone, reqId, otp } = await req.json();

    if (!phone || !reqId || !otp) {
      return new Response(
        JSON.stringify({ error: "Phone number, reqId, and OTP code are required" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Sanitize phone number to 10 digits
    let cleanPhone = String(phone).replace(/\D/g, "");
    if (cleanPhone.startsWith("0")) cleanPhone = cleanPhone.substring(1);
    if (cleanPhone.startsWith("91") && cleanPhone.length === 12) {
      cleanPhone = cleanPhone.substring(2);
    }

    if (cleanPhone.length !== 10) {
      return new Response(
        JSON.stringify({ error: "Invalid 10-digit Indian mobile number" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // 1. Verify OTP with MSG91 Mobile Widget API
    const msg91VerifyUrl = "https://control.msg91.com/api/v5/widget/verifyOtp";
    const msg91Res = await fetch(msg91VerifyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        widgetId: MSG91_WIDGET_ID,
        tokenAuth: MSG91_AUTH_TOKEN,
        reqId: String(reqId).trim(),
        otp: String(otp).trim(),
      }),
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
      const errMsg = msg91Data.message || "Invalid or expired OTP. Please try again.";
      return new Response(
        JSON.stringify({ error: errMsg }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // 2. Verified! Bridge to Supabase Auth
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const syntheticEmail = `phone_${cleanPhone}@phone.mangalsutram.in`;
    const formattedPhone = `+91${cleanPhone}`;

    // Lookup existing user by synthetic email
    let userId: string | null = null;
    const { data: existingUserId } = await supabaseClient.rpc(
      "get_auth_user_id_by_email",
      { p_email: syntheticEmail }
    );

    if (existingUserId) {
      userId = existingUserId;
    } else {
      // Create user with Service Role (auto-confirms)
      const { data: newUser, error: createErr } =
        await supabaseClient.auth.admin.createUser({
          email: syntheticEmail,
          email_confirm: true,
          user_metadata: {
            phone: formattedPhone,
            is_phone_verified: true,
          },
        });

      if (createErr && !newUser?.user) {
        console.error("Supabase user creation error:", createErr);
        // Fallback: check if user already exists
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

    // 3. Ensure basic profile exists in profiles table
    const { data: existingProfile } = await supabaseClient
      .from("profiles")
      .select("id")
      .eq("id", userId)
      .maybeSingle();

    if (!existingProfile) {
      await supabaseClient.from("profiles").upsert(
        {
          id: userId,
          phone: formattedPhone,
          account_type: "candidate",
          terms_accepted: true,
        },
        { onConflict: "id" }
      );
    }

    // 4. Generate one-time session token via magiclink
    const { data: linkData, error: linkErr } =
      await supabaseClient.auth.admin.generateLink({
        type: "magiclink",
        email: syntheticEmail,
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
        email: syntheticEmail,
        token: linkData.properties.email_otp,
        userId: userId,
        phone: formattedPhone,
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
