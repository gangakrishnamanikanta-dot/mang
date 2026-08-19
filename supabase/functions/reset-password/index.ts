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

// Allowed origins (or use regex for subdomains if needed)
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

  // If origin is strictly present but not allowed, we could block it, 
  // but returning empty Access-Control-Allow-Origin naturally blocks browser cross-origin requests.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, code, new_password } = await req.json();

    if (!email || !code || !new_password) {
      return new Response(
        JSON.stringify({ error: "Email, code, and new_password are required" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    if (new_password.length < 8) {
      return new Response(
        JSON.stringify({ error: "Password must be at least 8 characters." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Step 1: Verify the OTP code is valid
    const codeHash = await hashCode(code);
    const now = new Date().toISOString();

    const { data: match } = await supabaseAdmin
      .from("otps")
      .select("*")
      .eq("email", email)
      .eq("purpose", "reset_password")
      .eq("code_hash", codeHash)
      .gt("expires_at", now)
      .maybeSingle();

    if (!match) {
      // Check why — expired or wrong code?
      const { data: recentOtp } = await supabaseAdmin
        .from("otps")
        .select("*")
        .eq("email", email)
        .eq("purpose", "reset_password")
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
        JSON.stringify({ error: "Invalid verification code." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Step 2: Find the user by email
    const { data: usersData, error: userListError } = await supabaseAdmin.auth.admin.listUsers();
    if (userListError) {
      return new Response(
        JSON.stringify({ error: "Failed to find user." }),
        { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const user = usersData.users.find(u => u.email === email);
    if (!user) {
      return new Response(
        JSON.stringify({ error: "No account found with this email." }),
        { status: 404, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Step 3: Update password using Admin API
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      user.id,
      { password: new_password }
    );

    if (updateError) {
      return new Response(
        JSON.stringify({ error: "Failed to update password. Please try again." }),
        { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Step 4: Delete the used OTP
    await supabaseAdmin.from("otps").delete().eq("id", match.id);

    return new Response(
      JSON.stringify({ success: true, message: "Password updated successfully." }),
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
