import 'package:flutter/material.dart';

class MatchActionButtons extends StatelessWidget {
  final VoidCallback onPass;
  final VoidCallback onLike;

  const MatchActionButtons({
    super.key,
    required this.onPass,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pass Button
        _ActionCircle(
          icon: Icons.close_rounded,
          color: const Color(0xFF1C1C1E),
          iconColor: Colors.white,
          onTap: onPass,
          size: 64,
        ),
        const SizedBox(width: 32),
        // Like Button
        _ActionCircle(
          icon: Icons.favorite_rounded,
          color: const Color(0xFF6E1732), // Burgundy
          iconColor: Colors.white,
          onTap: onLike,
          size: 64,
        ),
      ],
    );
  }
}

class _ActionCircle extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final double size;

  const _ActionCircle({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    required this.size,
  });

  @override
  State<_ActionCircle> createState() => _ActionCircleState();
}

class _ActionCircleState extends State<_ActionCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: widget.iconColor,
            size: widget.size * 0.45,
          ),
        ),
      ),
    );
  }
}
