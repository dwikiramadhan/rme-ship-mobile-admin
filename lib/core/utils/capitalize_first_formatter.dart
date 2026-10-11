import 'package:flutter/services.dart';

/// Keeps the first letter of a free-text field uppercase ("demam" → "Demam"),
/// whether it was typed, pasted, or entered on a hardware keyboard. The rest
/// of the text is left exactly as the user wrote it.
class CapitalizeFirstFormatter extends TextInputFormatter {
  const CapitalizeFirstFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final index = text.indexOf(RegExp(r'\S'));
    if (index < 0) return newValue;

    final first = text[index];
    final upper = first.toUpperCase();
    // Skip when already uppercase, or when uppercasing changes the length
    // (e.g. "ß" → "SS"), which would shift the cursor.
    if (upper == first || upper.length != first.length) return newValue;

    return newValue.copyWith(
      text: text.replaceRange(index, index + 1, upper),
    );
  }
}

/// Formatters + keyboard hint for free-text fields.
const freeTextFormatters = <TextInputFormatter>[CapitalizeFirstFormatter()];
const freeTextCapitalization = TextCapitalization.sentences;
