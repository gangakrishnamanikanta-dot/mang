import 'package:flutter/material.dart';
import '../../constants/theme.dart';

class AppInput extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController controller;
  final bool isPassword;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  const AppInput({
    super.key,
    required this.label,
    this.hintText,
    required this.controller,
    this.isPassword = false,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(
              color: hasError ? AppColors.error : AppColors.border,
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isPassword ? obscureText : false,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              if (suffixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: suffixIcon,
                ),
              if (isPassword)
                GestureDetector(
                  onTap: () {
                    // This is handled by the parent managing obscureText state
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs, left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }
}
