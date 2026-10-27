import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/theme.dart';
import '../../../core/di.dart';
import '../../auth/services/supabase_service.dart';
import '../../interests/services/interest_service.dart';
import '../services/chat_service.dart';
import 'chat_conversation_screen.dart';
import '../../family/screens/family_group_chat_screen.dart';
import '../../family/screens/family_room_screen.dart';
import '../../family/services/family_service.dart';

class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> with WidgetsBindingObserver {
  final ChatService _chatService = getIt<ChatService>();
  final InterestService _interestService = getIt<InterestService>();
  final FamilyService _familyService = FamilyService.instance;

  int _selectedFilterIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['All Chats', 'Unread', 'Accepted Matches'];
  List<Map<String, dynamic>> _threads = [];
  String _familyGroupTitle = 'Family Group';
  String _familyGroupSubtitle = 'Private Family Sanctuary';
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _interestService.interestsRefreshTrigger.addListener(_onInterestChanged);
    _initRealtime();
  }

  void _onInterestChanged() {
    debugPrint('[InboxTab]: Interest changed trigger received -> instant refresh');
    _loadConversations(showSpinner: false);
  }

  void _initRealtime() {
    try {
      final myId = SupabaseService.client.auth.currentUser?.id;
      if (myId == null) return;

      _realtimeChannel = SupabaseService.client
          .channel('public:inbox_realtime_sync:$myId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            callback: (payload) {
              debugPrint('[InboxTab Realtime]: Conversations table changed -> live sync');
              if (mounted) _loadConversations(showSpinner: false);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'interests',
            callback: (payload) {
              debugPrint('[InboxTab Realtime]: Interests table changed -> live sync');
              if (mounted) _loadConversations(showSpinner: false);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'family_messages',
            callback: (payload) {
              debugPrint('[InboxTab Realtime]: family_messages changed -> live sync');
              if (mounted) _loadConversations(showSpinner: false);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[InboxTab Realtime Error]: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadConversations(showSpinner: false);
    }
  }

  Future<void> _loadConversations({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }
    final results = await Future.wait([
      _chatService.getConversations(),
      _loadFamilySummary(),
    ]);
    final convs = results[0] as List<Map<String, dynamic>>;
    if (mounted) {
      setState(() {
        _threads = convs;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFamilySummary() async {
    try {
      final circle = await _familyService.getOrCreateCircle();
      if (circle == null || circle['circle_id'] == null) return;

      final circleId = circle['circle_id'].toString();
      final familyName = circle['family_name'] as String? ?? 'Family Group';
      final inviteCode = circle['invite_code'] as String?;

      final msgs = await _familyService.getFamilyMessages(circleId, limit: 20);
      String subtitle;
      if (msgs.isNotEmpty) {
        final last = msgs.last;
        subtitle = last.messageType == 'system'
            ? last.content
            : '${last.senderRole}: ${last.content}';
      } else {
        final members = await _familyService.getMembers(circleId);
        if (members.length > 1) {
          final myId = SupabaseService.client.auth.currentUser?.id;
          subtitle = members
              .map((m) => m.userId == myId ? 'You (${m.role})' : m.role)
              .join(', ');
        } else {
          subtitle = inviteCode != null
              ? 'Tap to invite parents • Code: $inviteCode'
              : 'Discuss alliances with your family';
        }
      }

      if (mounted) {
        setState(() {
          _familyGroupTitle = familyName;
          _familyGroupSubtitle = subtitle;
        });
      }
    } catch (e) {
      debugPrint('[InboxTab _loadFamilySummary Error]: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _interestService.interestsRefreshTrigger.removeListener(_onInterestChanged);
    if (_realtimeChannel != null) {
      SupabaseService.client.removeChannel(_realtimeChannel!);
    }
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredThreads {
    return _threads.where((t) {
      final name = (t['name'] as String? ?? '').toLowerCase();
      final subcaste = (t['subcaste'] as String? ?? '').toLowerCase();
      final unreadCount = t['unread_count'] as int? ?? 0;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = name.contains(query);
        final matchesSubcaste = subcaste.contains(query);
        if (!matchesName && !matchesSubcaste) return false;
      }

      if (_selectedFilterIndex == 1) {
        return unreadCount > 0;
      }
      return true;
    }).toList();
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = timestamp is DateTime ? timestamp : DateTime.parse(timestamp.toString()).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return DateFormat('h:mm a').format(dt);
      } else if (now.difference(dt).inDays == 1) {
        return 'Yesterday';
      } else {
        return DateFormat('MMM d').format(dt);
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredThreads;
    final totalUnread = _threads.where((t) => (t['unread_count'] as int? ?? 0) > 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _loadConversations(showSpinner: false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Messages',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2B2118),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (totalUnread > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalUnread new',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        InkWell(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FamilyRoomScreen(),
                              ),
                            ).then((_) => _loadConversations(showSpinner: false));
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6EFE6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFC99A4B).withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.how_to_vote_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Family Room',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF2B2118)),
                    decoration: InputDecoration(
                      hintText: 'Search chats by name or subcaste...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFA8988B)),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9E8E81), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final isSel = _selectedFilterIndex == i;
                    return ChoiceChip(
                      label: Text(_filters[i]),
                      selected: isSel,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSel ? AppColors.primary : const Color(0xFFE5DDD5),
                        ),
                      ),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : const Color(0xFF5A4D41),
                      ),
                      onSelected: (_) => setState(() => _selectedFilterIndex = i),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Content List
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Family Sanctuary'),
                          _buildFamilyGroupTile(),
                          const SizedBox(height: 16),
                          _buildSectionHeader('Alliances'),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      )
                    else if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final isLast = index == filtered.length - 1;
                            return Column(
                              children: [
                                _buildAllianceTile(filtered[index]),
                                if (!isLast) const Divider(height: 1, color: Color(0xFFF0EAE1)),
                              ],
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF5A4D41),
        ),
      ),
    );
  }

  Widget _buildFamilyGroupTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 2),
        ),
        child: const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.family_restroom_rounded, color: Colors.white, size: 24),
        ),
      ),
      title: Text(
        _familyGroupTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2B2118),
        ),
      ),
      subtitle: Text(
        _familyGroupSubtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF8C7B6E),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Text(
          'Pinned',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
      onTap: () async {
        FocusScope.of(context).unfocus();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FamilyGroupChatScreen(),
          ),
        );
        _loadConversations(showSpinner: false);
      },
    );
  }

  Widget _buildAllianceTile(Map<String, dynamic> t) {
    final hasUnread = (t['unread_count'] as int? ?? 0) > 0;
    final otherId = t['other_user_id'] as String;
    final convId = t['conversation_id'] as String;
    final name = t['name'] as String;
    final photoUrl = t['photo_url'] as String?;
    final subcaste = t['subcaste'] as String?;
    final isVerified = t['is_verified'] == true;
    final lastMsg = t['last_message'] as String? ?? 'No messages yet';
    final time = _formatTime(t['last_message_time']);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEDE4DC),
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? const Icon(Icons.person, color: AppColors.primary, size: 28)
                : null,
          ),
          if (hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                color: const Color(0xFF2B2118),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isVerified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified_rounded, size: 14, color: Color(0xFFD97706)),
          ],
          const Spacer(),
          Text(
            time,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              color: hasUnread ? AppColors.primary : const Color(0xFF9E8E81),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              lastMsg,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                color: hasUnread ? const Color(0xFF2B2118) : const Color(0xFF8C7B6E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasUnread)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${t['unread_count']}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              conversationId: convId,
              profileId: otherId,
              name: name,
              photoUrl: photoUrl,
              subcaste: subcaste,
              isVerified: isVerified,
            ),
          ),
        );
        _loadConversations(showSpinner: false);
      },
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
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Alliances Yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2B2118),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When you and another member mutually accept an interest, your secure E2EE chat will appear here instantly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8C7B6E), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
