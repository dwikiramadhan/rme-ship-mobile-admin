import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bayan_rme/core/theme/app_colors.dart';
import 'package:bayan_rme/core/widgets/responsive_master_detail.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/presentation/medical_history_detail_view.dart';
import 'package:bayan_rme/features/patients/presentation/status_meta.dart';

void main() {
  group('MedicalHistory Domain & Serialization', () {
    final sampleJson = {
      "id": "e15f4a0c-8082-45f3-ae25-fdc822554636",
      "code": "RJ05092026-00001",
      "patient_id": "03872b15-c38d-4aa5-a007-e6a59b9b2241",
      "patient": {
        "id": "03872b15-c38d-4aa5-a007-e6a59b9b2241",
        "register_no": "RJ05092026-00001",
        "nik": "3173051208950007",
        "name": "Pierre Gasly",
        "dob": "1995-08-17T00:00:00Z",
        "gender": "Laki-laki",
        "blood_type": "O+",
        "phone": "081234567890",
        "address": "Jl. Pelabuhan No. 12, RT 01 / RW 02",
        "kode_provinsi": 11,
        "kode_kabkota": 11.050000190734863,
        "kode_kecamatan": "11.05.07",
        "kode_kelurahan": "11.05.07.2002",
        "kode_pos": 23652,
        "nama_wali": "Siti Rahma",
        "hubungan_wali": "Istri",
        "keterangan": "Memiliki riwayat alergi antibiotik golongan penisilin",
        "service_ship_code": "RSK-BYNP-LD1",
        "status": "Active",
        "last_visit": "2026-09-05T00:00:00Z",
        "created_at": "2026-09-05T22:39:04.796895+07:00",
        "updated_at": "2026-09-05T22:39:05.130894+07:00"
      },
      "doctor_id": "0f3a4534-3385-4305-8932-7154dd8cb35f",
      "doctor": {
        "id": "0f3a4534-3385-4305-8932-7154dd8cb35f",
        "type": "Doctor",
        "nik": "1271162501970013",
        "name": "dr. Andika Pratama",
        "gender": "Laki-laki",
        "specialty": "DLP, Sp.JP",
        "experience": "12",
        "sip": "7/B.15a/31.73.08.1002.19.BJ/4/TM.09.74/e/2025",
        "phone": "08626267123",
        "user_id": "ea7a3b61-7faf-4430-8e20-e4c5d527b6f7",
        "ship_id": "3a7ff982-e187-49f8-a34e-95f775afda61",
        "status": "Aktif",
        "availability": "On Duty",
        "created_at": "2026-08-28T10:59:31.939683+07:00",
        "updated_at": "2026-09-01T13:15:25.52967+07:00"
      },
      "ship_id": "07330d58-6146-4e33-b68e-278d581e2089",
      "ship": {
        "id": "07330d58-6146-4e33-b68e-278d581e2089",
        "code": "RSK-LD-3",
        "name": "RSK dr. Lie Dharmawan III",
        "type": "Passenger",
        "size": "100",
        "capacity": "",
        "year": "",
        "flag": "",
        "status": "Aktif",
        "created_at": "2026-07-17T14:44:23.564862+07:00",
        "updated_at": "2026-07-17T14:44:23.564862+07:00"
      },
      "port_id": "f7d71b54-4c2c-4b10-a601-b82a604c7315",
      "port": {
        "id": "f7d71b54-4c2c-4b10-a601-b82a604c7315",
        "code": "IDTPK",
        "name": "Pelabuhan Tanjung Priok",
        "type": "Internasional",
        "province": "DKI Jakarta",
        "kabupaten_kota": "",
        "kecamatan": "",
        "kelurahan": "",
        "kode_pos": "",
        "location": "",
        "specific_location": "",
        "latitude": "-6.1045642",
        "longitude": "106.8805674",
        "created_at": "2026-04-22T13:19:14.204854+07:00",
        "updated_at": "2026-08-16T00:46:31.457922+07:00"
      },
      "poli_code": "UMUM",
      "poliklinik": {
        "id": "50ef5a36-85b1-4be4-8ed7-d6fe0bbc7251",
        "code": "UMUM",
        "name": "Poli Umum",
        "description": "Pelayanan pemeriksaan umum untuk seluruh keluhan awal.",
        "status": "Aktif",
        "created_at": "2026-08-04T12:53:35.308262+07:00",
        "updated_at": "2026-08-04T12:53:35.308262+07:00"
      },
      "date": "2026-09-05T00:00:00Z",
      "complaint": "Demam dan sakit kepala",
      "diagnosis": "",
      "diagnosis_detail": "",
      "treatment": "",
      "tindakan_detail": "",
      "notes": "Memiliki riwayat alergi antibiotik golongan penisilin",
      "status": "Stable",
      "status_penanganan": "Menunggu Dokter",
      "systolic": 120,
      "diastolic": 80,
      "blood_pressure": "120/80",
      "heart_rate": 78,
      "temperature": 37,
      "respiratory_rate": 18,
      "oxygen_saturation": 98,
      "created_at": "2026-09-05T22:39:05.10637+07:00",
      "updated_at": "2026-09-05T22:39:05.10637+07:00"
    };

    test('parses exact response from backend correctly with vital signs', () {
      final history = MedicalHistory.fromApiJson(sampleJson);

      expect(history.id, equals("e15f4a0c-8082-45f3-ae25-fdc822554636"));
      expect(history.code, equals("RJ05092026-00001"));
      expect(history.patientId, equals("03872b15-c38d-4aa5-a007-e6a59b9b2241"));
      expect(history.patientName, equals("Pierre Gasly"));
      expect(history.patientNik, equals("3173051208950007"));
      expect(history.doctorName, equals("dr. Andika Pratama"));
      expect(history.doctorSip, equals("7/B.15a/31.73.08.1002.19.BJ/4/TM.09.74/e/2025"));
      expect(history.shipName, equals("RSK dr. Lie Dharmawan III"));
      expect(history.portName, equals("Pelabuhan Tanjung Priok"));
      expect(history.poliCode, equals("UMUM"));
      expect(history.poliName, equals("Poli Umum"));
      expect(history.complaint, equals("Demam dan sakit kepala"));
      expect(history.statusPenanganan, equals("Menunggu Dokter"));

      // Vital Signs
      expect(history.systolic, equals(120));
      expect(history.diastolic, equals(80));
      expect(history.bloodPressure, equals('120/80'));
      expect(history.heartRate, equals(78));
      expect(history.temperature, equals(37.0));
      expect(history.respiratoryRate, equals(18));
      expect(history.oxygenSaturation, equals(98.0));
      expect(history.vitals.tekananDarah, equals('120/80'));
      expect(history.vitals.nadi, equals('78'));
      expect(history.vitals.suhu, equals('37'));
      expect(history.vitals.frekuensiNapas, equals('18'));
      expect(history.vitals.spo2, equals('98'));
    });

    test('statusMetaFromPenanganan maps status_penanganan accurately', () {
      final metaMenunggu = statusMetaFromPenanganan('Menunggu Dokter');
      expect(metaMenunggu.label, equals('Menunggu Dokter'));
      expect(metaMenunggu.color, equals(AppColors.orange));

      final metaDiperiksa = statusMetaFromPenanganan('Diperiksa');
      expect(metaDiperiksa.label, equals('Diperiksa'));
      expect(metaDiperiksa.color, equals(AppColors.blue));

      final metaObat = statusMetaFromPenanganan('Menunggu Obat');
      expect(metaObat.label, equals('Menunggu Obat'));
      expect(metaObat.color, equals(AppColors.yellow));

      final metaSelesai = statusMetaFromPenanganan('Selesai');
      expect(metaSelesai.label, equals('Selesai'));
      expect(metaSelesai.color, equals(AppColors.green));
    });

    test('toPatient maps back to Patient for details', () {
      final history = MedicalHistory.fromApiJson(sampleJson);
      final patient = history.toPatient();

      expect(patient.nama, equals("Pierre Gasly"));
      expect(patient.registerNo, equals("RJ05092026-00001"));
      expect(patient.statusPenanganan, equals("Menunggu Dokter"));
      expect(patient.poliName, equals("Poli Umum"));
    });

    test('toPatient prioritizes diagnosisDetail and tindakanDetail', () {
      final json = {
        ...sampleJson,
        "diagnosis": "A00",
        "diagnosis_detail": "Cholera due to Vibrio cholerae 01 (A00)",
        "treatment": "00.0",
        "tindakan_detail": "Therapeutic ultrasound (00.0)",
      };
      final history = MedicalHistory.fromApiJson(json);
      final patient = history.toPatient();

      expect(patient.diagnosa, equals("Cholera due to Vibrio cholerae 01 (A00)"));
      expect(patient.tindakan, equals("Therapeutic ultrasound (00.0)"));
    });
  });

  testWidgets('MedicalHistoryDetailView renders diagnosis and treatment names', (tester) async {
    final history = MedicalHistory(
      id: '1',
      code: 'RJ001',
      patientId: 'p1',
      patientName: 'Pierre Gasly',
      diagnosis: 'A00, A00.9',
      diagnosisDetail: 'Cholera (A00), Cholera unspecified (A00.9)',
      treatment: '00.0',
      tindakanDetail: 'Therapeutic ultrasound (00.0)',
      statusPenanganan: 'Selesai',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MedicalHistoryDetailView(
                history: history,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify Diagnosa box shows full name and not just code
    expect(find.text('Cholera (A00), Cholera unspecified (A00.9)'), findsOneWidget);
    // Verify Tindakan box shows full name and not just code
    expect(find.text('Therapeutic ultrasound (00.0)'), findsOneWidget);
  });

  testWidgets('HeaderActionButton renders with Tambah Kunjungan tooltip and triggers onPressed', (tester) async {
    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeaderActionButton(
            icon: LucideIcons.plus,
            tooltip: 'Tambah Kunjungan',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.byType(HeaderActionButton), findsOneWidget);
    expect(find.byIcon(LucideIcons.plus), findsOneWidget);

    // Verify tooltip
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, equals('Tambah Kunjungan'));

    await tester.tap(find.byType(HeaderActionButton));
    await tester.pump();
    expect(pressed, isTrue);
  });
}

