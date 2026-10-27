import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/theme.dart';
import '../../auth/services/supabase_service.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../../profile/services/profile_service.dart';
import '../services/family_service.dart';
import 'family_room_screen.dart';

class FamilyGroupChatScreen extends StatefulWidget {
  const FamilyGroupChatScreen({super.key});

  @override
  State<FamilyGroupChatScreen> createState() => _FamilyGroupChatScreenState();
}

class _FamilyGroupChatScreenState extends State<FamilyGroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FamilyService _familyService = FamilyService.instance;

  bool _isLoading = true;
  bool _isSending = false;
  String? _circleId;
  String _familyName = 'Family Group';
  String? _inviteCode;
  List<FamilyMemberModel> _members = [];
  List<FamilyMessageModel> _messages = [];
  RealtimeChannel? _realtimeChannel;

  String? get _currentUserId => SupabaseService.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _initFamilyChat();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      SupabaseService.client.removeChannel(_realtimeChannel!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initFamilyChat() async {
    setState(() => _isLoading = true);
    final circle = await _familyService.getOrCreateCircle();
    if (circle == null || circle['circle_id'] == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final circleId = circle['circle_id'].toString();
    final familyName = circle['family_name'] as String? ?? 'Family Group';
    final inviteCode = circle['invite_code'] as String?;

    final results = await Future.wait([
      _familyService.getMembers(circleId),
      _familyService.getFamilyMessages(circleId),
    ]);

    if (!mounted) return;
    setState(() {
      _circleId = circleId;
      _familyName = familyName;
      _inviteCode = inviteCode;
      _members = results[0] as List<FamilyMemberModel>;
      _messages = results[1] as List<FamilyMessageModel>;
      _isLoading = false;
    });

    _scrollToBottom(animated: false);
    _subscribeRealtime(circleId);
  }

  void _subscribeRealtime(String circleId) {
    try {
      if (_realtimeChannel != null) {
        SupabaseService.client.removeChannel(_realtimeChannel!);
      }
      _realtimeChannel = SupabaseService.client
          .channel('public:family_messages:$circleId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'family_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_circle_id',
              value: circleId,
            ),
            callback: (_) async {
              if (!mounted || _circleId == null) return;
              final updated = await _familyService.getFamilyMessages(_circleId!);
              final members = await _familyService.getMembers(_circleId!);
              if (mounted) {
                setState(() {
                  _messages = updated;
                  _members = members;
                });
                _scrollToBottom(animated: true);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[FamilyGroupChatScreen Realtime Error]: $e');
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target + 80,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  String get _membersSubtitle {
    if (_members.isEmpty) {
      return _inviteCode != null
          ? 'Invite Code: $_inviteCode'
          : 'Private Family Sanctuary';
    }
    final myId = _currentUserId;
    final labels = _members.map((m) {
      if (m.userId == myId) return 'You (${m.role})';
      if (m.displayName.isNotEmpty &&
          m.displayName.toLowerCase() != m.role.toLowerCase()) {
        return '${m.displayName} (${m.role})';
      }
      return m.role;
    }).toList();
    return labels.join(', ');
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _circleId == null || _isSending) return;

    HapticFeedback.lightImpact();
    setState(() => _isSending = true);
    _messageController.clear();

    final sent = await _familyService.sendFamilyMessage(
      circleId: _circleId!,
      content: text,
      messageType: 'text',
    );

    if (sent && mounted && _circleId != null) {
      final updated = await _familyService.getFamilyMessages(_circleId!);
      if (mounted) {
        setState(() {
          _messages = updated;
          _isSending = false;
        });
        _scrollToBottom(animated: true);
      }
    } else if (mounted) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send message. Please try again.'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
    }
  }

  Future<void> _openSharedProfile(String profileId) async {
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile details unavailable.')),
      );
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('h:mm a').format(dt);
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFDF9),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FamilyRoomScreen()),
            ).then((_) => _initFamilyChat());
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.8),
                ),
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.family_restroom_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _familyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2B2118),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _membersSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF8C7B6E),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_inviteCode != null && _inviteCode!.isNotEmpty)
            IconButton(
              tooltip: 'Copy Invite Code ($_inviteCode)',
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.primary,
                size: 21,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                Clipboard.setData(ClipboardData(text: _inviteCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Family Invite Code $_inviteCode copied! Share with parents.',
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Open Family Room Shortlists',
            icon: const Icon(
              Icons.how_to_vote_rounded,
              color: Color(0xFFC99A4B),
              size: 22,
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyRoomScreen()),
              ).then((_) => _initFamilyChat());
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEAE2D7), height: 0.8),
        ),
      ),
      body: Column(
        children: [
          // Sacred Privacy Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF9EE),
              border: Border(
                bottom: BorderSide(color: Color(0xFFEDE3D2), width: 0.8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 13,
                  color: Color(0xFF92400E),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _inviteCode != null
                        ? 'Private Family Sanctuary • Invite Code: $_inviteCode'
                        : 'Private Family Sanctuary • Visible only to your Family Circle',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF92400E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          if (msg.messageType == 'system') {
                            return _buildSystemBanner(msg);
                          }
                          return _buildMessageBubble(msg);
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFC99A4B).withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start Your Family Deliberation',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2B2118),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _members.length <= 1 && _inviteCode != null
                  ? 'Share invite code $_inviteCode with your parents so they can join this private room and discuss alliances together.'
                  : 'Discuss horoscopes, family background, and shortlisted alliances privately with your family circle.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF8C7B6E),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBanner(FamilyMessageModel msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3ECE2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2D6C5), width: 0.8),
          ),
          child: Text(
            msg.content,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5A4A42),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(FamilyMessageModel msg) {
    final isMe = msg.senderId == _currentUserId;
    final senderLabel = msg.senderName.isNotEmpty &&
            msg.senderName.toLowerCase() != msg.senderRole.toLowerCase()
        ? '${msg.senderName} (${msg.senderRole})'
        : msg.senderRole;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: const Color(0xFFEDE4DC),
              child: Text(
                (msg.senderName.isNotEmpty ? msg.senderName : msg.senderRole)
                    .substring(0, 1)
                    .toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isMe
                    ? null
                    : Border.all(color: const Color(0xFFE5DDD5), width: 0.9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          msg.senderRole.toLowerCase() == 'candidate'
                              ? Icons.person_rounded
                              : Icons.verified_user_rounded,
                          size: 12,
                          color: isMe
                              ? const Color(0xFFE6C786)
                              : const Color(0xFFC99A4B),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isMe ? 'You • ${msg.senderRole}' : senderLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isMe
                                  ? const Color(0xFFE6C786)
                                  : const Color(0xFF6E1732),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (msg.messageType == 'shared_profile' &&
                      msg.sharedProfileId != null) ...[
                    GestureDetector(
                      onTap: () => _openSharedProfile(msg.sharedProfileId!),
                      child: Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFFBF8F1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMe
                                ? const Color(0xFFE6C786).withValues(alpha: 0.35)
                                : const Color(0xFFE5D5C5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 42,
                                height: 42,
                                color: const Color(0xFFEADBCE),
                                child: msg.sharedProfilePhoto != null &&
                                        msg.sharedProfilePhoto!.isNotEmpty
                                    ? Image.network(
                                        msg.sharedProfilePhoto!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.person_rounded,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.sharedProfileName ?? 'Shared Alliance',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isMe
                                          ? Colors.white
                                          : const Color(0xFF2B2118),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap to view full biodata →',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isMe
                                          ? const Color(0xFFE6C786)
                                          : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Text(
                    msg.content,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isMe ? Colors.white : const Color(0xFF2B2118),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(msg.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white70
                                : const Color(0xFFA8988B),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.done_all_rounded,
                            size: 12,
                            color: Color(0xFFE6C786),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        border: const Border(
          top: BorderSide(color: Color(0xFFEAE2D7), width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F1E9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5DDD5)),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF2B2118),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Message your family circle...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF9E8E81),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
