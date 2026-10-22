import 'package:equatable/equatable.dart';

/// One test of the lab request form (master `GET /lab-tests`). The doctor
/// ticks several, grouped by category, plus a free "Lain-lain".
class LabTestType extends Equatable {
  const LabTestType({
    required this.id,
    required this.category,
    required this.name,
    this.requiresFasting = false,
  });

  final String id;
  final String category;
  final String name;

  /// The patient has to fast before the sample is taken.
  final bool requiresFasting;

  factory LabTestType.fromJson(Map<String, dynamic> json) => LabTestType(
    id: json['id']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    requiresFasting: json['requires_fasting'] == true,
  );

  @override
  List<Object?> get props => [id, category, name, requiresFasting];
}

const String kLabOtherCategory = 'Lain-lain';

/// [tests] by category, keeping the server's order.
List<(String, List<LabTestType>)> groupLabTests(Iterable<LabTestType> tests) {
  final groups = <(String, List<LabTestType>)>[];
  for (final test in tests) {
    final i = groups.indexWhere((g) => g.$1 == test.category);
    if (i < 0) {
      groups.add((test.category, [test]));
    } else {
      groups[i].$2.add(test);
    }
  }
  return groups;
}

/// The `requested_test` text for the analyst, e.g. "Hematologi: Hematologi
/// Rutin; Gula Darah: Glukosa Puasa; Lain-lain: Rontgen". The category is
/// kept because some names are generic (e.g. "Protein").
String buildRequestedTest(Iterable<LabTestType> selected, String other) {
  final parts = [
    for (final (category, tests) in groupLabTests(selected))
      '$category: ${tests.map((t) => t.name).join(', ')}',
    if (other.trim().isNotEmpty) '$kLabOtherCategory: ${other.trim()}',
  ];
  return parts.join('; ');
}

/// The [tests] whose name or category contains [query] (any letter case).
List<LabTestType> filterLabTests(Iterable<LabTestType> tests, String query) {
  final q = query.trim().toLowerCase();
  return [
    for (final t in tests)
      if (q.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q))
        t,
  ];
}
