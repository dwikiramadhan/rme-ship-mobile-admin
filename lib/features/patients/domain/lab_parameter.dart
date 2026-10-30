import 'package:equatable/equatable.dart';

import 'lab_test_type.dart';

/// One row of the lab result form (master `GET /lab-parameters`), e.g.
/// Hemoglobin: its unit, how the result is entered and the reference range
/// per patient group, as on the paper form.
class LabParameter extends Equatable {
  const LabParameter({
    required this.id,
    required this.section,
    this.group = '',
    required this.name,
    this.unit = '',
    this.inputType = kLabInputText,
    this.options = const [],
    this.normalOptions = const [],
    this.referenceRange = '',
    this.references = const [],
    this.sortOrder = 0,
    this.labTestIds = const [],
  });

  final String id;

  /// Heading of the form part, e.g. "Kimia Klinik"; [group] is the part
  /// under it, e.g. "Gula Darah" (empty when the part has none).
  final String section;
  final String group;
  final String name;
  final String unit;

  /// [kLabInputText] (a number or free text) or [kLabInputSelect] (one of
  /// [options]).
  final String inputType;
  final List<String> options;
  final List<String> normalOptions;

  /// The whole reference text, e.g. "L : 13,5 – 17,5\nP : 11,7 – 15,5".
  final String referenceRange;

  /// [referenceRange] per patient group.
  final List<LabReference> references;
  final int sortOrder;

  /// The lab tests (`GET /lab-tests`) that include this row.
  final List<String> labTestIds;

  bool get isSelect => inputType == kLabInputSelect;

  /// Typed freely, with [options] offered as suggestions (e.g. urine colour).
  bool get isCombo => inputType == kLabInputCombo;

  /// Where it goes on the form: "Kimia Klinik / Gula Darah", or the section.
  String get heading => group.isEmpty ? section : '$section / $group';

  factory LabParameter.fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic v) => [
      if (v is List)
        for (final s in v) s.toString(),
    ];
    return LabParameter(
      id: json['id']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      group: json['group']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      inputType: json['input_type']?.toString() ?? kLabInputText,
      options: strings(json['options']),
      normalOptions: strings(json['normal_options']),
      referenceRange: json['reference_range']?.toString() ?? '',
      references: [
        if (json['references'] is List)
          for (final r in json['references'] as List)
            if (r is Map)
              LabReference(
                who: r['who']?.toString() ?? '',
                range: r['range']?.toString() ?? '',
              ),
      ],
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      labTestIds: strings(json['lab_test_ids']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    section,
    group,
    name,
    unit,
    inputType,
    sortOrder,
  ];
}

const String kLabInputText = 'text';
const String kLabInputSelect = 'select';
const String kLabInputCombo = 'combo';

/// One line of a reference range: the patient group ('' = everyone, 'L',
/// 'P', 'Anak', 'Dewasa', 'Bayi') and its range.
class LabReference extends Equatable {
  const LabReference({required this.who, required this.range});

  final String who;
  final String range;

  @override
  List<Object?> get props => [who, range];
}

/// The lab tests named in a doctor's `requested_test`, e.g. "Hematologi:
/// Hematologi Rutin; Elektrolit: Na, K, Cl; Lain-lain: Rontgen". Each master
/// name is matched inside its category's part, so names with commas work.
Set<String> requestedLabTestIds(String requestedTest, List<LabTestType> tests) {
  final ids = <String>{};
  for (final part in requestedTest.split(';')) {
    final colon = part.indexOf(':');
    if (colon < 0) continue;
    final category = part.substring(0, colon).trim().toLowerCase();
    final names = ', ${part.substring(colon + 1).trim().toLowerCase()}, ';
    for (final t in tests) {
      if (t.category.toLowerCase() == category &&
          names.contains(', ${t.name.toLowerCase()}, ')) {
        ids.add(t.id);
      }
    }
  }
  return ids;
}

/// The rows of the requested tests, in form order.
List<LabParameter> requestedParameters(
  List<LabParameter> parameters,
  Set<String> labTestIds,
) {
  final rows = [
    for (final p in parameters)
      if (p.labTestIds.any(labTestIds.contains)) p,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return rows;
}

/// [parameters] in form order, by section/group heading.
List<(String, List<LabParameter>)> groupLabParameters(
  Iterable<LabParameter> parameters,
) {
  final sorted = [...parameters]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final groups = <(String, List<LabParameter>)>[];
  for (final p in sorted) {
    if (groups.isEmpty || groups.last.$1 != p.heading) {
      groups.add((p.heading, [p]));
    } else {
      groups.last.$2.add(p);
    }
  }
  return groups;
}

/// The [parameters] whose name or heading contains [query] (any case).
List<LabParameter> filterLabParameters(
  Iterable<LabParameter> parameters,
  String query,
) {
  final q = query.trim().toLowerCase();
  return [
    for (final p in parameters)
      if (q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.heading.toLowerCase().contains(q))
        p,
  ];
}

const int _infantMaxDays = 30;
const int _childMaxYears = 18;

/// The reference range that applies to the patient, the same rule as the
/// backend: infant, then child, then sex, then adult, then everyone. With
/// nothing matching (e.g. unknown sex) all lines, joined with "; ". Choice
/// rows show their reference as is.
String patientReference(
  LabParameter p, {
  required String gender,
  DateTime? dob,
  DateTime? at,
}) {
  if (p.isSelect || p.isCombo) return p.referenceRange;
  final now = at ?? DateTime.now();
  final ageDays = (dob == null || now.isBefore(dob))
      ? -1
      : now.difference(dob).inDays;
  final g = gender.trim().toLowerCase();
  final sex = g.startsWith('l') ? 'L' : (g.startsWith('p') ? 'P' : '');

  final order = [
    if (ageDays >= 0 && ageDays <= _infantMaxDays) 'Bayi',
    if (ageDays >= 0 && ageDays < _childMaxYears * 365) 'Anak',
    if (sex.isNotEmpty) sex,
    'Dewasa',
    '',
  ];
  for (final who in order) {
    for (final r in p.references) {
      if (r.who == who) return r.range;
    }
  }
  return p.referenceRange.split('\n').map((l) => l.trim()).join('; ');
}

/// The `items` to send for the form rows: only rows with a result. The
/// backend fills name, unit, reference and status from `lab_parameter_id`;
/// they are sent too (with [reference] per row) so the device shows the
/// result before the next refresh.
List<Map<String, dynamic>> labParameterItems(
  Iterable<LabParameter> parameters,
  Map<String, String> results, {
  String Function(LabParameter)? reference,
}) => [
  for (final p in parameters)
    if ((results[p.id] ?? '').trim().isNotEmpty)
      {
        'lab_parameter_id': p.id,
        'test_name': p.name,
        'test_category': p.group.isEmpty ? p.section : p.group,
        'unit': p.unit,
        'reference_range': reference?.call(p) ?? p.referenceRange,
        'result_value': results[p.id]!.trim(),
      },
];
