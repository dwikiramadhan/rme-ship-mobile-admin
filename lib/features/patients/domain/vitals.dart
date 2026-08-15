import 'package:equatable/equatable.dart';

class Vitals extends Equatable {
  const Vitals({
    this.tekananDarah = '',
    this.nadi = '',
    this.suhu = '',
    this.frekuensiNapas = '',
    this.spo2 = '',
  });

  final String tekananDarah;
  final String nadi;
  final String suhu;
  final String frekuensiNapas;
  final String spo2;

  bool get isEmpty =>
      tekananDarah.isEmpty && nadi.isEmpty && suhu.isEmpty && frekuensiNapas.isEmpty && spo2.isEmpty;

  Vitals copyWith({
    String? tekananDarah,
    String? nadi,
    String? suhu,
    String? frekuensiNapas,
    String? spo2,
  }) {
    return Vitals(
      tekananDarah: tekananDarah ?? this.tekananDarah,
      nadi: nadi ?? this.nadi,
      suhu: suhu ?? this.suhu,
      frekuensiNapas: frekuensiNapas ?? this.frekuensiNapas,
      spo2: spo2 ?? this.spo2,
    );
  }

  @override
  List<Object?> get props => [tekananDarah, nadi, suhu, frekuensiNapas, spo2];
}
