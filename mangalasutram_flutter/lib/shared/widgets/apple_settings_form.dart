import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AppleFormSection extends StatelessWidget {
  final String? title;
  final String? footer;
  final List<Widget> children;

  const AppleFormSection({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: 30,
              bottom: 7,
              top: 22,
              right: 20,
            ),
            child: Text(
              title!.toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(0xFF7A6A5E),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
              ),
            ),
          )
        else
          const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.018),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(children: _buildChildrenWithDividers()),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
              left: 30,
              right: 24,
              top: 7,
            ),
            child: Text(
              footer!,
              style: GoogleFonts.inter(
                color: const Color(0xFF8C7E72),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildChildrenWithDividers() {
    final List<Widget> result = [];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(
          const Divider(
            height: 0.5,
            thickness: 0.5,
            color: Color(0xFFEDE7DF),
            indent: 16,
          ),
        );
      }
    }
    return result;
  }
}

class AppleFormRow extends StatelessWidget {
  final String label;
  final String? value;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final bool isReadOnly;
  final TextInputType? keyboardType;
  final String? hintText;
  final bool showChevron;
  final int maxLines;

  const AppleFormRow({
    super.key,
    required this.label,
    this.value,
    this.controller,
    this.onTap,
    this.isReadOnly = false,
    this.keyboardType,
    this.hintText,
    this.showChevron = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelector = onTap != null && isReadOnly;
    final bool hasValue =
        (controller?.text.trim().isNotEmpty == true) ||
        (value != null && value!.trim().isNotEmpty);

    Widget rightSide;

    if (isSelector) {
      rightSide = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              (controller?.text.isNotEmpty == true)
                  ? controller!.text
                  : (value ?? hintText ?? 'Select'),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                letterSpacing: -0.15,
                color: hasValue
                    ? const Color(0xFF6B5E54)
                    : const Color(0xFFB8AEA4),
              ),
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_forward,
              color: Color(0xFFC4B9AE),
              size: 16,
            ),
          ],
        ],
      );
    } else {
      rightSide = TextField(
        controller: controller,
        readOnly: isReadOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: maxLines > 1 ? maxLines : 1,
        textAlign: maxLines > 1 ? TextAlign.left : TextAlign.right,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.15,
          color: const Color(0xFF2C2520),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFFB8AEA4),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSelector ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: maxLines > 1
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: const Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 8),
                    rightSide,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: const Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: rightSide),
                  ],
                ),
        ),
      ),
    );
  }
}
