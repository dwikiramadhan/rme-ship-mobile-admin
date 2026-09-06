import 'package:equatable/equatable.dart';

class Icd9Item extends Equatable {
  const Icd9Item({
    required this.code,
    required this.display,
    this.version = '2015',
  });

  final String code;
  final String display;
  final String version;

  String get formatted => code.isNotEmpty ? '$code - $display' : display;

  factory Icd9Item.fromJson(Map<String, dynamic> json) {
    return Icd9Item(
      code: (json['code'] ?? json['icd9_code'] ?? '').toString(),
      display: (json['display'] ?? json['description'] ?? json['name'] ?? '').toString(),
      version: (json['version'] ?? '2015').toString(),
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
