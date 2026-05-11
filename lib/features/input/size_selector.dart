import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import 'selector_button.dart';

class SizeSelector extends StatelessWidget {
  const SizeSelector({
    super.key,
    required this.selectedPreset,
    required this.customWidth,
    required this.customHeight,
    required this.onPresetSelected,
  });

  final SizePreset selectedPreset;
  final int customWidth;
  final int customHeight;
  final ValueChanged<SizePreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return SelectorButton<SizePreset>(
      icon: Icons.aspect_ratio_rounded,
      label: selectedPreset == SizePreset.custom
          ? '$customWidth×$customHeight'
          : selectedPreset.label,
      values: SizePreset.values,
      selectedValue: selectedPreset,
      onSelected: onPresetSelected,
      itemLabelBuilder: (value) {
        if (value == SizePreset.custom) {
          return '自定义';
        }
        return '${value.label} ${value.width}×${value.height}';
      },
    );
  }
}
