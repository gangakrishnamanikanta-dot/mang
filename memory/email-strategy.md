---
name: email-strategy
description: All emails through Resend — triggers, list, bi-weekly digest rules, Supabase emails disabled
metadata:
  type: project
---

## All Emails via Resend (NOT Supabase)

### Email Types and Triggers
| # | Email | Trigger | Scheduling |
|---|-------|---------|------------|
| 1 | Welcome | After email verification | Instant |
| 2 | Profile Approved | Admin approves profile | Instant |
| 3 | Security Alert | Password changed or new device login | Instant |
| 4 | Interest Accepted | Someone accepts your interest | Instant |
| 5 | Profile Reminder | Day 3 after signup if <60% complete | Cron |
| 6 | Match Digest | Bi-weekly, ONLY if matches exist | Cron |
| 7 | Monthly Summary | 1st of every month | Cron |

### Bi-weekly Digest Rules
- Only send if new matches found for user
- If 0 matches → skip email (never fake it)
- If matches exist → show 5-8 curated profiles with key details

### Required Email Footer
Every email must include: unsubscribe link (CAN-SPAM legal requirement), physical address, "This email was sent to {{email}}"

### Supabase Email Settings
- Disable Supabase's built-in email provider
- Use Supabase only for auth (create users), not for sending emails
- OTP and password reset emails sent via Resend Edge Functions (custom OTP table)

### Edge Functions Needed
1. `send-otp` — generate + store OTP, send via Resend
2. `verify-otp` — check OTP, confirm user
3. `send-email` — generic email sender for all 7 email types
4. Cron job for bi-weekly digest and monthly summary

### Resend API Key
- Stored in Supabase secrets (not in code)
- Free tier: 100/day, 3,000/month — enough for v1
- Get from user when building Edge Functions

**Why not use Supabase for emails?** Free tier only allows 3/hr. Resend gives 100/day free. For a matrimony app with bi-weekly digests, welcome emails, and notifications, Resend is the right choice.
