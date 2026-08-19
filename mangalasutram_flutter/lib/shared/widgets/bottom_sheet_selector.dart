import 'package:flutter/material.dart';
import '../../models/profile.dart'; // For LookupOption

class BottomSheetSelector {
  static Future<LookupOption?> show({
    required BuildContext context,
    required String title,
    required List<LookupOption> options,
    LookupOption? selectedOption,
  }) {
    return showModalBottomSheet<LookupOption>(
      context: context,
      isScrollControlled: true,
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

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
  }

  void _filterOptions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = widget.options;
      } else {
        _filteredOptions = widget.options
            .where(
              (option) =>
                  option.label.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = widget.options.length > 10;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title and Close
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF8E8E93)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Search Bar
              if (hasSearch)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TextField(
                    onChanged: _filterOptions,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF8E8E93),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              const Divider(height: 1, color: Color(0xFFE5E5EA)),
              // List
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _filteredOptions.length,
                  itemBuilder: (context, index) {
                    final option = _filteredOptions[index];
                    final isSelected = widget.selectedOption?.id == option.id;
                    return InkWell(
                      onTap: () => Navigator.pop(context, option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFF2F2F7)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFF6E1732)
                                      : const Color(0xFF1C1C1E),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                color: Color(0xFF6E1732),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
