import 'package:flutter/material.dart';

import '../../shared/theme.dart';

class SelectorButton<T> extends StatelessWidget {
  const SelectorButton({
    super.key,
    required this.icon,
    required this.label,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
    required this.itemLabelBuilder,
  });

  final IconData icon;
  final String label;
  final List<T> values;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final String Function(T value) itemLabelBuilder;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      splashRadius: 20,
      onSelected: onSelected,
      itemBuilder: (context) {
        return values.map((value) {
          final selected = value == selectedValue;
          return PopupMenuItem<T>(
            value: value,
            child: Row(
              children: [
                Expanded(child: Text(itemLabelBuilder(value))),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppThemeTokens.primary,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppThemeTokens.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppThemeTokens.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppThemeTokens.primaryStrong),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppThemeTokens.primaryStrong,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppThemeTokens.primaryStrong,
            ),
          ],
        ),
      ),
    );
  }
}
