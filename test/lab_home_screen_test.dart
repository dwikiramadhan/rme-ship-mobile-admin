import 'dart:async';

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
  _FakeAuthRepository(this.session);
  final AuthSession? session;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) =>
      throw UnimplementedError();

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

  @override
  Stream<Map<String, dynamic>> get onEvent => _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  void dispose() {
    _controller.close();
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
        MedicalHistory(
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
        ),
        MedicalHistory(
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
    int limit = 50,
    String type = 'Doctor',
    String? search,
    String? availability,
  }) async {
    return [];
  }

  String? lastSubmittedMedRecId;
  Map<String, dynamic>? lastSubmittedLabBody;

  @override
  Future<Map<String, dynamic>> submitLabExaminations(
    String medRecId,
    Map<String, dynamic> body,
  ) async {
    lastSubmittedMedRecId = medRecId;
    lastSubmittedLabBody = body;
    return {'status': 'success'};
  }
}

void main() {
  testWidgets('LabHomeScreen Daftar Order uses medical-history API with status_penanganan = Menunggu Lab', (tester) async {
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
    final testSession = AuthSession(token: 'mock-token', user: testUser);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(testSession)),
          patientApiProvider.overrideWithValue(mockApi),
          webSocketServiceProvider.overrideWithValue(mockWs),
          patientsProvider.overrideWith((ref) => PatientsNotifier(
            api: mockApi,
            autoFetch: false,
          )),
          labOrderHistoryProvider.overrideWith((ref) => MedicalHistoryNotifier(
            api: mockApi,
            autoFetch: false,
            statusPenanganan: 'Menunggu Lab',
          )),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LabHomeScreen(analystName: 'Analyst RME'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap 'Antrian Lab' tab
    await tester.tap(find.text('Antrian Lab'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify initial call requested status_penanganan = 'Menunggu Lab'
    expect(mockApi.lastStatusPenanganan, 'Menunggu Lab');
    expect(mockApi.lastPage, 1);
    expect(mockApi.lastLimit, 10);
    expect(mockApi.lastSortBy, 'created_at');
    expect(mockApi.lastOrder, 'desc');

    // Verify list items rendered from medical-history
    expect(find.text('Budi Darmawan'), findsWidgets);
    expect(find.text('Dewi Lestari'), findsWidgets);
    expect(find.textContaining('Darah Rutin'), findsOneWidget);
    expect(find.textContaining('Urinalisis Lengkap'), findsOneWidget);
    expect(find.text('Menunggu Lab'), findsWidgets);

    // Test search functionality (server-side query)
    final searchInput = find.byType(TextField);
    if (searchInput.evaluate().isNotEmpty) {
      await tester.enterText(searchInput.first, 'Darmawan');
      await tester.pump(const Duration(milliseconds: 400));

      expect(mockApi.lastSearch, 'Darmawan');
      expect(mockApi.lastStatusPenanganan, 'Menunggu Lab');
    }
  });

  testWidgets('LabOrderDetail submits lab examinations via POST /medical-records/:id/lab-examinations', (tester) async {
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
    final testSession = AuthSession(token: 'mock-token', user: testUser);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(testSession)),
          patientApiProvider.overrideWithValue(mockApi),
          webSocketServiceProvider.overrideWithValue(mockWs),
          patientsProvider.overrideWith((ref) => PatientsNotifier(
            api: mockApi,
            autoFetch: false,
          )),
          labOrderHistoryProvider.overrideWith((ref) => MedicalHistoryNotifier(
            api: mockApi,
            autoFetch: false,
            statusPenanganan: 'Menunggu Lab',
          )),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LabHomeScreen(analystName: 'Analyst RME'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap 'Antrian Lab' tab
    await tester.tap(find.text('Antrian Lab'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Select first patient in list
    await tester.tap(find.text('Budi Darmawan').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify LabOrderDetail rendered
    expect(find.text('ORDER PEMERIKSAAN'), findsOneWidget);
    expect(find.text('HASIL PEMERIKSAAN'), findsOneWidget);
    expect(find.text('Tambah Parameter Pemeriksaan'), findsOneWidget);

    // Tap 'Kirim Hasil ke Dokter' button
    final submitBtn = find.text('Kirim Hasil ke Dokter');
    expect(submitBtn, findsOneWidget);
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
    expect(body['lab_personnel_id'], equals('453b5c3a-4390-4ad7-bb09-8840cb8f33cf'));
    expect(body['items'], isA<List>());
    final items = body['items'] as List;
    expect(items.isNotEmpty, isTrue);
    expect(items.first['test_name'], isNotEmpty);
  });
}
