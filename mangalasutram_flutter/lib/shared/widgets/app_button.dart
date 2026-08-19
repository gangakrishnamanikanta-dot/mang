import 'package:flutter/material.dart';
import '../../constants/theme.dart';

class AppButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final bool loading;
  final bool disabled;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.loading = false,
    this.disabled = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = loading || disabled;
    final bg = backgroundColor ?? AppColors.primary;
    final txtColor = textColor ?? AppColors.surface;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: txtColor,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          disabledForegroundColor: txtColor.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          elevation: 0,
        ),
        child: loading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: txtColor,
                ),
              )
            : Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
