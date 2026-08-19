import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppleFormSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const AppleFormSection({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: 32,
              bottom: 8,
              top: 24,
              right: 16,
            ),
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF6E1732), // Burgundy
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(children: _buildChildrenWithDividers()),
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
            color: Color(0xFFF0F0F0),
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

    Widget rightSide;

    if (isSelector) {
      rightSide = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              (controller?.text.isNotEmpty == true)
                  ? controller!.text
                  : (value ?? hintText ?? ''),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                color: (controller?.text.isNotEmpty == true || value != null)
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFFC7C7CC),
              ),
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_forward,
              color: Color(0xFFC7C7CC),
              size: 20,
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
        style: const TextStyle(fontSize: 17, color: Color(0xFF8E8E93)),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 17, color: Color(0xFFC7C7CC)),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSelector ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: maxLines > 1
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 17, color: Colors.black),
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
                      style: const TextStyle(fontSize: 17, color: Colors.black),
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
