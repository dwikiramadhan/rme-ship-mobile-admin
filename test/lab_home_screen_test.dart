import 'dart:typed_data';
import 'package:bayan_rme/features/patients/domain/lab_parameter.dart';
import 'package:bayan_rme/features/patients/domain/lab_test_type.dart';
import 'package:bayan_rme/features/lab/presentation/lab_order_detail.dart';
import 'package:bayan_rme/core/widgets/app_button.dart';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/auth_repository.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/lab/presentation/lab_home_screen.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/core/network/websocket_service.dart';
import 'package:bayan_rme/features/patients/domain/doctor.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession?> refreshUser(AuthSession current) async => null;

  _FakeAuthRepository(this.session);
  final AuthSession? session;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<void> logout() async {}

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}
}

class _MockWebSocketService implements WebSocketService {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _connController = StreamController<bool>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onEvent => _controller.stream;

  @override
  Stream<bool> get onConnectionChanged => _connController.stream;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  void dispose() {
    _controller.close();
    _connController.close();
  }
}

class _MockPatientApi implements PatientApi {
  int fetchCallCount = 0;
  String? lastSearch;
  String? lastStatusPenanganan;
  int lastPage = 1;
  int lastLimit = 10;
  String lastSortBy = '';
  String lastOrder = '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PaginatedMedicalHistory> getMedicalHistoryPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? statusPenanganan,
    String? userId,
    bool includePendingPrescriptions = false,
    bool includeReferred = false,
    String sortBy = 'created_at',
    String order = 'desc',
  }) async {
    fetchCallCount++;
    lastPage = page;
    lastLimit = limit;
    lastSearch = search;
    lastStatusPenanganan = statusPenanganan;
    lastSortBy = sortBy;
    lastOrder = order;

    return PaginatedMedicalHistory(
      data: [
        const MedicalHistory(
          id: 'hist-lab-1',
          code: 'REG-20260907-001',
          patientId: 'patient-lab-1',
          patientName: 'Budi Darmawan',
          patientNik: '3171010101900010',
          statusPenanganan: 'Menunggu Lab',
          notes: 'Order Lab: Darah Rutin (Puasa 8 jam)',
          treatment: 'Hematologi Lengkap',
          doctorName: 'Budi Santoso',
          date: '2026-09-07',
          createdAt: '2026-09-07T08:30:00Z',
          rawJson: {
            'lab_examination': {
              'id': 'lab-1',
              'requested_test': 'Hematologi: Hematologi Rutin',
            },
          },
        ),
        const MedicalHistory(
          id: 'hist-lab-2',
          code: 'REG-20260907-002',
          patientId: 'patient-lab-2',
          patientName: 'Dewi Lestari',
          patientNik: '3171010101900020',
          statusPenanganan: 'Menunggu Lab',
          tindakanDetail: 'Urinalisis Lengkap',
          doctorName: 'Budi Santoso',
          date: '2026-09-07',
          createdAt: '2026-09-07T09:00:00Z',
        ),
      ],
      page: page,
      limit: limit,
      total: 2,
      totalPages: 1,
    );
  }

  @override
  Future<Patient> getPatient(String id) async {
    return Patient(
      id: id,
      nama: id == 'patient-lab-1' ? 'Budi Darmawan' : 'Dewi Lestari',
      nik: '3171010101900010',
      jk: Gender.l,
      umur: 30,
      alamat: 'Jakarta',
      keluhanUtama: 'Demam',
      durasiKeluhan: '2 hari',
      lokasiKeluhan: 'Kepala',
      vitals: const Vitals(),
      assignedDokterId: 'doc-1',
      waktuMasuk: '2026-09-07',
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMedicalRecords(String patientId) async {
    return [];
  }

  @override
  Future<List<Doctor>> getDoctors({
    int page = 1,
    int limit = 15,
    String type = 'Doctor',
    String? search,
    String? availability,
  }) async {
    return [];
  }

  String? lastSubmittedMedRecId;
  Map<String, dynamic>? lastSubmittedLabBody;
  int lastSubmittedFiles = 0;

  @override
  Future<Map<String, dynamic>> submitLabExaminations(
    String medRecId,
    dynamic data,
  ) async {
    lastSubmittedMedRecId = medRecId;
    if (data is FormData) {
      lastSubmittedFiles = data.files.length;
      final map = <String, dynamic>{};
      for (final entry in data.fields) {
        if (entry.key == 'items') {
          map[entry.key] = jsonDecode(entry.value);
        } else {
          map[entry.key] = entry.value;
        }
      }
      lastSubmittedLabBody = map;
    } else if (data is Map<String, dynamic>) {
      lastSubmittedLabBody = data;
    }
    return {'status': 'success'};
  }
}

void main() {
  testWidgets(
    'LabHomeScreen Daftar Order uses medical-history API with status_penanganan = Menunggu Lab',
    (tester) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockApi = _MockPatientApi();
      final mockWs = _MockWebSocketService();
      const testUser = AppUser(
        id: 'analyst-1',
        name: 'Analyst RME',
        email: 'analyst@bayan.id',
        role: UserRole.lab,
      );
      const testSession = AuthSession(token: 'mock-token', user: testUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(testSession),
            ),
            patientApiProvider.overrideWithValue(mockApi),
            webSocketServiceProvider.overrideWithValue(mockWs),
            patientsProvider.overrideWith(
              (ref) => PatientsNotifier(api: mockApi, autoFetch: false),
            ),
            medicalHistoryProvider.overrideWith(
              (ref) => MedicalHistoryNotifier(api: mockApi, autoFetch: false),
            ),
            labOrderHistoryProvider.overrideWith(
              (ref) => MedicalHistoryNotifier(
                api: mockApi,
                autoFetch: false,
                statusPenanganan: 'Menunggu Lab',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: LabHomeScreen(analystName: 'Analyst RME')),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap 'Antrian Lab' tab
      await tester.tap(find.text('Antrian Lab'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify initial call requested status_penanganan = 'Menunggu Lab'
      expect(mockApi.lastStatusPenanganan, 'Menunggu Lab');
      expect(mockApi.lastPage, 1);
      expect(mockApi.lastLimit, 10);
      expect(mockApi.lastSortBy, 'created_at');
      expect(mockApi.lastOrder, 'desc');

      // Verify list items rendered from medical-history
      expect(find.text('Budi Darmawan'), findsWidgets);
      expect(find.text('Dewi Lestari'), findsWidgets);
      expect(
        find.textContaining('Darah Rutin · dr. Budi Santoso'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Urinalisis Lengkap · dr. Budi Santoso'),
        findsOneWidget,
      );
      expect(find.text('Menunggu Lab'), findsWidgets);

      // Test search functionality (server-side query)
      final searchInput = find.byType(TextField);
      if (searchInput.evaluate().isNotEmpty) {
        await tester.enterText(searchInput.first, 'Darmawan');
        await tester.pump(const Duration(milliseconds: 400));

        expect(mockApi.lastSearch, 'Darmawan');
        expect(mockApi.lastStatusPenanganan, 'Menunggu Lab');
      }
    },
  );

  testWidgets(
    'LabOrderDetail submits lab examinations via POST /medical-records/:id/lab-examinations',
    (tester) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockApi = _MockPatientApi();
      final mockWs = _MockWebSocketService();
      const testUser = AppUser(
        id: '453b5c3a-4390-4ad7-bb09-8840cb8f33cf',
        name: 'Analyst RME',
        email: 'analyst@bayan.id',
        role: UserRole.lab,
      );
      const testSession = AuthSession(token: 'mock-token', user: testUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(testSession),
            ),
            patientApiProvider.overrideWithValue(mockApi),
            webSocketServiceProvider.overrideWithValue(mockWs),
            patientsProvider.overrideWith(
              (ref) => PatientsNotifier(api: mockApi, autoFetch: false),
            ),
            medicalHistoryProvider.overrideWith(
              (ref) => MedicalHistoryNotifier(api: mockApi, autoFetch: false),
            ),
            labOrderHistoryProvider.overrideWith(
              (ref) => MedicalHistoryNotifier(
                api: mockApi,
                autoFetch: false,
                statusPenanganan: 'Menunggu Lab',
              ),
            ),
            labTestsProvider.overrideWith(
              (ref) async => const [
                LabTestType(
                  id: 't1',
                  category: 'Hematologi',
                  name: 'Hematologi Rutin',
                ),
              ],
            ),
            labParametersProvider.overrideWith(
              (ref) async => const [
                LabParameter(
                  id: 'hb',
                  section: 'Hematologi',
                  name: 'Hemoglobin',
                  unit: 'g/dL',
                  referenceRange: 'L : 13,5 – 17,5\nP : 11,7 – 15,5',
                  references: [
                    LabReference(who: 'L', range: '13,5 – 17,5'),
                    LabReference(who: 'P', range: '11,7 – 15,5'),
                  ],
                  sortOrder: 1,
                  labTestIds: ['t1'],
                ),
                LabParameter(
                  id: 'warna',
                  section: 'Urinalisa',
                  name: 'Warna',
                  inputType: kLabInputCombo,
                  options: ['Kuning Muda', 'Kuning', 'Merah'],
                  referenceRange: 'Kuning Muda',
                  sortOrder: 2,
                  labTestIds: ['t1'],
                ),
                LabParameter(
                  id: 'goldar',
                  section: 'Golongan Darah',
                  name: 'Golongan Darah',
                  inputType: kLabInputSelect,
                  options: ['A Rh+', 'O Rh+'],
                  sortOrder: 11,
                ),
              ],
            ),
            labDocumentPickerProvider.overrideWithValue(
              () async => (
                name: 'hasil.pdf',
                bytes: Uint8List.fromList([37, 80, 68, 70]),
                path: null,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: LabHomeScreen(analystName: 'Analyst RME')),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap 'Antrian Lab' tab
      await tester.tap(find.text('Antrian Lab'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select first patient in list
      await tester.tap(find.text('Budi Darmawan').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify LabOrderDetail rendered
      // Doctor's examination summary (same as the doctor's detail screen)
      expect(find.text('Hasil Pemeriksaan Dokter'), findsOneWidget);
      expect(find.text('Diagnosa Klinis'), findsOneWidget);
      expect(find.text('Hasil Pemeriksaan Lab'), findsOneWidget);
      // Nothing to send yet: no result and no document.
      final submitBtn = find.text('Kirim Hasil ke Dokter');
      expect(submitBtn, findsOneWidget);
      AppButton button() => tester.widget<AppButton>(
        find.ancestor(of: submitBtn, matching: find.byType(AppButton)),
      );
      expect(button().onPressed, isNull);

      // The requested test's rows are on the form, with the patient's
      // reference range.
      expect(find.text('HEMATOLOGI'), findsOneWidget);
      expect(find.text('Hemoglobin'), findsOneWidget);
      expect(find.text('Rujukan: 13,5 – 17,5'), findsOneWidget);
      expect(find.text('Golongan Darah'), findsNothing);

      // Another row from the form, searchable.
      final addParam = find.text('Tambah parameter lain');
      await tester.ensureVisible(addParam);
      await tester.tap(addParam);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Cari parameter atau bagian...'),
        'golongan',
      );
      await tester.pump();
      await tester.tap(find.text('Golongan Darah').last);
      await tester.pumpAndSettle();
      expect(find.text('GOLONGAN DARAH'), findsOneWidget);

      // A result is enough: the document is optional.
      final hb = find.byKey(const ValueKey('lab-param-hb'));
      await tester.ensureVisible(hb);
      await tester.enterText(hb, '14,2');
      await tester.pump();
      expect(button().onPressed, isNotNull);

      // Urine colour: pick a suggestion, or type freely.
      final warnaOptions = find.byKey(const ValueKey('lab-param-options-warna'));
      await tester.ensureVisible(warnaOptions);
      await tester.tap(warnaOptions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kuning').last);
      await tester.pumpAndSettle();
      final warna = find.byKey(const ValueKey('lab-param-warna'));
      expect(tester.widget<TextField>(warna).controller!.text, 'Kuning');
      await tester.enterText(warna, 'Kuning kemerahan');
      await tester.pump();

      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify mock API received the correct POST body structure
      expect(mockApi.lastSubmittedMedRecId, equals('hist-lab-1'));
      final body = mockApi.lastSubmittedLabBody;
      expect(body, isNotNull);
      expect(body!['medical_record_id'], equals('hist-lab-1'));
      expect(body['patient_id'], equals('patient-lab-1'));
      expect(
        body['lab_personnel_id'],
        anyOf(isNull, equals('453b5c3a-4390-4ad7-bb09-8840cb8f33cf')),
      );
      expect(body['items'], isA<List>());
      final items = body['items'] as List;
      // Only rows with a result are sent, by their form row.
      expect(items, hasLength(2));
      expect(items.first['lab_parameter_id'], 'hb');
      expect(items.first['result_value'], '14,2');
      expect(items.last['lab_parameter_id'], 'warna');
      expect(items.last['result_value'], 'Kuning kemerahan');
      expect(mockApi.lastSubmittedFiles, 0);
    },
  );
}
