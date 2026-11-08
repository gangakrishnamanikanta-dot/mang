# Mangalasutram Engineering Standards & Quality Gates

> **Authoritative Specification**: All code, migrations, services, and UI components in the *Mangalasutram* platform must strictly comply with the following 8 immutable laws.

---

## Law 1: Zero Fake Data Mandate
- **No Mock or Fallback Metrics**: Never inject synthetic fallback values (`?? 75`, `?? 24`, `?? 'Brahmin'`, `?? 80%`).
- **Authentic Nullability**: If data is missing (e.g. birth nakshatras, Guna Milan score, annual income, caste), render legitimate empty/unspecified UI or `null`. Never lie to matrimonial candidates or their guardians.

---

## Law 2: Zero-Defect Static Analysis Gate
- **0 Errors, 0 Warnings, 0 Lints**: Every single pull request, commit, and file modification must maintain `flutter analyze` / `dart analyze` at zero issues.
- **Unused Code Erasure**: No unused imports, deprecated API usages, dead code branches, or untyped `dynamic` variables where concrete models exist.

---

## Law 3: Monotonic Concurrency Tokens
- **Anti-Race-Condition Protection**: All asynchronous search, pagination, filter, and fetch operations must utilize monotonic integer request tokens (`_requestId` or `_searchRequestId`).
- **Discard Stale Frames**: When an asynchronous call completes, if its request token does not match the active monotonic token, the response payload must be immediately discarded to prevent stale data overriding fresh user inputs.

---

## Law 4: Unfocus Keyboard Before Modals
- **Zero Screen Jumping**: Before presenting any modal bottom sheet, date/time picker, or dialog, code must invoke `FocusScope.of(context).unfocus()`.
- **Smooth Layout Transitions**: Bottom sheets must never jump or clip due to software keyboards resizing viewports mid-animation.

---

## Law 5: Canonical Vedic Astrology Engine
- **Authentic Ashta-Koota Calculation**: Compatibility scoring must use authentic Vedic Ashta-Koota (Varna, Vashya, Tara, Yoni, Graha Maitri, Gana, Bhakoot, Nadi) totaling 36 points.
- **Strict 4-Tier Scale**:
  - `0 – 17 Gunas`: *Varjya* (Incompatible / Avoid)
  - `18 – 24 Gunas`: *Madhyama* (Average / Moderate)
  - `25 – 32 Gunas`: *Uttama* (Auspicious / Highly Compatible)
  - `33 – 36 Gunas`: *Ati-Uttama* (Divinely Auspicious / Exceptional)
- **Null Safety**: If either candidate's Nakshatra is unknown, the score must evaluate to `null` and show a prompt to update horoscope details.

---

## Law 6: Luxury Vedic Aesthetic System
- **Backgrounds**: Warm Ivory / Sacred Cream (`#FBF8F1`, `#FFFDF9`).
- **Primary Accent**: Deep Royal Burgundy (`#6E1732`).
- **Auspicious Highlight**: Temple Gold (`#C99A4B`).
- **Typography**: Google Fonts `PlayfairDisplay` for sacred headings and `Inter` for crisp, high-legibility body copy.
- **No Blocking Spinners on Lookups**: Always leverage in-memory cached lookup tables for instantaneous dropdown rendering.

---

## Law 7: Secure Multi-Channel Auth & SMS Integrity
- **Indian SMS OTP Engine**: Powered by MSG91 Mobile Widget v5 using MSG91 default templates (DLT pre-approved).
- **Backend Session Bridge**: Verified mobile numbers bridge to authenticated Supabase GoTrue sessions via the `phone-auth` Edge Function, generating secure magiclink tokens and ensuring full Row-Level Security (RLS) enforcement.
- **Brute-Force Shield**: Throttling configured to protect against SMS flooding, with sane lockout limits (15 minutes, never 24 hours).

---

## Law 8: Goal Guardrail & Anti-Drift Execution
- **Launch Priority**: All development cycles must drive directly toward the production-grade MVP launch.
- **One-Shot High-Standard Delivery**: Deliver comprehensive, fully verified solutions with accompanying test suites in single passes rather than fragile, half-finished iterations.

