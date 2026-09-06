import 'package:equatable/equatable.dart';

class Vitals extends Equatable {
  const Vitals({
    this.tekananDarah = '',
    this.nadi = '',
    this.suhu = '',
    this.frekuensiNapas = '',
    this.spo2 = '',
    this.systolic,
    this.diastolic,
    this.bloodPressure,
    this.heartRate,
    this.temperature,
    this.respiratoryRate,
    this.oxygenSaturation,
  });

  final String tekananDarah;
  final String nadi;
  final String suhu;
  final String frekuensiNapas;
  final String spo2;

  final int? systolic;
  final int? diastolic;
  final String? bloodPressure;
  final int? heartRate;
  final double? temperature;
  final int? respiratoryRate;
  final double? oxygenSaturation;

  bool get isEmpty =>
      tekananDarah.isEmpty &&
      nadi.isEmpty &&
      suhu.isEmpty &&
      frekuensiNapas.isEmpty &&
      spo2.isEmpty &&
      systolic == null &&
      diastolic == null &&
      heartRate == null &&
      temperature == null &&
      respiratoryRate == null &&
      oxygenSaturation == null;

  factory Vitals.fromJson(Map<String, dynamic> json) {
    final sys = (json['systolic'] as num?)?.toInt() ??
        int.tryParse(json['systolic']?.toString() ?? '');
    final dia = (json['diastolic'] as num?)?.toInt() ??
        int.tryParse(json['diastolic']?.toString() ?? '');
    String bp = json['blood_pressure']?.toString() ??
        json['tekanan_darah']?.toString() ??
        json['bloodPressure']?.toString() ??
        '';
    if (bp.isEmpty && sys != null && dia != null) {
      bp = '$sys/$dia';
    }

    final hr = (json['heart_rate'] as num?)?.toInt() ??
        int.tryParse(json['heart_rate']?.toString() ?? '') ??
        int.tryParse(json['heartRate']?.toString() ?? '') ??
        int.tryParse(json['nadi']?.toString() ?? '');

    final temp = (json['temperature'] as num?)?.toDouble() ??
        double.tryParse(
          json['temperature']?.toString().replaceAll(',', '.') ?? '',
        ) ??
        double.tryParse(json['suhu']?.toString().replaceAll(',', '.') ?? '');

    final rr = (json['respiratory_rate'] as num?)?.toInt() ??
        int.tryParse(json['respiratory_rate']?.toString() ?? '') ??
        int.tryParse(json['respiratoryRate']?.toString() ?? '') ??
        int.tryParse(json['frekuensi_napas']?.toString() ?? '');

    final spo2 = (json['oxygen_saturation'] as num?)?.toDouble() ??
        double.tryParse(
          json['oxygen_saturation']?.toString().replaceAll(',', '.') ?? '',
        ) ??
        double.tryParse(
          json['oxygenSaturation']?.toString().replaceAll(',', '.') ?? '',
        ) ??
        double.tryParse(json['spo2']?.toString().replaceAll(',', '.') ?? '');

    return Vitals(
      tekananDarah:
          bp.isNotEmpty ? bp : (json['tekanan_darah']?.toString() ?? ''),
      nadi: hr != null ? hr.toString() : (json['nadi']?.toString() ?? ''),
      suhu: temp != null
          ? (temp % 1 == 0 ? temp.toInt().toString() : temp.toString())
          : (json['suhu']?.toString() ?? ''),
      frekuensiNapas:
          rr != null ? rr.toString() : (json['frekuensi_napas']?.toString() ?? ''),
      spo2: spo2 != null
          ? (spo2 % 1 == 0 ? spo2.toInt().toString() : spo2.toString())
          : (json['spo2']?.toString() ?? ''),
      systolic: sys,
      diastolic: dia,
      bloodPressure: bp.isNotEmpty ? bp : null,
      heartRate: hr,
      temperature: temp,
      respiratoryRate: rr,
      oxygenSaturation: spo2,
    );
  }

  Vitals copyWith({
    String? tekananDarah,
    String? nadi,
    String? suhu,
    String? frekuensiNapas,
    String? spo2,
    int? systolic,
    int? diastolic,
    String? bloodPressure,
    int? heartRate,
    double? temperature,
    int? respiratoryRate,
    double? oxygenSaturation,
  }) {
    return Vitals(
      tekananDarah: tekananDarah ?? this.tekananDarah,
      nadi: nadi ?? this.nadi,
      suhu: suhu ?? this.suhu,
      frekuensiNapas: frekuensiNapas ?? this.frekuensiNapas,
      spo2: spo2 ?? this.spo2,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      bloodPressure: bloodPressure ?? this.bloodPressure,
      heartRate: heartRate ?? this.heartRate,
      temperature: temperature ?? this.temperature,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      oxygenSaturation: oxygenSaturation ?? this.oxygenSaturation,
    );
  }

  @override
  List<Object?> get props => [
    tekananDarah,
    nadi,
    suhu,
    frekuensiNapas,
    spo2,
    systolic,
    diastolic,
    bloodPressure,
    heartRate,
    temperature,
    respiratoryRate,
    oxygenSaturation,
  ];
}
