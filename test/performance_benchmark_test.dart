import 'dart:math';
import 'package:bayan_rme/core/theme/app_theme.dart';
import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/auth/presentation/auth_state.dart';
import 'package:bayan_rme/features/history/presentation/visit_history_screen.dart';
import 'package:bayan_rme/features/medicine_stock/domain/ship_medicine_stock.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('⚡ Performance & Benchmark Suite', () {
    test('1. JSON Deserialization Throughput (1,000 MedicalHistory & Patient models)', () {
      final sampleHistoryJson = <String, dynamic>{
        'id': 'hist-uuid-001',
        'code': 'RM-2026-0001',
        'patient_id': 'pat-uuid-001',
        'patient': {
          'id': 'pat-uuid-001',
          'name': 'Budi Santoso',
          'nik': '3374031203680001',
          'gender': 'Laki-laki',
          'dob': '1985-05-12T00:00:00Z',
        },
        'user_id': 'usr-uuid-001',
        'doctor_name': 'dr. Lie Dharmawan',
        'doctor_sip': 'SIP/123/2026',
        'ship_name': 'RSK dr. Lie Dharmawan Bayan Peduli I',
        'date': '2026-10-05',
        'complaint': 'Pusing dan demam tinggi',
        'diagnosis': 'Faringitis Akut (J02.9)',
        'treatment': 'Paracetamol 500mg 3x1',
        'status_penanganan': 'Selesai',
        'created_at': '2026-10-05T08:30:00Z',
        'vitals': {
          'systolic': 120,
          'diastolic': 80,
          'heart_rate': 78,
          'temperature': 36.6,
          'respiratory_rate': 18,
          'oxygen_saturation': 98,
        },
      };

      final samplePatientJson = <String, dynamic>{
        'id': 'pat-uuid-001',
        'name': 'Ahmad Fauzi',
        'nik': '3271011504880003',
        'gender': 'Laki-laki',
        'dob': '1990-01-15T00:00:00Z',
        'phone': '08123456789',
        'status': 'Menunggu Dokter',
        'status_penanganan': 'Menunggu Pemeriksaan Dokter',
        'keluhan_utama': 'Batuk berdahak',
        'created_at': '2026-10-05T08:00:00Z',
      };

      final sampleMedicineJson = <String, dynamic>{
        'id': 'med-uuid-001',
        'medicine_name': 'Amoxicillin 500mg',
        'category': 'Antibiotik',
        'unit': 'Tablet',
        'stock': 120,
        'minimum_stock': 20,
        'expiry_date': '2027-10-05T00:00:00Z',
      };

      // Measure 1,000 MedicalHistory parses
      final swHist = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        MedicalHistory.fromApiJson(sampleHistoryJson);
      }
      swHist.stop();

      // Measure 1,000 Patient parses
      final swPat = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        Patient.fromApiJson(samplePatientJson);
      }
      swPat.stop();

      // Measure 1,000 ShipMedicineStock parses
      final swMed = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        ShipMedicineStock.fromJson(sampleMedicineJson);
      }
      swMed.stop();

      debugPrint('📊 [Benchmark: JSON Deserialization]');
      debugPrint('   - 1,000 MedicalHistory: ${swHist.elapsedMilliseconds} ms (${(1000 / (swHist.elapsedMicroseconds / 1000000)).toStringAsFixed(0)} ops/s)');
      debugPrint('   - 1,000 Patient: ${swPat.elapsedMilliseconds} ms (${(1000 / (swPat.elapsedMicroseconds / 1000000)).toStringAsFixed(0)} ops/s)');
      debugPrint('   - 1,000 MedicineStock: ${swMed.elapsedMilliseconds} ms (${(1000 / (swMed.elapsedMicroseconds / 1000000)).toStringAsFixed(0)} ops/s)');

      // Target: each batch of 1,000 objects must parse well under 100ms
      expect(swHist.elapsedMilliseconds, lessThan(100));
      expect(swPat.elapsedMilliseconds, lessThan(100));
      expect(swMed.elapsedMilliseconds, lessThan(100));
    });

    test('2. In-Memory Sorting & Pagination Processing Budget (< 16ms 60fps frame budget)', () {
      final rand = Random(42);
      final testItems = List.generate(1000, (i) {
        final days = rand.nextInt(365);
        final date = DateTime.now().subtract(Duration(days: days, hours: rand.nextInt(24)));
        return MedicalHistory(
          id: 'hist-$i',
          code: 'RM-$i',
          patientId: 'pat-$i',
          patientName: 'Pasien $i',
          patientNik: '31710000000000$i',
          diagnosis: 'Diagnosis $i',
          createdAt: date.toIso8601String(),
          statusPenanganan: i % 2 == 0 ? 'Selesai' : 'Menunggu Obat',
        );
      });

      // Baseline naive sort with DateTime.tryParse (unoptimized)
      final swNaiveSort = Stopwatch()..start();
      final copyNaive = List<MedicalHistory>.from(testItems);
      copyNaive.sort((a, b) {
        final timeA = DateTime.tryParse(a.createdAt ?? a.date ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = DateTime.tryParse(b.createdAt ?? b.date ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
      swNaiveSort.stop();

      // Optimized ISO-8601 lexicographical string sort (O(N log N) string ops, zero parsing overhead)
      final swOptimizedSort = Stopwatch()..start();
      final copyOptimized = List<MedicalHistory>.from(testItems);
      copyOptimized.sort((a, b) {
        final strA = a.createdAt ?? a.date ?? '';
        final strB = b.createdAt ?? b.date ?? '';
        return strB.compareTo(strA);
      });
      final page1 = copyOptimized.take(15).toList();
      swOptimizedSort.stop();

      debugPrint('📊 [Benchmark: Sorting & State Slice]');
      debugPrint('   - Naive (DateTime.tryParse in sort loop): ${swNaiveSort.elapsedMicroseconds} µs (${swNaiveSort.elapsedMilliseconds} ms)');
      debugPrint('   - Optimized (ISO string comparison):     ${swOptimizedSort.elapsedMicroseconds} µs (${swOptimizedSort.elapsedMilliseconds} ms)');

      expect(page1.length, equals(15));
      // Optimized sort must comfortably fit within the 16.6ms 60fps frame budget
      expect(swOptimizedSort.elapsedMilliseconds, lessThan(16));
    });

    test('3. Client-Side Substring Search Benchmark (1,000 items)', () {
      final items = List.generate(1000, (i) {
        return MedicalHistory(
          id: 'hist-$i',
          code: 'RM-$i',
          patientId: 'pat-$i',
          patientName: i % 7 == 0 ? 'Budi Santoso $i' : 'Pasien Umum $i',
          patientNik: '3201${i.toString().padLeft(6, '0')}',
          diagnosis: i % 3 == 0 ? 'Hipertensi esensial' : 'ISPA ringan',
        );
      });

      const query = 'budi';
      final swSearch = Stopwatch()..start();
      final filtered = items.where((m) {
        return m.patientName.toLowerCase().contains(query) ||
            m.patientNik.contains(query) ||
            (m.diagnosis?.toLowerCase().contains(query) ?? false);
      }).toList();
      swSearch.stop();

      debugPrint('📊 [Benchmark: Search Filtering]');
      debugPrint('   - Search 1,000 items for "$query": ${swSearch.elapsedMicroseconds} µs (${filtered.length} matches)');
      expect(swSearch.elapsedMilliseconds, lessThan(5));
      expect(filtered.isNotEmpty, isTrue);
    });

    testWidgets('4. UI Widget Build & Layout Latency (VisitHistoryScreen with 50 entries)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyHistories = List<MedicalHistory>.generate(50, (i) {
        return MedicalHistory(
          id: 'hist-$i',
          code: 'RM-$i',
          patientId: 'pat-$i',
          patientName: 'Pasien Uji $i',
          patientNik: '3171020000000$i',
          createdAt: DateTime.now().subtract(Duration(hours: i * 3)).toIso8601String(),
          diagnosis: 'Diagnosa Kunjungan $i',
          complaint: 'Keluhan pasien $i',
          treatment: 'Terapi $i',
          statusPenanganan: 'Selesai',
        );
      });

      const loggedUser = AppUser(
        id: 'usr-doctor-1',
        name: 'Dr. Budi Santoso',
        email: 'budi@rme.id',
        role: UserRole.dokter,
      );

      final swRender = Stopwatch()..start();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _BenchmarkAuthController(
              const AuthState.authenticated(AuthSession(token: 'fake-jwt', user: loggedUser)),
            )),
            medicalHistoryByUserProvider('usr-doctor-1').overrideWith(
              (ref) => _BenchmarkMedicalHistoryNotifier(dummyHistories),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: VisitHistoryScreen(canEdit: true),
            ),
          ),
        ),
      );
      await tester.pump();
      swRender.stop();

      debugPrint('📊 [Benchmark: UI Rendering & MasterDetail Layout]');
      debugPrint('   - VisitHistoryScreen initial pump (50 records): ${swRender.elapsedMilliseconds} ms');

      expect(find.text('Riwayat Kunjungan'), findsOneWidget);
      expect(find.text('50 rekam medis'), findsOneWidget);
      expect(find.text('Pasien Uji 0'), findsWidgets);
      expect(swRender.elapsedMilliseconds, lessThan(2000));
    });
  });
}

class _BenchmarkAuthController extends StateNotifier<AuthState> implements AuthController {
  _BenchmarkAuthController(super.initial);

  @override
  Future<void> login({required String email, required String password, bool rememberMe = true}) async {}

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {}

  @override
  Future<void> logout() async {}
}

class _BenchmarkMedicalHistoryNotifier extends StateNotifier<List<MedicalHistory>> implements MedicalHistoryNotifier {
  _BenchmarkMedicalHistoryNotifier(super.initial);

  @override
  bool get isLoading => false;

  @override
  bool get isLoadingMore => false;

  @override
  bool get hasMore => false;

  @override
  int get total => state.length;

  @override
  int get totalPages => 1;

  @override
  int get currentPage => 1;

  @override
  String? get statusPenanganan => null;

  @override
  set statusPenanganan(String? _) {}

  @override
  String? get userId => null;

  @override
  set userId(String? _) {}

  @override
  void setDoctorId(String? _) {}

  @override
  void setUserId(String? _) {}

  @override
  void setStatusPenanganan(String? _) {}

  @override
  Future<void> fetchHistory({bool refresh = false}) async {}

  @override
  Future<void> loadMore() async {}

  @override
  void searchHistory(String query, {bool debounce = false}) {}

  @override
  void upsertHistory(MedicalHistory history) {}

  @override
  void updateHistoryStatus({
    required String recordId,
    String? patientId,
    required String statusPenanganan,
    String? diagnosis,
    String? treatment,
    String? notes,
  }) {}
}
