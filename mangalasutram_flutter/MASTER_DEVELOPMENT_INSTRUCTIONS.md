# Mangalasutram — Master Development & AI Implementation Instructions

## 1. Project Objective

Mangalasutram is a premium Hindu Brahmin matrimony application intended for real production launch on:

* Google Play Store
* Apple App Store

Target launch: **end of the current month**.

The application must feel like a genuine commercial product, not a college prototype or demonstration application.

The development philosophy is:

> **Simple enough to finish. Production-ready enough to launch. Flexible enough to change.**

Do not unnecessarily complicate the system.

Do not simplify away essential security, reliability, backend validation, or UX quality.

---

# 2. Core Product Vision

Mangalasutram is exclusively designed for the **Hindu Brahmin community**.

The product should communicate:

* Trust
* Tradition
* Premium quality
* Privacy
* Authenticity
* Modern technology
* Cultural accuracy
* Ease of use

The visual direction is:

* Premium
* Elegant
* Modern
* Apple-style in terms of cleanliness and polish
* Burgundy / Gold / Cream visual language
* Sophisticated typography
* Excellent spacing
* Subtle animations
* Strong visual hierarchy
* High-quality profile presentation

Do not turn the application into a generic dating application.

Do not introduce unnecessary dating-app patterns simply because they are common elsewhere.

---

# 3. Most Important Development Rule

## The existing architecture is NOT a prison.

The current implementation is a baseline.

The client may request:

* New features
* Removal of features
* Changes to existing features
* Different workflows
* Different UI
* Different profile fields
* Different matching rules
* Different subscription rules
* Different admin capabilities
* Different screens
* Different navigation
* Different business rules

When the client requests a change:

**Adapt the implementation.**

Do not respond with:

> "The current architecture doesn't support this."

Instead:

1. Understand the requested change.
2. Identify what existing components are affected.
3. Determine the smallest clean modification.
4. Implement it without unnecessarily breaking unrelated functionality.
5. Refactor only where genuinely necessary.

The system should be designed so that reasonable changes are possible.

---

# 4. Architecture Philosophy

Use a **modular but practical architecture**.

Do NOT build an unnecessarily sophisticated enterprise architecture.

Do NOT introduce technologies merely because they are technically impressive.

Every architectural decision should answer:

> "Does this make the application more reliable, secure, maintainable, or easier to change?"

If the answer is no, don't add it.

Prefer:

* Clear modules
* Reusable components
* Reusable services
* Centralized configuration
* Proper database constraints
* Server-side authorization
* Simple SQL functions where appropriate
* Small, understandable Edge Functions
* Clean Flutter architecture
* Clear naming
* Minimal dependencies

Avoid:

* Unnecessary microservices
* Kubernetes
* Event buses without a real requirement
* Complex message queues
* Multiple databases without a real need
* Artificial abstraction layers
* Overly generic frameworks
* AI/ML where deterministic logic is sufficient
* Premature optimization
* Complex caching systems without demonstrated need

---

# 5. Current Technology Stack

The established stack is:

### Mobile

Flutter + Dart

Target:

* Android
* iOS

### Backend

Supabase

Including:

* PostgreSQL
* Supabase Auth
* Supabase Storage
* Supabase Realtime
* Row Level Security

### Serverless Logic

Deno Edge Functions

Used for sensitive server-side operations such as:

* OTP processing
* Email delivery
* Sensitive validation
* Backend-controlled operations

### Email

Resend through appropriate server-side logic.

### Storage

Supabase Storage for profile photographs and other approved user media.

Do not introduce another backend unless there is a genuine requirement.

---

# 6. Existing Completed Infrastructure

Treat the following as already established unless the current code/reference explicitly shows otherwise.

## Authentication

* Custom 6-digit OTP flow
* Supabase Auth
* OTP sending
* OTP verification
* Secure Edge Functions
* Signup flow
* Authentication routing

## Profile Onboarding

* 8-step onboarding
* 30+ profile data points
* Cultural information
* Gothram
* Nakshatram
* Rashi
* Education
* Occupation
* Family information
* Other profile information

## Profile Completeness

An AuthRouter currently uses profile completeness to determine whether onboarding must continue.

The existing threshold is approximately 60%.

Do not change this value casually.

If the client changes the onboarding rules, update the completeness calculation appropriately.

## Profile Management

Existing capabilities include:

* Basic information editing
* Family details
* Traditional information
* Profile photographs
* Main profile photo
* Additional gallery photographs
* Supabase Storage
* Cache-busting / refreshed profile images

## Core UI

Existing major areas include:

* Home / Matches
* Profile Detail
* Interests
* Edit Profile
* Edit Photos

The established design language should remain consistent unless the client explicitly requests a redesign.

---

# 7. UI/UX Instructions

## Always follow provided references

If the user/client provides:

* Reference images
* Screenshots
* Figma designs
* Existing application screenshots
* UI examples
* Videos
* Design specifications
* Written visual requirements

Treat them as authoritative design references.

Do not invent a completely different design.

Use the reference as the visual source of truth.

If a reference image shows:

* spacing
* card structure
* typography hierarchy
* button placement
* colors
* icon positioning
* image proportions
* navigation
* component hierarchy

replicate the design intent closely.

Do not blindly copy elements that are technically inappropriate for Flutter or the target platform, but preserve the intended appearance and interaction.

---

# 8. When References Are Incomplete

If the reference does not specify something:

Do NOT hallucinate a complicated requirement.

Use the simplest reasonable interpretation that:

1. Matches the existing Mangalasutram design system.
2. Does not conflict with existing functionality.
3. Is consistent with the surrounding screens.
4. Is practical to implement.
5. Can be changed later.

If the missing detail materially affects functionality or business logic, ask for clarification instead of inventing it.

---

# 9. "As Per My Vision" Rule

When the owner provides a specific product vision, prioritize that vision over generic AI assumptions.

For example:

If the owner says:

> "I want this screen to feel premium and minimal."

Do not automatically add:

* excessive animations
* gradients everywhere
* unnecessary cards
* gamification
* social features
* AI recommendations
* complicated dashboards

Interpret the vision first.

The objective is to build **Mangalasutram**, not an AI-generated generic matrimony template.

---

# 10. UI Quality Standard

Every production screen should properly handle:

### Normal state

The intended populated interface.

### Loading state

Show a polished loading experience.

### Empty state

Explain clearly when there is no data.

### Error state

Give the user a meaningful message.

### Retry state

Where appropriate, allow retrying.

### Long content

Ensure content does not overflow.

### Different screen sizes

The UI must adapt to:

* Small Android phones
* Large Android phones
* iPhones
* Different aspect ratios
* Different text sizes

Never assume one fixed screen dimension.

---

# 11. Responsive Design

Never hardcode a design around one specific device.

For example:

Do not design exclusively around one Oppo, Samsung, iPhone, or emulator resolution.

Use:

* Responsive layouts
* Flexible widgets
* Safe areas
* Appropriate constraints
* Scrollable content where necessary
* Adaptive spacing

The UI should remain visually correct across supported devices.

---

# 12. Do Not Overdesign

Avoid unnecessary:

* Animations
* Lottie files
* Parallax
* Particle effects
* 3D elements
* Excessive gradients
* Glassmorphism everywhere
* Excessive shadows
* Decorative elements that reduce usability

Premium does not mean complicated.

Premium means:

> **Good typography + spacing + hierarchy + consistency + responsiveness + restraint.**

---

# 13. Backend Security Rules

The backend must be treated as untrusted-client architecture.

Never assume the Flutter application is secure merely because the UI hides something.

Anything sensitive must be enforced server-side.

Examples:

* User permissions
* Profile ownership
* Contact-number visibility
* Subscription entitlements
* Chat permissions
* Interest permissions
* Admin permissions
* Profile moderation
* Private profile information
* Storage access

Do not rely exclusively on:

```text
if (isPremium) { ... }
```

inside Flutter.

A malicious user can bypass frontend logic.

Use appropriate:

* Supabase RLS
* Database policies
* Server-side validation
* Edge Functions
* Database constraints

where required.

---

# 14. Supabase RLS

RLS is a critical production requirement.

For every sensitive table, explicitly determine:

* Who can SELECT?
* Who can INSERT?
* Who can UPDATE?
* Who can DELETE?

Never assume default behavior is safe.

Do not disable RLS simply because it makes development easier.

Do not use broad policies such as:

> authenticated users can access everything

unless that access is genuinely intended.

---

# 15. Service Role Key

Never expose the Supabase service-role key inside:

* Flutter code
* GitHub
* APK
* IPA
* public configuration
* client-side JavaScript

The service-role key belongs only in trusted server-side environments.

---

# 16. OTP Security

OTP functionality must be treated as a security-sensitive component.

Consider:

* Expiration
* Attempt limits
* Rate limiting
* Secure verification
* Abuse prevention
* Appropriate error messages
* Avoiding account enumeration
* Server-side validation

Never expose OTP verification secrets in the mobile application.

Do not log OTP values.

Do not place sensitive OTP information in analytics.

---

# 17. Storage Security

Profile images are user data.

Do not make private profile images publicly accessible unless that is an intentional product decision.

Use appropriate:

* Storage policies
* Access rules
* Signed URLs where required
* File type validation
* File size restrictions

Do not blindly allow arbitrary files to be uploaded.

---

# 18. Personal Information

Matrimony profiles can contain sensitive personal information.

Treat information such as:

* Phone numbers
* Email addresses
* Family details
* Photos
* Location-related information
* Personal preferences
* Profile information

as protected user data.

Only expose information according to the application's actual privacy rules.

Do not assume:

> "The user is logged in, therefore they can see everything."

---

# 19. Matching Engine Philosophy

The first production matching engine should NOT be unnecessarily complicated.

Start with a deterministic PostgreSQL-based matching system.

Suggested conceptual pipeline:

```text
Candidate Pool
      ↓
Basic Eligibility
      ↓
Hard Filters
      ↓
Mutual Preference Validation
      ↓
Preference Scoring
      ↓
Ranking
      ↓
Home Feed
```

The system should be:

* Explainable
* Testable
* Adjustable
* Fast enough for the expected user base
* Easy to modify

Do not introduce machine learning merely to make the system appear advanced.

If SQL scoring solves the current requirement, use SQL scoring.

---

# 20. Matching Rules Must Be Configurable

Do not scatter matching rules throughout Flutter.

Avoid logic such as:

```dart
if (age > ...)
if (occupation == ...)
if (diet == ...)
```

across multiple UI files.

Keep matching logic centralized.

This makes future client changes much easier.

If the client later says:

> "Occupation should have lower weight."

That should be a manageable backend change, not a complete application rewrite.

---

# 21. Partner Preferences

Partner Preferences should be designed as a configurable system.

Potential categories may include:

* Age
* Education
* Occupation
* Location
* Dietary preference
* Traditional preferences
* Other approved partner requirements

But do not automatically add every possible preference.

Only implement requirements supported by:

* the client's specification
* the approved product design
* the actual business requirement

Do not invent dozens of filters merely because they are possible.

---

# 22. Interests

The Interests system should support the actual approved workflow.

At minimum, the architecture should be capable of handling:

* Send interest
* Receive interest
* Accept
* Decline
* Prevent duplicate requests
* Appropriate status changes
* Permission checks

Database constraints should prevent invalid duplicate states where appropriate.

---

# 23. Chat

Chat should only become available according to the approved business rule.

For example, if the rule is:

```text
Interest sent
      ↓
Accepted
      ↓
Chat enabled
```

then the backend should enforce that relationship.

Do not depend solely on Flutter navigation to restrict chat access.

Supabase Realtime can provide live updates, but the underlying authorization must still be correct.

---

# 24. Admin Dashboard

The admin dashboard is a separate restricted system.

It should eventually provide appropriate capabilities such as:

* User management
* Profile review
* Verification
* Moderation
* Suspicious profile handling
* Reports
* Basic metrics
* Appropriate account actions

Do not build a giant enterprise administration platform for the MVP.

Build the functionality actually required to operate Mangalasutram.

---

# 25. Admin Security

Admin privileges are highly sensitive.

Never identify an admin merely because Flutter says:

```text
isAdmin = true
```

The backend must verify administrator authorization.

Separate:

* normal user
* moderator
* administrator
* owner-level privileges

only if the actual product requires these distinctions.

Do not invent a complex role hierarchy without a requirement.

---

# 26. Payments

Payment integration should be implemented only after the subscription rules are finalized.

Possible providers may include:

* Razorpay
* Stripe

Select the appropriate provider based on the actual launch requirements and supported markets/platforms.

Never treat:

```text
payment_success = true
```

from the client as sufficient proof of payment.

Payment verification must happen through trusted backend mechanisms.

Subscription entitlements must be server-controlled.

---

# 27. Do Not Build AI Unnecessarily

Mangalasutram does not need AI simply because it is an AI-era application.

Do not add:

* AI matchmaking
* AI profile generation
* AI chat recommendations
* AI compatibility scoring
* AI moderation

unless there is an actual approved requirement.

A reliable deterministic system is better than an impressive but unnecessary AI system.

AI can be added later if the product actually benefits from it.

---

# 28. Do Not Hallucinate Requirements

This is a critical instruction.

Never invent:

* Features
* APIs
* Database tables
* User permissions
* Legal requirements
* Business rules
* UI components
* Matching rules
* Subscription rules
* Client preferences
* Backend behavior

without evidence.

If information is missing:

### If it is a minor visual decision:

Use a simple design consistent with the existing system.

### If it affects architecture or business logic:

Ask for clarification.

### If an external fact is required:

Verify it instead of guessing.

---

# 29. Never Pretend Something Was Implemented

Do not say:

> "Implemented."

unless the change was actually made.

Do not claim:

* database migration completed
* RLS configured
* Edge Function deployed
* API working
* payment verified
* app tested
* App Store ready

unless it was actually verified.

Be explicit about the difference between:

* Designed
* Planned
* Coded
* Tested
* Deployed
* Verified

---

# 30. When Existing Code Is Available

Before changing code:

1. Inspect the existing implementation.
2. Understand its dependencies.
3. Identify what currently works.
4. Determine what must change.
5. Make the smallest clean modification.
6. Avoid breaking existing functionality.

Do not rewrite entire files just because a small modification is required.

Do not replace working architecture with a new architecture without a real reason.

---

# 31. Preserve Existing Functionality

When implementing a new feature:

> Existing working functionality must continue working unless the new requirement explicitly replaces it.

After changes, check:

* Authentication
* Navigation
* Profile loading
* Profile editing
* Photos
* Onboarding
* Existing database operations
* Existing UI flows

Do not fix one screen by silently breaking another.

---

# 32. Dependency Discipline

Do not add packages casually.

Before introducing a package, ask:

* Is Flutter's built-in capability insufficient?
* Is the package actively maintained?
* Does it introduce unnecessary complexity?
* Is it compatible with Android and iOS?
* Does it introduce security/privacy concerns?
* Is it actually required?

Prefer fewer high-quality dependencies.

---

# 33. Database Design

Database schema should be:

* Relational
* Clear
* Consistent
* Properly constrained
* Easy to query
* Easy to modify

Use:

* Primary keys
* Foreign keys
* Unique constraints
* Appropriate indexes
* Appropriate nullable/non-nullable fields
* Timestamps
* Check constraints where useful

Do not create separate tables for every tiny concept without a real reason.

Do not put everything into one giant JSON column either.

Use PostgreSQL according to the actual data relationships.

---

# 34. Performance

Do not prematurely optimize.

First make it:

1. Correct
2. Secure
3. Reliable
4. Maintainable

Then optimize actual bottlenecks.

For profile feeds:

* Use pagination
* Avoid downloading unnecessary data
* Optimize image sizes
* Avoid repeated database calls
* Select only required columns where practical

Do not load hundreds of profiles at once.

---

# 35. Images

Profile photographs are likely to be one of the largest performance costs.

Use appropriate:

* Compression
* Resolution
* Thumbnail/preview strategy where useful
* Lazy loading
* Caching
* Storage organization

Do not repeatedly download original high-resolution images when a smaller display version is sufficient.

---

# 36. Error Handling

Never expose raw technical errors to users.

Avoid showing messages such as:

```text
PostgrestException(...)
```

or:

```text
JWT expired
```

directly to normal users.

Translate technical failures into useful messages such as:

> "We couldn't load your matches. Please try again."

Log technical information appropriately for debugging.

---

# 37. Logging

Do not log sensitive information.

Never casually log:

* Passwords
* OTPs
* Access tokens
* Service-role keys
* Private user information
* Payment secrets

Development logging must be reviewed before production release.

---

# 38. Environment and Secrets

Separate:

* Development
* Testing
* Production

Do not commit secrets into GitHub.

Do not place production secrets in publicly accessible configuration.

Review the repository before release.

---

# 39. Testing Before Launch

At minimum, test the complete critical journey:

```text
Install
 ↓
Open App
 ↓
Register
 ↓
Receive OTP
 ↓
Verify OTP
 ↓
Create Profile
 ↓
Complete Onboarding
 ↓
Upload Photo
 ↓
Edit Profile
 ↓
Set Preferences
 ↓
View Matches
 ↓
Send Interest
 ↓
Accept Interest
 ↓
Chat
 ↓
Subscription
 ↓
Logout
 ↓
Login Again
```

Also test invalid cases.

Examples:

* Incorrect OTP
* Expired OTP
* Too many OTP attempts
* Network failure
* Empty profile
* Invalid data
* Duplicate interest
* Unauthorized profile access
* Unauthorized chat access
* Expired session
* Deleted user
* Missing image
* Slow network

---

# 40. Android and iOS

Do not assume:

> "It works on Android, so iOS is finished."

Test both platforms.

Check:

* Navigation
* Keyboard behavior
* Permissions
* Image selection
* Camera/photo library
* Safe areas
* Fonts
* Push notifications if implemented
* Deep links if implemented
* Authentication
* App lifecycle
* Background/foreground behavior
* Performance

---

# 41. Store Launch Requirements

Before launch, verify the actual current Google Play and Apple App Store requirements rather than relying on memory.

Prepare appropriate:

* App icon
* Screenshots
* App description
* Privacy information
* Terms
* Account deletion workflow if required
* Permission explanations
* Contact/support information
* Production configuration
* Release signing
* Versioning
* Crash/error monitoring where appropriate

Do not claim store readiness until these have actually been checked.

---

# 42. Privacy and Legal Requirements

Do not invent legal claims.

If legal/compliance requirements are needed, verify current requirements from authoritative sources.

The application should have appropriate production documentation such as:

* Privacy Policy
* Terms of Service
* Appropriate grievance/support information
* Data handling disclosures
* Account/data deletion process where applicable

Legal text should not be generated as if it were professional legal advice without appropriate review.

---

# 43. Client Change Management

When the client requests a change, classify it:

### Category A — UI change

Example:

> Change the button style.

Implement directly.

### Category B — Workflow change

Example:

> Users should be able to edit this field later.

Check affected screens and backend rules.

### Category C — Data-model change

Example:

> Add another partner preference.

Update database/backend/UI carefully.

### Category D — Business-rule change

Example:

> Only Premium members can initiate conversations.

Update:

* Backend authorization
* Database rules where necessary
* Flutter UI
* Subscription logic
* Testing

Do not implement only the visual portion.

---

# 44. Never Patch Only the UI for Backend Requirements

If a client changes a business rule, check all layers.

For example:

Client says:

> "Only approved profiles should appear in matches."

Do not simply hide unapproved profiles in Flutter.

The proper implementation should consider:

```text
Database
 ↓
Matching query/function
 ↓
Authorization
 ↓
Flutter UI
```

The UI should reflect backend truth.

---

# 45. Avoid "Magic Numbers"

Where business rules may change, avoid scattering numbers throughout the application.

For example, instead of repeatedly hardcoding:

```text
60
```

for profile completeness, centralize the rule.

Likewise for:

* subscription limits
* photo limits
* preference weights
* age limits
* pagination size
* OTP expiry

But do not build an enormous configuration-management system for every value.

Centralize only values that realistically may change.

---

# 46. Feature Flags

Use feature flags only where they genuinely help.

A simple configurable approach is preferable.

Do not create a sophisticated feature-flag platform for an MVP.

If a feature may be enabled/disabled during launch testing, a simple controlled configuration may be sufficient.

---

# 47. UI Consistency

Reuse established design elements.

Maintain consistent:

* Buttons
* Typography
* Colors
* Cards
* Input fields
* Bottom navigation
* App bars
* Spacing
* Icons
* Error messages
* Loading indicators
* Empty states

Do not create a completely different visual language for every screen.

---

# 48. Reference Images Have Priority

When a client/reference image exists:

> **Reference image > generic AI design preference**

The AI should not decide:

> "I think a carousel would look better."

If the reference clearly uses a list, build a list.

If the reference clearly uses cards, build cards.

If the reference clearly shows a particular hierarchy, preserve it.

Improvements are allowed only when they:

* Preserve the design intent
* Improve usability
* Are technically necessary
* Are requested

---

# 49. Do Not Blindly Copy References

References are authoritative for design direction, not necessarily for technical implementation.

For example:

A screenshot may show:

* A static list

But production implementation may require:

* Pagination
* Loading state
* Empty state
* Error state

Implement the underlying production behavior while preserving the visual intent.

---

# 50. AI Agent Working Procedure

Before modifying anything:

## Step 1 — Understand

Read:

* Existing code
* Existing database structure
* Relevant screens
* Existing services
* Provided references
* Client requirements

## Step 2 — State the actual change

Clearly identify:

> What exists now → What needs to change → Why.

## Step 3 — Check dependencies

Determine whether the change affects:

* UI
* State
* Database
* RLS
* Edge Functions
* Authentication
* Storage
* Matching
* Payments
* Navigation

## Step 4 — Implement the smallest correct solution

Do not rewrite unrelated components.

## Step 5 — Test

Test:

* Happy path
* Failure path
* Permissions
* Different devices/screen sizes where relevant

## Step 6 — Report honestly

State:

* What was changed
* What was tested
* What remains
* Any limitations
* Any assumptions

Never pretend unverified work is complete.

---

# 51. How the AI Should Handle Uncertainty

If uncertain about a technical implementation:

Do not hallucinate.

Use one of these approaches:

### If existing code answers it:

Inspect the code.

### If documentation answers it:

Check the official documentation.

### If the requirement is ambiguous:

Ask for clarification.

### If there are multiple reasonable options:

Recommend the simplest production-ready option and explain the trade-off briefly.

Never invent APIs, package behavior, Supabase functionality, or platform requirements.

---

# 52. What NOT To Do

## Do not:

* Overengineer
* Hallucinate requirements
* Invent client preferences
* Rewrite working code unnecessarily
* Add unnecessary technologies
* Add AI without a requirement
* Put security logic only in Flutter
* Expose secrets
* Disable RLS for convenience
* Create huge abstractions
* Add unnecessary dependencies
* Build enterprise infrastructure prematurely
* Claim untested functionality works
* Assume Android testing means iOS is complete
* Ignore loading/error/empty states
* Ignore accessibility/usability
* Copy reference images blindly
* Change the design language without reason
* Break existing features while adding new ones
* Hardcode business logic throughout the UI
* Assume payment success from client-side state
* Expose private user data unnecessarily
* Use fake/dummy production data without clearly marking it
* Invent legal/compliance requirements
* Delay essential security until after launch

---

# 53. What TO Do

## Always:

* Follow the client's actual vision.
* Follow provided references.
* Inspect existing implementation first.
* Keep architecture modular.
* Keep implementation understandable.
* Protect sensitive data.
* Enforce permissions server-side.
* Use RLS correctly.
* Validate backend inputs.
* Handle failures gracefully.
* Make UI responsive.
* Maintain the existing design system.
* Test critical flows.
* Consider both Android and iOS.
* Keep client changes possible.
* Prefer deterministic solutions when they are sufficient.
* Verify uncertain facts.
* Tell the truth about implementation status.
* Optimize only where useful.
* Keep production launch as the goal.

---

# 54. Definition of "Production Ready"

A feature is NOT production-ready merely because:

> "The screen works."

A feature should be considered production-ready when:

* The intended UI works.
* The data flow works.
* Backend authorization is correct.
* Invalid input is handled.
* Network failures are handled.
* Loading states exist.
* Empty states exist where necessary.
* Errors are handled.
* Sensitive information is protected.
* The feature works after restarting the app.
* Authentication/session behavior is correct.
* Relevant Android behavior works.
* Relevant iOS behavior works.
* Existing functionality has not been broken.
* The implementation is maintainable.
* The feature matches the approved product requirement.

---

# 55. Definition of "Simple"

Simple does NOT mean:

> "Do the minimum possible."

Simple means:

> "Use the smallest architecture that correctly solves the real production requirement."

Example:

If PostgreSQL + Supabase Edge Functions solves a problem, use them.

Do not introduce:

```text
Microservice
+
Redis
+
Kafka
+
Kubernetes
+
Separate API Gateway
+
Multiple databases
```

unless the actual scale or requirement demands it.

---

# 56. Definition of "Premium"

Premium does NOT mean:

> "Add more visual effects."

Premium means:

* Excellent spacing
* Strong typography
* Consistent design
* High-quality images
* Smooth interactions
* Fast response
* Clear navigation
* Good error handling
* Privacy
* Reliability
* Attention to detail

The user should feel that Mangalasutram is a serious commercial product.

---

# 57. Current Development Priority

The immediate development sequence should remain approximately:

```text
Partner Preferences
        ↓
Matching Engine
        ↓
Interests
        ↓
Chat
        ↓
Admin Dashboard
        ↓
Payments
        ↓
Production QA
        ↓
Play Store + App Store Launch
```

However, this sequence is **not immutable**.

If a client requirement changes the priority, reorganize the development plan accordingly.

---

# 58. Final Principle

The AI/developer must always remember:

> **Mangalasutram is being built for a real launch, not merely for demonstration.**

Therefore:

**Do not overengineer it.**

**Do not underbuild critical functionality.**

**Do not hallucinate.**

**Do not blindly follow generic AI suggestions.**

**Do not ignore the client's vision.**

**Do not treat the current architecture as unchangeable.**

**Do not sacrifice security for speed.**

**Do not sacrifice essential UX quality for speed.**

**Do not claim something is complete until it has actually been implemented and verified.**

Build each feature so that it is:

> **Simple → Secure → Production-ready → Maintainable → Changeable.**

And when a reference image or explicit client instruction is provided:

> **Follow the reference and the client's vision first; use your technical judgment to make the implementation production-ready without changing the intended product unnecessarily.**

This is the standing development philosophy for Mangalasutram.
