import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/exceptions/app_exception.dart';
import '../models/subscription_status.dart';
import '../services/subscription_service.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _subService = SubscriptionService.instance;
  final PageController _pageController = PageController(
    viewportFraction: 0.88,
    initialPage: 1, // Default to Prime Lite (Most Popular)
  );

  int _currentPageIndex = 1;
  bool _isLoading = true;
  bool _isProcessingUpgrade = false;
  SubscriptionStatus? _currentStatus;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final status = await _subService.getMyStatus(forceRefresh: true);
    if (mounted) {
      setState(() {
        _currentStatus = status;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUpgrade(SubscriptionTier tier, {int durationDays = 30}) async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessingUpgrade = true);

    try {
      await _subService.upgradeTier(tier, durationDays: durationDays);
      await _loadStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Upgraded to ${tier.displayName} successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is AppException ? e.message : 'Unable to complete upgrade request. Please try again later.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingUpgrade = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6E1732)),
              )
            : Column(
                children: [
                  const SizedBox(height: 6),

                  // ── 1. Clean Top App Bar (Working Navigation) ──────────────
                  _buildTopAppBar(),

                  const SizedBox(height: 8),

                  // ── 2. Hero Title ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Choose the plan that’s right for you',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E2432),
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── 3. Horizontal 1-Card-Per-Swipe PageView ────────────────
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() => _currentPageIndex = index);
                      },
                      children: [
                        _buildFreePlanCard(),
                        _buildPrimeLitePlanCard(),
                        _buildPrimePlanCard(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── 4. Bottom Horizontal Indicator Dots ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isSelected = _currentPageIndex == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6E1732)
                              : const Color(0xFFDCD2C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }

  // ── Top App Bar with Knots Divider ─────────────────────────────────────────
  Widget _buildTopAppBar() {
    final canPop = Navigator.of(context).canPop();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (canPop)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2B2118), size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              Text(
                'Pricing Plans',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E2432),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Decorative Knot / Line
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 36, height: 1, color: const Color(0xFFE2D6C7)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.all_inclusive_rounded, size: 14, color: Color(0xFFC49A58)),
            ),
            Container(width: 36, height: 1, color: const Color(0xFFE2D6C7)),
          ],
        ),
      ],
    );
  }

  // ── 1. Free Plan Card ──────────────────────────────────────────────────────
  Widget _buildFreePlanCard() {
    final isCurrent = _currentStatus?.isFree == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEADBCE), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header
            Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFF0F2),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFFE94B77),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Free',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2432),
                  ),
                ),
                Text(
                  'Get started at no cost',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF7A726A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹0',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2432),
                  ),
                ),
                Text(
                  'Forever',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF8C827A),
                  ),
                ),
              ],
            ),

            const Divider(height: 16, color: Color(0xFFF0E5D8)),

            // Features list (takes available space cleanly)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFeatureRow('Create Profile', isIncluded: true),
                  _buildFeatureRow('Browse Profiles', isIncluded: true),
                  _buildFeatureRow('Send Interests (5/day)', isIncluded: true),
                  _buildFeatureRow('View Contact Details', isIncluded: false),
                  _buildFeatureRow('Chat', isIncluded: false),
                  _buildFeatureRow('Profile Boost', isIncluded: false),
                  _buildFeatureRow('Who Viewed My Profile', isIncluded: false),
                  _buildFeatureRow('Advanced Filters', isIncluded: false),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You are active on the Free Membership plan.'),
                        backgroundColor: Color(0xFF6E1732),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE94B77),
                  side: const BorderSide(color: Color(0xFFFFB8C6), width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  isCurrent ? 'Current Plan' : 'Continue with Free',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Prime Lite Plan Card (Highlighted) ──────────────────────────────────
  Widget _buildPrimeLitePlanCard() {
    final isCurrent = _currentStatus?.isPrimeLite == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF7C85C), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF7C85C).withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header
            Column(
              children: [
                // Most Popular Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2.5),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8BA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF7C85C)),
                  ),
                  child: Text(
                    'Most Popular',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF5A4300),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),

                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFF8E6),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFD4AF37),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prime Lite',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2432),
                  ),
                ),
                Text(
                  'More visibility, more connections',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF7A726A),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '₹299 ',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E2432),
                        ),
                      ),
                      TextSpan(
                        text: '/ 1 Month',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF8C827A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹799 / 3 Months',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF8C827A),
                  ),
                ),
              ],
            ),

            const Divider(height: 14, color: Color(0xFFF0E5D8)),

            // Features list
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFeatureRow('Everything in Free', isIncluded: true),
                  _buildFeatureRow('Send Interests (15/day)', isIncluded: true),
                  _buildFeatureRow('View Contact Details (25)', isIncluded: true),
                  _buildFeatureRow('Chat (Direct)', isIncluded: true),
                  _buildFeatureRow('Who Viewed My Profile', isIncluded: true),
                  _buildFeatureRow('Profile Boost (1 time / mo)', isIncluded: false),
                  _buildFeatureRow('Advanced Filters (Basic)', isIncluded: false),
                  _buildFeatureRow('Priority Placement', isIncluded: false),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: isCurrent || _isProcessingUpgrade
                    ? null
                    : () => _handleUpgrade(SubscriptionTier.primeLite, durationDays: 30),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7C85C),
                  foregroundColor: const Color(0xFF3B2A00),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: _isProcessingUpgrade
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B2A00)),
                      )
                    : Text(
                        isCurrent ? 'Active Plan' : 'Choose Prime Lite',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Prime VIP Plan Card ─────────────────────────────────────────────────
  Widget _buildPrimePlanCard() {
    final isCurrent = _currentStatus?.isPrime == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFD1DC), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE94B77).withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header
            Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFF0F4),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFE94B77),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Prime VIP',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2432),
                  ),
                ),
                Text(
                  'The complete experience',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF7A726A),
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '₹699 ',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E2432),
                        ),
                      ),
                      TextSpan(
                        text: '/ 1 Month',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF8C827A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹1,999 / 3 Months',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF8C827A),
                  ),
                ),
              ],
            ),

            const Divider(height: 16, color: Color(0xFFF0E5D8)),

            // Features list
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFeatureRow('Everything in Prime Lite', isIncluded: true),
                  _buildFeatureRow('Chat (Unlimited Direct)', isIncluded: true),
                  _buildFeatureRow('Profile Boost (🔥 3x Spotlight)', isIncluded: true),
                  _buildFeatureRow('Advanced Filters (All)', isIncluded: true),
                  _buildFeatureRow('Priority Support', isIncluded: true),
                  _buildFeatureRow('Read Receipts', isIncluded: true),
                  _buildFeatureRow('Highlight Profile (Top Rank)', isIncluded: true),
                  _buildFeatureRow('View 60 Contact Details', isIncluded: true),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: isCurrent || _isProcessingUpgrade
                    ? null
                    : () => _handleUpgrade(SubscriptionTier.prime, durationDays: 90),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE94B77),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: _isProcessingUpgrade
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isCurrent ? 'Active Plan' : 'Choose Prime VIP',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String title, {required bool isIncluded}) {
    return Row(
      children: [
        Icon(
          isIncluded ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isIncluded ? const Color(0xFF5AB374) : const Color(0xFFB5ADA6),
          size: 15,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isIncluded ? const Color(0xFF332D28) : const Color(0xFF8C827A),
              fontWeight: isIncluded ? FontWeight.w500 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
