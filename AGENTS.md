# Mangalasutram Project Rules & Directives

## 1. Goal Guardrail & Anti-Drift Rule (CRITICAL)
- **Stay on the Main Plot**: Always keep the project focused on the core goal: building and launching a production-grade, luxury matrimonial app (*Mangalasutram*).
- **Proactive Warning on Scope Creep**: If the user or agent starts drifting into endless micro-tweaking loops, unnecessary side features, or non-MVP tangents that delay the launch, **immediately warn the user and redirect focus back to the core milestone**.
- **One-Shot High-Standard Execution**: Deliver complete, industry-standard solutions in single structured passes rather than iterative, broken cycles.

## 2. Core Architecture & Standards
- **Frontend**: Flutter with Clean Feature Architecture (`lib/features/*`).
- **Backend**: Supabase (Postgres, RLS policies, RPC functions, Edge Functions).
- **Aesthetic System**: Luxury Vedic Matrimonial:
  - Background: Warm Ivory / Cream (`#FBF8F1`, `#FFFDF9`)
  - Primary Accent: Deep Royal Burgundy (`#6E1732`)
  - Auspicious Highlight: Temple Gold (`#C99A4B`)
  - Typography: Google Fonts `PlayfairDisplay` (headings) and `Inter` (body/data).
- **Astrology & Guna Milan Integrity**:
  - Guna Milan scores and Ashta-Koota calculations must be strictly authentic.
  - If birth stars / nakshatras are absent, compatibility score must remain `null` — never display fake or simulated astrology data.

## 3. Interaction & UX Rules
- **No Screen Jumping**: Always unfocus keyboard (`FocusScope.of(context).unfocus()`) before presenting bottom sheets or pickers.
- **No Blocking Dialog Spinners on Dropdowns**: Use cached in-memory lookups (`_lookupData`) directly.
- **Native / Cupertino Pickers**: Use `LuxuryDatePicker` and `LuxuryTimePicker` instead of raw text inputs.
- **Zero Errors Policy**: Every code change must maintain `flutter analyze` at 0 errors, 0 warnings, and 0 lints.

## 4. Communication & Truth Mandate (CRITICAL)
- **Brutal & Honest Truth Always**: Never sugarcoat, flatter, or pretend something works when it has architectural or functional flaws. Always provide raw, objective, transparent engineering realities, tradeoffs, and technical truth without hesitation.

