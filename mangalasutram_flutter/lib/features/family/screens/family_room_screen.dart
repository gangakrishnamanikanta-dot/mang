import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/supabase_service.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../../profile/services/profile_service.dart';
import '../services/family_service.dart';
import 'family_group_chat_screen.dart';

class FamilyRoomScreen extends StatefulWidget {
  const FamilyRoomScreen({super.key});

  @override
  State<FamilyRoomScreen> createState() => _FamilyRoomScreenState();
}

class _FamilyRoomScreenState extends State<FamilyRoomScreen> {
  final _familyService = FamilyService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _circleData;
  List<FamilyMemberModel> _members = [];
  List<FamilyReviewModel> _reviews = [];
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadCircle();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      SupabaseService.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _loadCircle({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }
    final circle = await _familyService.getOrCreateCircle();
    if (circle != null && circle['circle_id'] != null) {
      final circleId = circle['circle_id'] as String;
      final results = await Future.wait([
        _familyService.getMembers(circleId),
        _familyService.getReviews(circleId),
      ]);
      if (mounted) {
        setState(() {
          _circleData = circle;
          _members = results[0] as List<FamilyMemberModel>;
          _reviews = results[1] as List<FamilyReviewModel>;
          _isLoading = false;
        });
        _subscribeRealtime(circleId);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime(String circleId) {
    try {
      if (_realtimeChannel != null) return;
      _realtimeChannel = SupabaseService.client
          .channel('public:family_room_sync:$circleId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'family_profile_reviews',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_circle_id',
              value: circleId,
            ),
            callback: (_) {
              if (mounted) _loadCircle(showSpinner: false);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'family_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_circle_id',
              value: circleId,
            ),
            callback: (_) {
              if (mounted) _loadCircle(showSpinner: false);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[FamilyRoomScreen Realtime Error]: $e');
    }
  }

  void _openFamilyGroupChat() {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FamilyGroupChatScreen()),
    ).then((_) => _loadCircle(showSpinner: false));
  }

  Future<void> _openCandidateProfile(String profileId) async {
    HapticFeedback.selectionClick();
    final profile = await ProfileService().getProfileById(profileId);
    if (!mounted) return;
    if (profile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(profile: profile),
        ),
      );
    }
  }

  void _showInviteModal() {
    FocusScope.of(context).unfocus();
    final code = _circleData?['invite_code'] as String? ?? 'MANG-ROOM';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFDF9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6C8B4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Invite Family Members',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6E1732),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this secret Vedic invite code with your parents or trusted guardians (max 2) to review alliances together in your private Family Room.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6D635B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EFE6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC99A4B), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    code,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: const Color(0xFF6E1732),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Color(0xFFC99A4B),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Family invite code copied! Share on WhatsApp.',
                          ),
                          backgroundColor: Color(0xFF6E1732),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showJoinModal() {
    FocusScope.of(context).unfocus();
    final codeCtrl = TextEditingController();
    String selectedRole = 'Father';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFDF9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6C8B4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Join Existing Family Room',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6E1732),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Enter Invite Code (e.g. MANG-2039)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: const [
                    DropdownMenuItem(
                      value: 'Father',
                      child: Text('Father (నాన్నగారు)'),
                    ),
                    DropdownMenuItem(
                      value: 'Mother',
                      child: Text('Mother (అమ్మగారు)'),
                    ),
                    DropdownMenuItem(
                      value: 'Brother',
                      child: Text('Brother (సోదరుడు)'),
                    ),
                    DropdownMenuItem(
                      value: 'Sister',
                      child: Text('Sister (సోదరి)'),
                    ),
                    DropdownMenuItem(
                      value: 'Relative',
                      child: Text('Relative (బంధువులు)'),
                    ),
                    DropdownMenuItem(
                      value: 'Guardian',
                      child: Text('Guardian (పెద్దలు)'),
                    ),
                  ],
                  onChanged: (val) =>
                      setModalState(() => selectedRole = val ?? 'Father'),
                  decoration: InputDecoration(
                    labelText: 'Your Relationship to Candidate',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      FocusScope.of(ctx).unfocus();
                      final result = await _familyService.joinCircleWithResult(
                        inviteCode: codeCtrl.text,
                        role: selectedRole,
                        displayName: selectedRole,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (result['success'] == true) {
                        _loadCircle();
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message'] as String? ??
                                    'Unable to join family room.',
                              ),
                              backgroundColor: const Color(0xFFD32F2F),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6E1732),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Join Family Circle'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF8F1),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF6E1732),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Family Room • కుటుంబ వేదిక',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF6E1732),
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.forum_outlined,
              color: Color(0xFF6E1732),
            ),
            tooltip: 'Open Family Group Chat',
            onPressed: _openFamilyGroupChat,
          ),
          IconButton(
            icon: const Icon(
              Icons.group_add_outlined,
              color: Color(0xFF6E1732),
            ),
            tooltip: 'Invite Family',
            onPressed: _showInviteModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6E1732)),
            )
          : RefreshIndicator(
              onRefresh: () => _loadCircle(showSpinner: false),
              color: const Color(0xFF6E1732),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  // 1. Auspicious Family Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6E1732), Color(0xFF8B263E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6E1732).withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _circleData?['family_name'] as String? ??
                                    'Sacred Family Circle',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.playfairDisplay(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if ((_circleData?['invite_code'] as String?)
                                    ?.isNotEmpty ??
                                false)
                              GestureDetector(
                                onTap: _showInviteModal,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC99A4B),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _circleData?['invite_code'] as String? ??
                                            '',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.copy_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A private sanctuary where parents and candidate review alliances and deliberate in real time.',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _openFamilyGroupChat,
                              icon: const Icon(
                                Icons.chat_bubble_rounded,
                                size: 15,
                                color: Color(0xFF6E1732),
                              ),
                              label: Text(
                                'Family Group Chat',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6E1732),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE6C786),
                                foregroundColor: const Color(0xFF6E1732),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _showInviteModal,
                              icon: const Icon(
                                Icons.share_rounded,
                                size: 15,
                                color: Color(0xFFFFFDF9),
                              ),
                              label: Text(
                                'Invite Parent',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFC99A4B),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _showJoinModal,
                              child: Text(
                                'Join via Code',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFFE5D5C5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Connected Family Members Row
                  Text(
                    'Family Circle Members (${_members.length})',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B2F2F),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 92,
                    child: _members.isEmpty
                        ? Center(
                            child: Text(
                              'No family members joined yet. Tap Invite Parent to share your code.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _members.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 14),
                            itemBuilder: (ctx, idx) {
                              final m = _members[idx];
                              final isCand =
                                  m.role.toLowerCase() == 'candidate';
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isCand
                                            ? const Color(0xFFC99A4B)
                                            : const Color(0xFF6E1732)
                                                .withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: const Color(0xFFEADBCE),
                                      child: Icon(
                                        isCand
                                            ? Icons.person_rounded
                                            : Icons.family_restroom_rounded,
                                        color: const Color(0xFF6E1732),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    m.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2B2118),
                                    ),
                                  ),
                                  Text(
                                    m.role,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF8C7B6E),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Shared Alliance Discussions List
                  Text(
                    'Alliances Under Family Discussion (${_reviews.length})',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B2F2F),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_reviews.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5D5C5)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.forum_outlined,
                            size: 48,
                            color: Color(0xFFC99A4B),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Alliances in Family Discussion Yet',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6E1732),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'When browsing profiles, tap the Family Room icon to share an alliance here for parent approval and deliberation.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._reviews.map((r) => _buildReviewCard(r)),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildReviewCard(FamilyReviewModel r) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeLabel;

    switch (r.reaction.toLowerCase()) {
      case 'shortlist':
        badgeColor = const Color(0xFF2E7D32);
        badgeIcon = Icons.check_circle_rounded;
        badgeLabel = 'Shortlisted by Family';
        break;
      case 'decline':
        badgeColor = const Color(0xFFD32F2F);
        badgeIcon = Icons.cancel_rounded;
        badgeLabel = 'Declined';
        break;
      default:
        badgeColor = const Color(0xFFC99A4B);
        badgeIcon = Icons.help_outline_rounded;
        badgeLabel = 'Needs Deliberation';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEADBCE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           InkWell(
            onTap: () => _openCandidateProfile(r.targetProfileId),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 54,
                    height: 54,
                    color: const Color(0xFFEADBCE),
                    child: r.candidatePhoto != null &&
                            r.candidatePhoto!.isNotEmpty
                        ? Image.network(r.candidatePhoto!, fit: BoxFit.cover)
                        : const Icon(Icons.person, color: Color(0xFF6E1732)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.candidateName ?? 'Alliance Member',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF332D28),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.candidateCity ?? 'Location not disclosed',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF8C827A),
                        ),
                      ),
                      if (r.reviewerRole != null || r.reviewerName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Shared by ${r.reviewerRole ?? r.reviewerName}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6E1732),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        badgeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (r.note != null && r.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF0E5D8)),
              ),
              child: Text(
                '💬 "${r.note!}"',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF5A4A42),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0E5D8)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Family Vote:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8C827A),
                ),
              ),
              const Spacer(),
              _buildVoteChip(
                label: 'Agree',
                icon: Icons.check_circle_outline_rounded,
                selected: r.reaction == 'shortlist',
                activeColor: const Color(0xFF2E7D32),
                onTap: () => _updateReviewReaction(r, 'shortlist'),
              ),
              const SizedBox(width: 6),
              _buildVoteChip(
                label: 'Discuss',
                icon: Icons.chat_bubble_outline_rounded,
                selected: r.reaction == 'discuss',
                activeColor: const Color(0xFFC99A4B),
                onTap: () => _updateReviewReaction(r, 'discuss'),
              ),
              const SizedBox(width: 6),
              _buildVoteChip(
                label: 'Pass',
                icon: Icons.close_rounded,
                selected: r.reaction == 'decline',
                activeColor: const Color(0xFFD32F2F),
                onTap: () => _updateReviewReaction(r, 'decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoteChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFFF6EFE6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : const Color(0xFFEADBCE),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? activeColor : const Color(0xFF8C827A),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? activeColor : const Color(0xFF5A4A42),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateReviewReaction(
    FamilyReviewModel r,
    String newReaction,
  ) async {
    HapticFeedback.selectionClick();
    final success = await _familyService.updateReviewReaction(
      reviewId: r.id,
      reaction: newReaction,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newReaction == 'shortlist'
                ? 'Alliance marked as Shortlisted by Family 🪔'
                : newReaction == 'decline'
                    ? 'Alliance marked as Declined'
                    : 'Alliance marked for Family Discussion 💬',
          ),
          backgroundColor: const Color(0xFF6E1732),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadCircle(showSpinner: false);
    }
  }
}
