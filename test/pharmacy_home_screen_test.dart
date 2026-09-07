import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/auth_repository.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/doctor.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';
import 'package:bayan_rme/features/pharmacy/presentation/pharmacy_home_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _FakeAuthRepository implements AuthRepository {
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
          id: 'hist-1',
          code: 'REG-20260906-001',
          patientId: 'patient-1',
          patientName: 'Ahmad Dahlan',
          patientNik: '3171010101900001',
          statusPenanganan: 'Menunggu Obat',
          date: '2026-09-06',
          createdAt: '2026-09-06T14:30:00Z',
        ),
        MedicalHistory(
          id: 'hist-2',
          code: 'REG-20260906-002',
          patientId: 'patient-2',
          patientName: 'Siti Aminah',
          patientNik: '3171010101900002',
          statusPenanganan: 'Selesai',
          date: '2026-09-06',
          createdAt: '2026-09-06T15:00:00Z',
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
      nama: id == 'patient-1' ? 'Ahmad Dahlan' : 'Siti Aminah',
      nik: '3171010101900001',
      jk: Gender.l,
      umur: 30,
      alamat: 'Jakarta',
      keluhanUtama: 'Demam',
      durasiKeluhan: '2 hari',
      lokasiKeluhan: 'Kepala',
      vitals: const Vitals(),
      assignedDokterId: 'doc-1',
      waktuMasuk: '2026-09-06',
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
}

void main() {
  testWidgets('PharmacyHomeScreen Antrian Resep uses medical-history API for listing, search, and status filter', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = AuthSession(
      token: 'fake-token',
      user: const AppUser(
        id: 'u1',
        name: 'Apoteker Joko',
        email: 'joko@bayan.id',
        role: UserRole.pharmacy,
        shipId: 'KM-01',
      ),
    );

    final mockApi = _MockPatientApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(session)),
          patientApiProvider.overrideWithValue(mockApi),
          patientsProvider.overrideWith((ref) => PatientsNotifier(
            api: mockApi,
            autoFetch: false,
          )),
          pharmacyPrescriptionHistoryProvider.overrideWith((ref) => MedicalHistoryNotifier(
            api: mockApi,
            autoFetch: false,
            statusPenanganan: 'Menunggu Obat',
          )),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PharmacyHomeScreen(apotekerName: 'Joko'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap 'Antrian Resep' tab
    await tester.tap(find.text('Antrian Resep'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify API called with default status_penanganan=Menunggu Obat
    expect(mockApi.lastPage, equals(1));
    expect(mockApi.lastLimit, equals(10));
    expect(mockApi.lastSortBy, equals('created_at'));
    expect(mockApi.lastOrder, equals('desc'));
    expect(mockApi.lastStatusPenanganan, equals('Menunggu Obat'));

    // Verify list items displayed from medical history
    expect(find.text('Ahmad Dahlan'), findsWidgets);
    expect(find.text('REG-20260906-001'), findsOneWidget);

    // Verify Status Filter button is present (icon-only)
    final filterBtn = find.byIcon(LucideIcons.filter);
    expect(filterBtn, findsOneWidget);

    // Tap filter button and select 'Semua Status'
    await tester.tap(filterBtn);
    await tester.pumpAndSettle();

    final optSemua = find.text('Semua Status');
    expect(optSemua, findsOneWidget);
    await tester.tap(optSemua);
    await tester.pumpAndSettle();

    expect(mockApi.lastStatusPenanganan, equals('Menunggu Obat,Selesai'));

    // Tap filter button and select 'Menunggu Obat' again
    await tester.tap(filterBtn);
    await tester.pumpAndSettle();
    final optMenungguObat = find.text('Menunggu Obat');
    expect(optMenungguObat, findsWidgets);
    await tester.tap(optMenungguObat.last);
    await tester.pumpAndSettle();

    expect(mockApi.lastStatusPenanganan, equals('Menunggu Obat'));

    // Test Search triggers server-side search
    await tester.enterText(find.byType(TextField), 'Ahmad');
    await tester.pump(const Duration(milliseconds: 400));
    expect(mockApi.lastSearch, equals('Ahmad'));
  });
}
