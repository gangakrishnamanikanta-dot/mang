import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const FROM_EMAIL = "Mangalasutram <noreply@send.mangalsutram.me>";
const APP_URL = Deno.env.get("EXPO_PUBLIC_APP_URL") || "https://mangalasutram.me";

interface EmailPayload {
  to: string;
  type: "welcome" | "profile_approved" | "security_alert" | "interest_accepted" | "profile_reminder" | "match_digest" | "monthly_summary";
  data: Record<string, any>;
}

function escapeHtml(str: string): string {
  const map: Record<string, string> = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" };
  return str.replace(/[&<>"']/g, m => map[m]);
}

function generateEmail(type: string, data: Record<string, any>): { subject: string; html: string } {
  const name = escapeHtml(data.name || "User");
  const logoUrl = data.logo_url || `${APP_URL}/logo.png`;

  switch (type) {
    case "welcome": {
      return {
        subject: "Welcome to Mangalasutram — Begin Your Journey",
        html: `
          <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
            <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
            <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

            <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">Welcome, ${name}!</h2>
            <p style="color: #666; line-height: 1.6; margin-bottom: 30px;">
              Your account has been verified successfully. Now it's time to complete your profile and discover your perfect match.
            </p>

            <a href="${APP_URL}/profile-setup" style="display: inline-block; background: #8B0000; color: white; padding: 14px 32px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0;">
              Complete Your Profile
            </a>

            <p style="color: #666; line-height: 1.6; margin-top: 30px; font-size: 14px;">
              Your profile must be <strong>60% complete</strong> to start seeing matches. The more details you provide, the better your matches will be.
            </p>

            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
              <p style="color: #ccc; font-size: 10px; margin-top: 8px;">
                <a href="${APP_URL}/unsubscribe?email=${escapeHtml(data.email || "")}" style="color: #ccc;">Unsubscribe</a> from these emails.
              </p>
            </div>
          </div>
        `,
      };
    }

    case "profile_approved": {
      return {
        subject: "Your Profile is Now Live on Mangalasutram",
        html: `
          <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
            <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
            <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

            <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">🎉 Your Profile is Live!</h2>
            <p style="color: #666; line-height: 1.6; margin-bottom: 30px;">
              Congratulations ${name}! Your profile has been approved and is now visible to potential matches. Start exploring profiles that align with your preferences.
            </p>

            <a href="${APP_URL}/matches" style="display: inline-block; background: #8B0000; color: white; padding: 14px 32px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0;">
              View Your Matches
            </a>

            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
              <p style="color: #ccc; font-size: 10px; margin-top: 8px;">
                <a href="${APP_URL}/unsubscribe?email=${escapeHtml(data.email || "")}" style="color: #ccc;">Unsubscribe</a>
              </p>
            </div>
          </div>
        `,
      };
    }

    case "security_alert": {
      return {
        subject: "Security Alert — Your Mangalasutram Account",
        html: `
          <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
            <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
            <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

            <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">Security Alert</h2>
            <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
              Hi ${name}, your password was recently changed.
            </p>
            <div style="background: #FFF8F0; border-left: 4px solid #D4AF37; padding: 20px; margin: 20px 0; text-align: left;">
              <p style="color: #333; margin: 5px 0;"><strong>Event:</strong> ${escapeHtml(data.event || "Password changed")}</p>
              <p style="color: #333; margin: 5px 0;"><strong>Date:</strong> ${escapeHtml(data.date || new Date().toLocaleString())}</p>
              <p style="color: #333; margin: 5px 0;"><strong>Device:</strong> ${escapeHtml(data.device || "Unknown")}</p>
              <p style="color: #333; margin: 5px 0;"><strong>Location:</strong> ${escapeHtml(data.location || "Unknown")}</p>
            </div>
            <p style="color: #666; line-height: 1.6; margin-top: 20px; font-size: 14px;">
              If this was you, no action is needed. If you didn't make this change, please secure your account immediately.
            </p>

            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
              <p style="color: #ccc; font-size: 10px; margin-top: 8px;">
                <a href="${APP_URL}/unsubscribe?email=${escapeHtml(data.email || "")}" style="color: #ccc;">Unsubscribe</a>
              </p>
            </div>
          </div>
        `,
      };
    }

    case "interest_accepted": {
      return {
        subject: `${name} accepted your interest on Mangalasutram!`,
        html: `
          <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
            <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
            <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

            <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">Good News!</h2>
            <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
              <strong>${escapeHtml(data.sender_name || "Someone")}</strong> has accepted your interest. Now you can connect and start your conversation.
            </p>

            <a href="${APP_URL}/chat" style="display: inline-block; background: #8B0000; color: white; padding: 14px 32px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0;">
              Start Chatting
            </a>

            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
              <p style="color: #ccc; font-size: 10px; margin-top: 8px;">
                <a href="${APP_URL}/unsubscribe?email=${escapeHtml(data.email || "")}" style="color: #ccc;">Unsubscribe</a>
              </p>
            </div>
          </div>
        `,
      };
    }

    case "profile_reminder": {
      return {
        subject: "Complete Your Mangalasutram Profile",
        html: `
          <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
            <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
            <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

            <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">Don't Miss Out!</h2>
            <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
              Hi ${name}, your profile is still incomplete. Complete it to start seeing your matches.
            </p>

            <div style="background: #FFF8F0; border: 2px dashed #D4AF37; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p style="color: #8B0000; font-weight: bold; margin: 0;">You're ${data.percent || 0}% done</p>
              <p style="color: #999; font-size: 13px; margin: 8px 0 0 0;">Only ${data.remaining || 0} more fields to complete</p>
            </div>

            <a href="${APP_URL}/profile-setup" style="display: inline-block; background: #8B0000; color: white; padding: 14px 32px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0;">
              Complete Profile
            </a>

            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
              <p style="color: #ccc; font-size: 10px; margin-top: 8px;">
                <a href="${APP_URL}/unsubscribe?email=${escapeHtml(data.email || "")}" style="color: #ccc;">Unsubscribe</a>
              </p>
            </div>
          </div>
        `,
      };
    }

    case "match_digest": {
      const matchesHtml = (data.matches || []).map((m: any) => `
        <div style="text-align: left; padding: 12px; background: #FFF8F0; border-radius: 8px; margin-bottom: 10px; border-left: 3px solid #D4AF37;">
          <p style="margin: 0; font-weight: bold; color: #333;">${escapeHtml(m.name || "Profile")}</p>
          <p style="margin: 4px 0 0 0; color: #666; font-size: 13px;">
            ${escapeHtml(m.age || "")} yrs · ${escapeHtml(m.location || "")} · ${escapeHtml(m.education || "")}
          </p>
          <p style="margin: 4px 0 0 0; color: #999; font-size: 12px;">
            ${escapeHtml(m.occupation || "")} · ${escapeHtml(m.marital_status || "")}
          </p>
        </div>
      `).join("");

      return {
        subject: `Your Bi-Weekly Match Digest — ${data.match_count || 0} new matches for you`,
        html: `
          <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
            <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
            <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

            <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">Your Bi-Weekly Matches</h2>
            <p style="color: #666; line-height: 1.6; margin-bottom: 30px;">
              Hi ${name}, here are your curated matches for this fortnight. We found <strong>${data.match_count || 0} new profiles</strong> that align with your preferences.
            </p>

            ${matchesHtml || "<p style='color: #999;'>No new matches this fortnight — we'll keep looking for you.</p>"}

            <a href="${APP_URL}/matches" style="display: inline-block; background: #8B0000; color: white; padding: 14px 32px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0;">
              View All Matches
            </a>

            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
              <p style="color: #ccc; font-size: 10px; margin-top: 8px;">
                <a href="${APP_URL}/unsubscribe?email=${escapeHtml(data.email || "")}" style="color: #ccc;">Unsubscribe</a> from digest emails.
              </p>
            </div>
          </div>
        `,
      };
    }

    case "monthly_summary": {
      return {
        subject: `Your Monthly Activity on Mangalasutram`,
        html: `
          <div style="font-family: 'Playfair Display', serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center;">
            <h1 style="color: #8B0000; font-size: 32px; margin-bottom: 10px;">Mangalasutram</h1>
            <p style="color: #D4AF37; font-size: 14px; letter-spacing: 2px; margin-bottom: 40px;">A SACRED UNION AWAITS YOUR ARRIVAL</p>

            <h2 style="color: #333; font-size: 24px; margin-bottom: 20px;">Your Monthly Summary</h2>
            <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
              Hi ${name}, here's what happened on your Mangalasutram journey this month.
            </p>

            <div style="display: flex; justify-content: center; gap: 20px; margin: 30px 0;">
              <div style="background: #FFF8F0; border: 1px solid #D4AF37; padding: 20px; border-radius: 8px; width: 120px;">
                <p style="color: #8B0000; font-size: 28px; font-weight: bold; margin: 0;">${data.profile_views || 0}</p>
                <p style="color: #999; font-size: 12px; margin: 5px 0 0 0;">Profile Views</p>
              </div>
              <div style="background: #FFF8F0; border: 1px solid #D4AF37; padding: 20px; border-radius: 8px; width: 120px;">
                <p style="color: #8B0000; font-size: 28px; font-weight: bold; margin: 0;">${data.interests_received || 0}</p>
                <p style="color: #999; font-size: 12px; margin: 5px 0 0 0;">Interests</p>
              </div>
              <div style="background: #FFF8F0; border: 1px solid #D4AF37; padding: 20px; border-radius: 8px; width: 120px;">
                <p style="color: #8B0000; font-size: 28px; font-weight: bold; margin: 0;">${data.matches || 0}</p>
                <p style="color: #999; font-size: 12px; margin: 5px 0 0 0;">New Matches</p>
              </div>
            </div>

            <a href="${APP_URL}/matches" style="display: inline-block; background: #8B0000; color: white; padding: 14px 32px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0;">
              View Matches
            </a>

            <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #aaa; font-size: 11px;">© 2026 Mangalasutram. All rights reserved.</p>
              <p style="color: #ccc; font-size: 10px; margin-top: 8px;">
                <a href="${APP_URL}/unsubscribe?email=${escapeHtml(data.email || "")}" style="color: #ccc;">Unsubscribe</a>
              </p>
            </div>
          </div>
        `,
      };
    }

    default:
      return {
        subject: "Mangalasutram Notification",
        html: `<p>You have a new notification from Mangalasutram.</p>`,
      };
  }
}

serve(async (req) => {
  try {
    const payload: EmailPayload = await req.json();

    if (!payload.to || !payload.type || !payload.data) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: to, type, data" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const { subject, html } = generateEmail(payload.type, payload.data);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: payload.to,
        subject,
        html,
      }),
    });

    if (!resendResponse.ok) {
      const error = await resendResponse.text();
      console.error("Resend error:", error);
      return new Response(
        JSON.stringify({ error: "Failed to send email", details: error }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: "Email sent successfully" }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Server error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
