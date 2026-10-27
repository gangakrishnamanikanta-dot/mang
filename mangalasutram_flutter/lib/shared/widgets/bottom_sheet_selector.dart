import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/lookup_option.dart';

class BottomSheetSelector {
  static Future<LookupOption?> show({
    required BuildContext context,
    required String title,
    required List<LookupOption> options,
    LookupOption? selectedOption,
  }) {
    // Unfocus any active text inputs to prevent bottom inset collapse jumps
    FocusScope.of(context).unfocus();

    return showModalBottomSheet<LookupOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _BottomSheetSelectorWidget(
          title: title,
          options: options,
          selectedOption: selectedOption,
        );
      },
    );
  }
}

class _BottomSheetSelectorWidget extends StatefulWidget {
  final String title;
  final List<LookupOption> options;
  final LookupOption? selectedOption;

  const _BottomSheetSelectorWidget({
    required this.title,
    required this.options,
    this.selectedOption,
  });

  @override
  State<_BottomSheetSelectorWidget> createState() =>
      _BottomSheetSelectorWidgetState();
}

class _BottomSheetSelectorWidgetState
    extends State<_BottomSheetSelectorWidget> {
  late List<LookupOption> _filteredOptions;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterOptions(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredOptions = widget.options;
      } else {
        final q = query.toLowerCase().trim();
        _filteredOptions = widget.options
            .where((option) => option.label.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = widget.options.length > 8;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxSheetHeight = screenHeight * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF231F20),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF8E8E93)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          if (hasSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filterOptions,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search options...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF8E8E93), fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF8E8E93),
                    size: 20,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filterOptions('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF7F3EE),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          const Divider(height: 1, color: Color(0xFFF2EBE3)),

          // Options List
          Flexible(
            child: _filteredOptions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No matching options found',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filteredOptions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF8F4EE)),
                    itemBuilder: (context, index) {
                      final option = _filteredOptions[index];
                      final isSelected = widget.selectedOption?.id == option.id ||
                          widget.selectedOption?.label == option.label;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        title: Text(
                          option.label,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF6E1732)
                                : const Color(0xFF231F20),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF6E1732),
                                size: 20,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
