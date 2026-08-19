import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppleTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? customPrefix;
  final Widget? suffixIcon;
  final bool isPassword;
  final bool obscureVal;
  final TextInputType? keyboardType;
  final VoidCallback? onToggleObscure;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;

  // Constants
  static const Color _textDark = Color(0xFF1C1C1E);
  static const Color _textGray = Color(0xFF8E8E93);
  static const Color _borderColor = Color(0xFFE5E5EA);
  static const Color _burgundy = Color(0xFF6E1732);

  const AppleTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.customPrefix,
    this.suffixIcon,
    this.isPassword = false,
    this.obscureVal = false,
    this.keyboardType,
    this.onToggleObscure,
    this.inputFormatters,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscureVal : false,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: _textDark,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: hintText,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: _textGray,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _burgundy, width: 1.5),
        ),
        prefixIcon:
            customPrefix ??
            (prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(prefixIcon, color: _burgundy, size: 22),
                  )
                : null),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon:
            suffixIcon ??
            (isPassword
                ? IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        obscureVal
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        key: ValueKey<bool>(obscureVal),
                        color: _burgundy,
                        size: 22,
                      ),
                    ),
                    onPressed: onToggleObscure,
                  )
                : null),
      ),
    );
  }
}
