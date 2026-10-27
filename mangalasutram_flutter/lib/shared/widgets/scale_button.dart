import 'package:flutter/material.dart';

class ScaleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final bool hasShadow;
  final double height;
  final double? fontSize;
  final Widget? icon;

  const ScaleButton({
    super.key,
    required this.onPressed,
    required this.text,
    required this.color,
    required this.textColor,
    this.isLoading = false,
    this.borderColor,
    this.hasShadow = false,
    this.height = 56,
    this.fontSize = 17,
    this.icon,
  });

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      widget.onPressed!();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0, // Exact Apple 98% scale down tap
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.onPressed == null
                ? widget.color.withValues(alpha: 0.5)
                : widget.color,
            borderRadius: BorderRadius.circular(16),
            border: widget.borderColor != null
                ? Border.all(color: widget.borderColor!, width: 1.5)
                : null,
            boxShadow:
                widget.hasShadow && widget.onPressed != null && !_isPressed
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: widget.textColor,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: widget.onPressed == null
                              ? widget.textColor.withValues(alpha: 0.5)
                              : widget.textColor,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
