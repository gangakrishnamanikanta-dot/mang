import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../screens/notifications_screen.dart';

/// Notification bell icon with unread badge counter adhering to the Vedic Luxury system.
class NotificationBadge extends StatelessWidget {
  final FutureOr<void> Function()? onTap;
  final Color iconColor;
  final double iconSize;
  final bool isTablet;

  const NotificationBadge({
    super.key,
    this.onTap,
    this.iconColor = const Color(0xFF4A3B32),
    this.iconSize = 20.0,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = isTablet ? 42.0 : 36.0;

    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final badgeText = provider.unreadBadgeText;
        final hasBadge = badgeText.isNotEmpty;

        return Semantics(
          label: hasBadge
              ? 'Notifications, ${provider.unreadCount} unread'
              : 'Notifications, no unread',
          button: true,
          child: InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              if (onTap != null) {
                await onTap!();
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationCenterScreen(),
                  ),
                );
              }
              if (context.mounted) {
                provider.refreshUnreadCount();
              }
            },
            borderRadius: BorderRadius.circular(btnSize / 2),
            child: Container(
              width: btnSize,
              height: btnSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE8E0D5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    hasBadge
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_rounded,
                    color: hasBadge ? const Color(0xFF6E1732) : iconColor,
                    size: iconSize,
                  ),
                  if (hasBadge)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6E1732), // Deep Royal Burgundy
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6E1732).withValues(alpha: 0.4),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            badgeText,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
