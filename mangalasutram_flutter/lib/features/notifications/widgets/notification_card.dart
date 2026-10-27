import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notification_item.dart';

class NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final ValueChanged<NotificationItem> onTap;
  final ValueChanged<NotificationItem> onDismiss;

  const NotificationCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF6E1732), // Deep Royal Burgundy
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(height: 2),
            Text(
              'Dismiss',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDismiss(item);
      },
      child: Semantics(
        label: '${isUnread ? "Unread " : ""}${item.title}. ${item.body}. ${item.timeAgo}',
        button: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap(item);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUnread ? const Color(0xFFFFFDF8) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread
                    ? const Color(0xFFC99A4B).withValues(alpha: 0.55)
                    : const Color(0xFFECE7E0),
                width: isUnread ? 1.2 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isUnread
                      ? const Color(0xFF6E1732).withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.category.iconBackgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.category.iconColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      item.category.icon,
                      color: item.category.iconColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Title + Timestamp
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 15,
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                color: isUnread
                                    ? const Color(0xFF4A121A)
                                    : const Color(0xFF1E1E1E),
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.timeAgo,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8C7A6B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Notification Body (Sanitized text only)
                      Text(
                        item.body,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                          color: isUnread
                              ? const Color(0xFF2B2118)
                              : const Color(0xFF6B5E55),
                          height: 1.38,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Unread Indicator & Dismiss Action
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUnread) ...[
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4, bottom: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFC99A4B), // Temple Gold Dot
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    // Dismiss Button (Accessible Tap Target)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFFB0A499),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      splashRadius: 18,
                      tooltip: 'Dismiss',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onDismiss(item);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
