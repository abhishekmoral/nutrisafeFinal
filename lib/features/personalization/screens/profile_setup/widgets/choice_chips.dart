import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../utils/constants/sizes.dart';

/// -- Multi-select chips. [options] maps the stored value to its label.
class XChoiceChips extends StatelessWidget {
  const XChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final Map<String, String> options;
  final List<String> selected;
  final void Function(String value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: XSizes.sm,
      runSpacing: XSizes.xs,
      children: options.entries.map((option) {
        final isSelected = selected.contains(option.key);
        return FilterChip(
          label: Text(option.value.tr),
          selected: isSelected,
          labelStyle: TextStyle(color: isSelected ? Colors.white : null),
          onSelected: (_) => onToggle(option.key),
        );
      }).toList(),
    );
  }
}
