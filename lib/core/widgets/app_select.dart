import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_text_field.dart';

class AppSelectOption<T> {
  const AppSelectOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// Port of the prototype's `Select` component (a native <select> styled to
/// match the Input field) using a Material dropdown.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.hint = 'Pilih...',
    this.fontSize,
    this.labelFontSize,
  });

  final String label;
  final List<AppSelectOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final bool required;
  final String hint;
  final double? fontSize;
  final double? labelFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label: label, required: required, fontSize: labelFontSize),
        const SizedBox(height: 5),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.sub),
          style: TextStyle(fontSize: fontSize ?? 14, color: AppColors.text),
          decoration: const InputDecoration(),
          hint: Text(hint, style: TextStyle(fontSize: fontSize ?? 14, color: AppColors.sub)),
          items: [
            for (final o in options)
              DropdownMenuItem<T>(
                value: o.value,
                child: Text(
                  o.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: fontSize ?? 14),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
