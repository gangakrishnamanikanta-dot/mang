# 🪔 Mangalasutram — Canonical Rules of This App

> **Document Status**: Master Specification & Canonical Rulebook  
> **Target**: MVP Internal Beta (Play Store + TestFlight) & Production Launch  
> **Enforcement**: Strictly enforced across Frontend (Flutter Clean Architecture), Backend (Supabase Postgres RLS & RPCs), and Edge Functions.

---

## 📌 1. The Core Lock-In & Engineering Rules

1. **Anti-Drift & Scope Lock-In**:
   - No new features mid-sprint. Ideas outside the locked MVP checklist automatically go to the **Phase 2 Backlog**.
   - Build → Test → Verify → Move to the next day's task.
2. **Zero Errors Policy (`AGENTS.md`)**:
   - `flutter analyze` must maintain **0 errors, 0 warnings, and 0 lints** at every commit.
   - All tests must maintain a 100% pass rate.
3. **Vedic Luxury Aesthetic Standard**:
   - **Backgrounds**: Warm Ivory & Cream (`#FAF6F0`, `#FFFDF9`)
   - **Primary Accent**: Royal Burgundy (`#6E1732`, `#54121F`)
   - **Auspicious Highlight**: Temple Gold (`#C99A4B`)
   - **Typography**: Google Fonts `PlayfairDisplay` (Headings) and `Inter` (Data / Body).
4. **Mobile UX & Interaction Polish**:
   - **Keyboard Guardrail**: Always unfocus the keyboard (`FocusScope.of(context).unfocus()`) **before** opening bottom sheets, dialogs, or pickers to avoid viewport jumping.
   - **Native Pickers**: Date of Birth and Time of Birth use luxury Vedic pickers (`LuxuryDatePicker`, `LuxuryTimePicker`), never raw keyboard text boxes.
   - **No Blocking Spinners on Dropdowns**: Lookups use cached in-memory data (`LookupService`), never blocking network spinners on tap.
   - **Double-Back to Exit**: On the Home tab, pressing Android back prompts "Press back again to exit" within 2 seconds. Pressing back from other tabs returns to Home (index 0).

---

## 👑 2. Membership Tiers & Access Control Matrix

Mangalasutram operates on a 3-tier model: **Free Member**, **Prime Lite**, and **Prime VIP**.

| Feature / Capability | Free Member | Prime Lite | Prime VIP |
|---|:---:|:---:|:---:|
| **Daily Express Interests** | **5 per day** | **25 per day** | **50 per day** |
| **Daily Quota Reset Schedule** | Midnight IST (00:00:00 UTC+5:30) | Midnight IST (00:00:00 UTC+5:30) | Midnight IST (00:00:00 UTC+5:30) |
| **Contact Phone Number Unlocks** | ❌ 0 (Locked) | **15 contacts / month** | **50 contacts / month** |
| **Contact Retention Rule** | N/A | **Permanent in Address Book** | **Permanent in Address Book** |
| **Chat with Matches** | ✅ Mutual matches only (both accepted) | ✅ Mutual matches only | ✅ Mutual matches + Direct message with interest |
| **Guna Milan Compatibility** | Overall score only (e.g. `28/36`) | Overall score + basic summary | Full 8-Koota breakdown with Parihara details |
| **Profile Visitors ("Who Viewed Me")** | ❌ Blurred thumbnail & count only | ❌ Blurred thumbnail & count only | ✅ Unrestricted full list with timestamps |
| **Search & Discovery Priority** | Standard waterfall pool | High visibility | Top priority in match waterfall pool |
| **Horoscope Request Access** | Send & receive requests | Send & receive requests | Priority instant access |
| **Membership Badge** | None | ✨ Prime Lite Badge | 👑 Prime VIP Crown Badge |
| **Customer Support SLA** | Standard email | Priority WhatsApp support | Dedicated Relationship Manager |

### Tier Enforcement Logic:
1. **Express Interest Quota**:
   - Enforced atomically in Postgres via `send_interest_with_quota` RPC.
   - When a user exceeds their daily quota, the RPC throws `quota_exceeded`, and the Flutter app immediately presents the `QuotaExhaustedSheet`.
2. **Contact Number Unlocking**:
   - Enforced via `unlock_contact_number` RPC.
   - Phone numbers are stored securely in `profiles.phone` and **never exposed** in the public `public_profiles` view.
   - Deducts 1 credit from `contacts_unlocked_limit`. Once unlocked, the decrypted number is permanently stored in the user's `contact_unlocks` ledger.
   - **Unlocked contacts remain permanently readable** even if the user's Prime subscription expires.
3. **Messaging Permissions**:
   - Free users **CANNOT** cold-message any profile.
   - Messaging is unlocked **ONLY** when User A sends an Interest and User B taps **Accept**.

---

## 🔮 3. Vedic Astrology & Guna Milan Rules

1. **Authenticity Guarantee (Brihat Parashara Hora Shastra Standard)**:
   - Guna Milan compatibility strictly follows the authentic 8-Koota (36-Guna) mathematical framework:
     - **Varna (1 pt)**: Spiritual / ego harmony (Brahmin, Kshatriya, Vaishya, Shudra).
     - **Vashya (2 pts)**: Mutual power and natural attraction (Chatushpada, Manava, Jalachara, Keeta, Vanachara).
     - **Tara (3 pts)**: Dina Koota health, longevity, and destiny compatibility.
     - **Yoni (4 pts)**: Complete 14-animal biological compatibility (Natural enemies: Tiger vs. Cow = 0, Cat vs. Rat = 0, Elephant vs. Lion = 0).
     - **Graha Maitri (5 pts)**: Moon planetary lord friendships.
     - **Gana (6 pts)**: Temperament compatibility (Deva, Manushya, Rakshasa).
     - **Bhakoot (7 pts)**: Rasi distance (6/8, 9/5, 2/12) with authentic scriptural cancellation exceptions.
     - **Nadi (8 pts)**: Authentic Serpentine Wave (Aadi, Madhya, Antya) with scriptural **Nadi Parihara** exceptions (different Padas or beneficial planetary lords).
2. **Zero Fake Astrology Policy (CRITICAL)**:
   - If either profile lacks an authentic Nakshatra or Pada, the Guna score **MUST strictly be `null`**.
   - **NEVER** generate a random, heuristic, modulo, or placeholder horoscope score.
3. **Horoscope Privacy Modes**:
   - **Public**: Kundali chart visible to verified members.
   - **On-Request**: Kundali chart is locked; candidate must send a "Horoscope Request" which the profile owner approves or declines.
   - **Private**: Kundali is hidden; only the Guna Milan score is shown.

---

## 🕉️ 4. Traditional Community & Gotra Governance Rules

1. **Sagotra Marriage Restriction (Gotra & Pravara Rule)**:
   - In orthodox Vedic Brahmin traditions, marriage within the same Gotra (`gothram_id_A == gothram_id_B`) is strictly prohibited.
   - The matching engine applies a severe compatibility penalty or hard-filters candidates sharing the same Gotra unless the user explicitly enables *"Open to same Gotra / Sagotra"*.
2. **Brahmin Subsect Specialization**:
   - The platform strictly indexes and respects Vedic subsects:
     - **Vaidiki**: Velanadu, Veginadu, Telaganya, Kasalanadu, Murikinadu.
     - **Niyogi**: Aruvela, Prathamasaki, Nandavariki.
     - **Other Brahmin Traditions**: Smartha, Madhwa, Sri Vaishnava (Vadakalai, Thenkalai), Dravida.
3. **Traditional Lifestyle Index**:
   - Profiles track traditional observance: Sandhyavandanam, Daily Pooja, Veda Shakha, Kuladevata, and Sampradayam.

---

## 🎯 5. Recommendation Engine & Waterfall Pool Rules

The match feed (`get_top_matches_v2`) generates recommendations using a 100-point composite score:

1. **Hard Filters (Strict Zero Tolerance)**:
   - **Gender**: Strict opposite gender matching (Male ↔ Female).
   - **Marital Status**: Alignment with candidate's stated preference.
   - **Exclusions**: Any user in `match_exclusions` (blocked or passed) is completely omitted.
2. **100-Point Scoring Breakdown**:
   - **Guna Milan Compatibility (30 pts)**: Authentic Ashta-Koota score mapped proportionally ($Score / 36 \times 30$). If horoscope is missing, a neutral baseline is assigned.
   - **Education & Career Tier (25 pts)**: Professional alignment (Masters, Doctorates, Engineering, CA, Civil Services, Business).
   - **Location Proximity (15 pts)**: Same City (15 pts) > Same State (10 pts) > Same Country (5 pts).
   - **Lifestyle & Food (15 pts)**: Strict Vegetarianism / Eggetarianism and traditional habit compatibility.
   - **Activity & Freshness (15 pts)**: Active within last 7 days gets maximum boost; inactive profiles fade down the feed.
3. **Pool Rotation & Cooldown**:
   - Free users receive a curated batch of 10–20 daily profiles.
   - Passing a profile (`swipe_left`) places that candidate into a **30-day cooldown**, preventing feed clogging.

---

## 🤝 6. Match Lifecycle & Interaction Rules

1. **The "It's a Match!" Rule**:
   - An alliance is formed when User B accepts User A's pending interest.
   - The app immediately triggers the **Match Celebration Experience**:
     - Dual photo display with Temple Gold accents.
     - Authentic Guna Milan compatibility score badge.
     - Instant action button: **"Start Sacred Chat"**.
2. **Atomic Conversation Creation**:
   - On interest acceptance, the Postgres trigger atomically initializes an E2EE conversation room in the `conversations` table.
3. **Decline & Anti-Harassment Rule**:
   - If User B taps **Decline**, the status updates to `declined`.
   - User A cannot re-send an interest to User B.
   - The declined interest is archived from the active feed.
4. **Daily Quota Reset**:
   - Quotas are calculated on Indian Standard Time (IST, UTC+5:30) to align with community expectations.
   - Unused daily interests do not roll over to the next day.

---

## 🔒 7. End-to-End Encryption (E2EE) Chat Architecture

1. **Zero-Knowledge Cryptographic Primitives**:
   - **Key Agreement**: X25519 (Elliptic Curve Diffie-Hellman over Curve25519).
   - **Symmetric Cipher**: AES-256-GCM (Galois/Counter Mode with 128-bit authentication tag).
   - **Key Storage**: Hardware-backed Android Keystore / iOS Keychain.
   - Neither database admins, server processes, nor cloud providers can read plaintext messages.
2. **Storage Model**:
   - The `messages` table stores only `ciphertext`, `nonce`, and `sender_public_key`.
3. **Delivery Ticks Protocol**:
   - **Single Grey Tick `✓`**: Message uploaded to server.
   - **Double Grey Tick `✓✓`**: Delivered to recipient's device.
   - **Double Blue/Gold Tick `✓✓`**: Read by recipient in the active chat view.
4. **Encrypted Media Storage**:
   - Chat images are encrypted on the mobile device into binary blobs (`.bin`) before uploading to the `chat-media-encrypted` bucket.

---

## 🛡️ 8. Safety, Privacy & Store Compliance Rules

1. **Apple Guideline 1.2 & Google UGC Mandate**:
   - Every candidate profile card, detail screen, and chat screen **MUST** provide an accessible 3-dot menu with **Report Member** and **Block Member**.
   - Categories: Fake profile, Inappropriate photo, Harassment/Abuse, Already married, Scam/Commercial, Other.
2. **Bilateral Block Isolation**:
   - When User A blocks User B:
     - Record inserted into `user_blocks`.
     - Bidirectional exclusion inserted into `match_exclusions` (`(A, B)` and `(B, A)`).
     - Match caches for both users are purged immediately.
     - Pending interests between them are cancelled.
     - Mutual chat conversation is disabled.
     - Neither user will ever see the other in Discovery, Search, or Matches.
3. **Apple Guideline 5.1.1(v) Permanent Account Erasure**:
   - Users can self-serve account deletion at any time under **Settings & Privacy -> Danger Zone -> Delete Account**.
   - The RPC `delete_user_account`:
     - Wipes phone, email, and personal identification details.
     - Sets `is_active = false`.
     - Revokes auth sessions and signs the user out.
4. **Photo Privacy & Protection**:
   - Watermark overlay applied to profile photos.
   - Option for users to keep photos blurred until an interest is accepted.

---

## ⚖️ 9. Indian Statutory & Legal Compliance (IT Act, DPDP & CERT-In)

1. **CERT-In 180-Day Log Retention Mandate**:
   - User connection IP addresses, session timestamps, and authentication actions are retained in `auth_audit_logs` for 180 days for statutory cyber cell inquiry readiness (Section 91 CrPC).
2. **Grievance Redressal SLA (IT Rules 2021)**:
   - Reported profiles are queued with a mandatory 24-hour review SLA.
3. **Law Enforcement Readiness**:
   - Ability to generate a certified Law Enforcement Response Package (dossier + audit log timeline + cryptographic non-possession certificate) upon receipt of lawful notices.

---

## 🗺️ 10. Product Roadmap & Phased Boundaries

- **Phase 1 (Current 4-Week MVP)**:
  - Ship the credible core: verified profiles, Brahmin subsect filters, authentic 36-guna matching, E2EE chat, delivery ticks, store safety & moderation, and monetization tier UI.
- **Phase 2 (Post-MVP — The Shared Family Space)**:
  - Private family room replacing WhatsApp screenshots.
  - Zero-friction parent invite via WhatsApp deep-links.
  - Candidate + Parent joint discussion boards and alignment indicators.
- **Phase 3 (Post-Launch Intelligence)**:
  - Pattern recognition across repeated rejections (e.g. location bottlenecks).
  - "What-if" criteria relaxation suggestions.
