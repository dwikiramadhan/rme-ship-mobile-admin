import 'package:equatable/equatable.dart';

class Icd10Item extends Equatable {
  const Icd10Item({
    required this.code,
    required this.display,
    this.version = 'ICD10_2010',
  });

  final String code;
  final String display;
  final String version;

  String get formatted => '$code - $display';

  factory Icd10Item.fromJson(Map<String, dynamic> json) {
    return Icd10Item(
      code: (json['code'] ?? '').toString(),
      display: (json['display'] ?? '').toString(),
      version: (json['version'] ?? 'ICD10_2010').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'display': display,
      'version': version,
    };
  }

  @override
  List<Object?> get props => [code, display, version];
}
