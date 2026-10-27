import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_card.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      provider.loadInitialNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      context.read<NotificationProvider>().loadMoreNotifications();
    }
  }

  void _handleNotificationTap(NotificationItem item) {
    final provider = context.read<NotificationProvider>();
    if (!item.isRead) {
      provider.markAsRead(item.id);
    }

    final route = item.targetRoute;
    if (route != null && route.isNotEmpty) {
      // Safe navigation based on route payload
      if (route == '/interests') {
        Navigator.pushNamed(context, '/interests');
      } else if (route == '/plans') {
        Navigator.pushNamed(context, '/plans');
      } else if (route == '/settings') {
        Navigator.pushNamed(context, '/settings');
      }
    }
  }

  void _showClearAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFECE7E0)),
        ),
        title: Text(
          'Clear Notifications',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6E1732),
          ),
        ),
        content: Text(
          'Are you sure you want to dismiss all active notifications? This action cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4A3B32),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8C7A6B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6E1732),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<NotificationProvider>().dismissAll();
            },
            child: Text(
              'Clear All',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final horizontalPadding = isTablet ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1), // Warm Ivory
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF8F1),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF4A121A),
            size: 24,
          ),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4A121A),
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              final hasUnread = provider.unreadCount > 0;
              final hasNotifications = provider.notifications.isNotEmpty;

              return Row(
                children: [
                  // Mark all as read action
                  if (hasUnread)
                    IconButton(
                      icon: const Icon(
                        Icons.done_all_rounded,
                        color: Color(0xFFC99A4B), // Temple Gold
                        size: 22,
                      ),
                      tooltip: 'Mark all as read',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        provider.markAllAsRead();
                      },
                    ),

                  // Clear all action
                  if (hasNotifications)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Color(0xFF8C7A6B),
                        size: 22,
                      ),
                      tooltip: 'Clear all',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _showClearAllConfirmation(context);
                      },
                    ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Segmented Filter Bar (All vs. Unread) ───────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 10,
              ),
              child: Consumer<NotificationProvider>(
                builder: (context, provider, _) {
                  final totalCount = provider.notifications.length;
                  final unreadCount = provider.unreadCount;

                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EDE2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE8DFD3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Filter "All"
                        Expanded(
                          child: _FilterPill(
                            label: 'All ($totalCount)',
                            isSelected: provider.currentFilter == NotificationFilter.all,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.setFilter(NotificationFilter.all);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Filter "Unread"
                        Expanded(
                          child: _FilterPill(
                            label: 'Unread ($unreadCount)',
                            isSelected: provider.currentFilter == NotificationFilter.unreadOnly,
                            badgeColor: unreadCount > 0
                                ? const Color(0xFF6E1732)
                                : null,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.setFilter(NotificationFilter.unreadOnly);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),

            // ── Main Content Area ───────────────────────────────────────
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (context, provider, _) {
                  // 1. Loading State
                  if (provider.isLoading && provider.notifications.isEmpty) {
                    return _buildLoadingSkeleton(horizontalPadding);
                  }

                  // 2. Error State
                  if (provider.errorMessage != null && provider.notifications.isEmpty) {
                    return _buildErrorState(provider, horizontalPadding);
                  }

                  final list = provider.filteredNotifications;

                  // 3. Empty State
                  if (list.isEmpty) {
                    return _buildEmptyState(
                      provider.currentFilter == NotificationFilter.unreadOnly,
                      horizontalPadding,
                    );
                  }

                  // 4. Notifications List
                  return RefreshIndicator(
                    color: const Color(0xFF6E1732),
                    backgroundColor: Colors.white,
                    onRefresh: () => provider.loadInitialNotifications(),
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 10,
                      ),
                      itemCount: list.length + (provider.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == list.length) {
                          // Bounded pagination loader
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFC99A4B),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final item = list[index];
                        return NotificationCard(
                          item: item,
                          onTap: _handleNotificationTap,
                          onDismiss: (toDismiss) {
                            provider.dismissNotification(toDismiss.id);
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading Skeleton ────────────────────────────────────────────────
  Widget _buildLoadingSkeleton(double horizontalPadding) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Container(
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECE7E0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3EDE2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EDE2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F4EE),
                        borderRadius: BorderRadius.circular(4),
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

  // ── Error State ─────────────────────────────────────────────────────
  Widget _buildErrorState(NotificationProvider provider, double horizontalPadding) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFBECEF),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFF6E1732),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Notifications',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A121A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              provider.errorMessage ?? 'Please check your connection and try again.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF8C7A6B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1732),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () => provider.loadInitialNotifications(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Try Again',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isUnreadOnly, double horizontalPadding) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFDF6E9), // Temple Gold Soft Tint
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.mark_email_read_outlined,
                  color: Color(0xFFC99A4B), // Temple Gold
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isUnreadOnly ? 'No Unread Notifications' : 'All Caught Up',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A121A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isUnreadOnly
                  ? 'You have read all received alerts and updates.'
                  : 'New interests, astrology matches, and family room activities will appear here.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF8C7A6B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? badgeColor;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF6E1732)
                : const Color(0xFF75675E),
          ),
        ),
      ),
    );
  }
}
