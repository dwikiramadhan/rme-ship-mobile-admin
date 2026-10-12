/// A medicine handed to the patient for one prescription line: what the
/// pharmacy dispensed (`prescriptions[].dispenses[]`), or the prescription
/// itself when no dispense is recorded.
class DispensedMedicine {
  const DispensedMedicine({
    required this.name,
    required this.quantity,
    this.unit = '',
    this.dosage = '',
    this.instructions = '',
    this.substitutedFor,
    this.substitutionReason = '',
    this.dispensedBy,
    this.dispensedAt,
  });

  final String name;
  final int quantity;
  final String unit;
  final String dosage;
  final String instructions;

  /// The prescribed medicine when the pharmacy gave another one.
  final String? substitutedFor;
  final String substitutionReason;
  final String? dispensedBy;
  final String? dispensedAt;

  bool get isSubstituted => substitutedFor != null;

  /// Reads both backend shapes: GET /medical-history (`medicine`,
  /// `instructions`) and the records in GET /patients/:id (`name`,
  /// `instruction`).
  static List<DispensedMedicine> listFromPrescriptions(Object? raw) {
    if (raw is! List) return const [];
    final result = <DispensedMedicine>[];
    for (final rx in raw.whereType<Map>()) {
      final medicine = rx['medicine'] is Map ? rx['medicine'] as Map : null;
      final prescribedName = _text(medicine?['name']) ??
          _text(rx['name']) ??
          _text(rx['sku']) ??
          'Obat';
      final unit = _text(medicine?['unit_of_measurement']) ??
          _text(rx['unit_of_measurement']) ??
          '';
      final dosage = _text(rx['dosage']) ?? '';
      final instructions =
          _text(rx['instructions']) ?? _text(rx['instruction']) ?? '';

      final dispenses = rx['dispenses'] is List
          ? (rx['dispenses'] as List).whereType<Map>().toList()
          : const <Map>[];
      if (dispenses.isEmpty) {
        result.add(
          DispensedMedicine(
            name: prescribedName,
            quantity: _int(rx['quantity']),
            unit: unit,
            dosage: dosage,
            instructions: instructions,
          ),
        );
        continue;
      }

      for (final d in dispenses) {
        final given = d['dispensed_medicine'] is Map
            ? d['dispensed_medicine'] as Map
            : null;
        final by = d['dispensed_by'] is Map ? d['dispensed_by'] as Map : null;
        result.add(
          DispensedMedicine(
            name: _text(given?['name']) ??
                _text(d['dispensed_sku']) ??
                prescribedName,
            quantity: _int(d['dispensed_quantity'] ?? rx['quantity']),
            unit: _text(given?['unit_of_measurement']) ?? unit,
            dosage: dosage,
            instructions: instructions,
            substitutedFor: d['is_substituted'] == true ? prescribedName : null,
            substitutionReason: _text(d['substitution_reason']) ?? '',
            dispensedBy: _text(by?['name']),
            dispensedAt: _text(d['dispensed_at']),
          ),
        );
      }
    }
    return result;
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
