# 🏛️ Mangalasutram Matrimony: Admin Panel, E2EE Chat & Legal Compliance Specification
> **Document Status**: Production Blueprint & Statutory Compliance Specification  
> **Applicable Laws**: Indian IT Act 2000, IT Rules 2021 (Intermediary Guidelines), DPDP Act 2023, CERT-In Cyber Security Directions (April 2022).

---

## 📌 1. Overview & Core Principles

This document serves as the permanent technical and architectural specification for the **Mangalasutram Admin Compliance Portal, End-to-End Encrypted (E2EE) Chat System, App-Wide Event & Swipe Tracking Engine, Media Storage Tiers, and Statutory Record-Holding Architecture**.

### Core Guarantees:
1. **Zero-Knowledge Privacy**: Chat messages and chat media are encrypted on client devices (Curve25519 + AES-256-GCM). Neither database admins, server processes, nor cloud providers can read plaintext messages or view private chat attachments.
2. **Indian Statutory Compliance**: Adheres strictly to CERT-In (180-day access log retention), DPDP Act 2023 (purpose limitation & security safeguards), and IT Rules 2021 (Intermediary response to lawful Section 91 CrPC notices).
3. **Law Enforcement Readiness**: Provides an automated, cryptographically certified dossier export mechanism for cyber crime cells and courts without compromising cryptographic keys.

---

## 🧭 2. App-Wide Event & Swipe Tracking Architecture

The platform categorizes all user telemetry and interactions into **3 distinct tracking buckets**:

```
MANGALASUTRAM TRACKING ENGINE
├── 1. 🧠 Algorithm & Behavioral Signals (Feeds the Recommendation AI)
├── 2. 🛡️ Safety, Fraud & Statutory Audit Logs (Indian Cyber Law / CERT-In)
└── 3. 💰 Monetization & Paywall Analytics (Drives Prime Upgrades)
```

### 2.1 Bucket 1: Algorithm & Behavioral Tracking (Feed AI)
* **`swipe_right` / `send_interest`**: Positive signal (+3.0x affinity weight) on caste, occupation, education.
* **`swipe_left` / `pass_profile`**: Negative signal (-0.5x affinity penalty) + 30-day cooldown via `match_swipes`.
* **`shortlist_toggle`**: Moderate positive (+1.5x weight).
* **`profile_dwell`**: $\ge 5\text{s} \to$ Intentional read; $< 2\text{s} \to$ Quick bounce (`profile_views.dwell_seconds`).
* **`horoscope_expanded`**: Flags user as **"Astrology-Sensitive"** (increases Kundali match score weight from 8% $\to$ 20%).

```sql
CREATE TABLE public.match_swipes (
    user_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    swipe_action  text NOT NULL CHECK (swipe_action IN ('like', 'pass', 'super_interest')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, target_id)
);
CREATE INDEX idx_match_swipes_lookup ON public.match_swipes(user_id, swipe_action);
```

### 2.2 Bucket 2: Safety, Fraud & Statutory Tracking (Legal Mandate)
* **`auth_login` / `auth_otp_verify`**: User ID, IP Address, Device Model, OS, Timestamp (CERT-In 180-day retention).
* **`profile_reported`**: Reporter ID, Target ID, Reason (Fake, Inappropriate, Harassment) $\to$ Triggers Grievance SLA (IT Rules 2021).
* **`profile_blocked`**: Hard-excludes both users from search, chat, and feed permanently.
* **`contact_unlocked`**: Buyer ID, Target Profile ID, Timestamp, Remaining Quota (DPDP audit proof).
* **`kyc_verified`**: Aadhaar / Govt ID hash verification timestamp for romance scam prevention.

### 2.3 Bucket 3: Monetization & Conversion Tracking (Paywall Funnel)
* **`daily_matches_exhausted`**: Free user hits 5/5 daily limit and sees *"You're All Caught Up"* paywall card.
* **`blurred_visitor_clicked`**: Free user taps blurred visitor photo in *"Who Viewed You"*.
* **`contact_limit_hit`**: User tries viewing contact with 0 quota left $\to$ Triggers Prime upgrade modal.
* **`discovery_search_capped`**: Free user hits 10th result in discovery search.

---

## 🖼️ 3. Media & Image Storage Architecture (3-Tier Storage)

Images and media are strictly isolated into 3 storage tiers:

```
STORAGE TIERS (Supabase Storage / AWS S3)
├── 1. 🌐 Public Profile Photos ('profile-photos')
│   ├── Format: Compressed WebP / AVIF (80–120 KB per image)
│   ├── Security: Platform watermark overlay ("Mangalasutram Verified")
│   └── Monetization: Blurred/masked via server URL for Free tier users
│
├── 2. 🔒 Encrypted Chat Media ('chat-media-encrypted')
│   ├── Format: Client-Side Encrypted Binary Blobs (`photo_encrypted.bin`)
│   ├── Encryption: AES-256-GCM using derived session key on mobile device
│   └── Access: Zero server visibility; only sender & receiver hold decryption keys
│
└── 3. 🛡️ Private KYC & Govt ID Vault ('kyc-vault-private')
    ├── Storage: AES-256 encrypted at rest, zero public URL routing
    ├── Retention: Retained during active account lifecycle for fraud prevention
    └── Access: Admin viewing via 15-minute temporary signed URLs with audit logging
```

---

## 💌 4. Interests & Interaction Metadata Architecture

Under Indian cyber law, interest exchanges establish the **chain of consent and communication timeline**.

### 4.1 Database Schema (`public.interests`)
```sql
CREATE TABLE public.interests (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_profile_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_profile_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status                text NOT NULL DEFAULT 'pending' 
                          CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
    sender_ip             inet,                  -- Captured at transmission (CERT-In)
    created_at            timestamptz NOT NULL DEFAULT now(), -- Sent timestamp
    updated_at            timestamptz NOT NULL DEFAULT now(), -- Accepted/Declined timestamp
    CONSTRAINT unique_sender_receiver UNIQUE (sender_profile_id, receiver_profile_id)
);

CREATE INDEX idx_interests_sender ON public.interests(sender_profile_id, created_at DESC);
CREATE INDEX idx_interests_receiver ON public.interests(receiver_profile_id, status);
```

---

## 🔒 5. End-to-End Encryption (E2EE) Chat Architecture

### 5.1 Cryptographic Primitives
* **Key Agreement Protocol**: X25519 (Elliptic Curve Diffie-Hellman over Curve25519).
* **Symmetric Cipher**: AES-256-GCM (Galois/Counter Mode with 128-bit authentication tag).
* **Device Key Storage**:
  * **Android**: Android Keystore with Hardware-backed EncryptedSharedPreferences.
  * **iOS**: iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

### 5.2 Database Storage Model (`messages` table)
```sql
CREATE TABLE public.messages (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id     uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id           uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    ciphertext          text NOT NULL,          -- AES-256-GCM encrypted payload
    nonce               text NOT NULL,          -- Cryptographic Initialization Vector (IV)
    sender_public_key   text NOT NULL,          -- Sender's X25519 public key identifier
    is_read             boolean NOT NULL DEFAULT false,
    created_at          timestamptz NOT NULL DEFAULT now()
);
```

---

## 🇮🇳 6. Indian Legal Compliance & Data Retention Lifecycle

### 6.1 CERT-In 180-Day Log Retention Mandate
```sql
CREATE TABLE public.auth_audit_logs (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    action      text NOT NULL,                  -- e.g., 'login', 'otp_verify', 'interest_sent', 'profile_view'
    ip_address  inet NOT NULL,                  -- User's connection IP
    user_agent  text,                           -- Client OS and App Version
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_user_date ON public.auth_audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_ip_date ON public.auth_audit_logs(ip_address, created_at DESC);
```

### 6.2 Account Deletion ("Dost Deleting" / DPDP Right to Erasure)
* When a user deletes their chat or account:
  1. Plaintext messages and cached media are wiped from device storage immediately.
  2. Server deletes or tombstones `messages` ciphertext rows.
  3. Profile status is marked `is_deleted = true, deleted_at = now()`.
  4. Core access metadata (IP logs, registration timestamps) is retained in `auth_audit_logs` for the statutory 180-day CERT-In window, after which a background pg_cron worker purges them permanently.

---

## 🖥️ 7. Admin Panel: Compliance & Law Enforcement Portal Design

### 7.1 Required Admin Modules
```
ADMIN DASHBOARD
├── 1. Member Management (KYC Verification, Profile Approvals)
├── 2. Monetization & Subscriptions (Prime Lite/VIP Management)
├── 3. Match Analytics (Score Distributions, Feed Health)
└── 4. ⚖️ LEGAL & COMPLIANCE PORTAL (Superadmin / 2FA Gated)
    ├── A. Law Enforcement Dossier Generator (Section 91 CrPC)
    ├── B. CERT-In 180-Day Access & IP Log Exporter (CSV)
    ├── C. Interaction, Swipe & Interest Graph Exporter
    ├── D. E2EE Cryptographic Non-Possession Certificate Generator
    └── E. DPDP Account Deletion & Data Erasure Queue
```

---

## 📄 8. Law Enforcement Response Package (LERP) Workflow

When a formal notice (Section 91 CrPC / Section 69 IT Act / Cyber Cell inquiry) is served:

### Step 1: Search & Target Identification
Admin searches by Phone Number, Email, or Profile UUID.

### Step 2: Automated ZIP Package Export
Clicking **"Generate Law Enforcement Package"** compiles a password-protected ZIP containing:

1. **`Official_Dossier_[CaseNo].pdf`**:
   * Subscriber demographics, verified mobile number, email, registration date/time.
   * Device identifiers, operating system, and IP address login history.
   * Full KYC / Aadhaar verification audit status.
2. **`Interaction_And_Interest_Timeline.pdf`**:
   * Timestamped record of when parties viewed each other, sent interests, accepted interests, swiped, and initiated chat.
3. **`Access_Logs_180Days.csv`**:
   * Complete CERT-In tabular dump of IP addresses, session timestamps, and authentication events.
4. **`E2EE_Cryptographic_Certificate.pdf`**:
   * Formal legal affidavit regarding zero-knowledge client-side encryption.
