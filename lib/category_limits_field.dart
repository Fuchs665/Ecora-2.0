import 'package:flutter/material.dart';

import 'guest_categories.dart';
import 'theme.dart';

/// Sezione facoltativa del form "Crea serata" (Blocco C.5d): un contatore
/// per coppie, donne e uomini; null = nessun limite, mai oltre il totale.
class CategoryLimitsField extends StatelessWidget {
  final int total;
  final Map<GuestCategory, int?> limits;
  final void Function(GuestCategory category, int? value) onChanged;
  final bool enabled;

  const CategoryLimitsField({
    super.key,
    required this.total,
    required this.limits,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kCategoryLimitsTitle, style: textTheme.titleMedium),
        const SizedBox(height: EcoraSpace.s4),
        Text(kCategoryLimitsHint,
            style: textTheme.bodySmall?.copyWith(color: EcoraColors.inkMuted)),
        const SizedBox(height: EcoraSpace.s8),
        for (final category in GuestCategory.values)
          _CounterRow(
            label: category.plural,
            value: limits[category],
            onDecrement: !enabled || limits[category] == null
                ? null
                : () => onChanged(category, decrementLimit(limits[category])),
            onIncrement: !enabled || (limits[category] ?? -1) >= total
                ? null
                : () =>
                    onChanged(category, incrementLimit(limits[category], total)),
          ),
      ],
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int? value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shown = value == null ? kNoLimit : '$value';
    return Row(
      children: [
        Expanded(child: Text(label, style: textTheme.bodyLarge)),
        IconButton(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 104,
          child: Text(
            shown,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
                color: value == null ? EcoraColors.inkMuted : EcoraColors.ink),
          ),
        ),
        IconButton(
          onPressed: onIncrement,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
