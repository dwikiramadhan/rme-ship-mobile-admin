import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/auth/presentation/auth_state.dart';
import 'package:bayan_rme/features/doctor/presentation/widgets/examination_input_modal.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/doctor.dart';
import 'package:bayan_rme/features/patients/domain/doctor_referral.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/schedule/domain/trip_schedule.dart';

// A doctor refers the patient to another doctor on the ongoing trip; the
// other doctor takes the visit over.

const _visit = <String, dynamic>{
  'id': 'mr-1',
  'doctor_id': 'mp-b',
  'doctor': {'id': 'mp-b', 'name': 'dr. B', 'user_id': 'u-b'},
  'status_penanganan': 'Menunggu Dokter',
  'referrals': [
    {
      'from_doctor_id': 'mp-a',
      'from_doctor': {'id': 'mp-a', 'name': 'dr. A', 'user_id': 'u-a'},
      'to_doctor_id': 'mp-b',
      'to_doctor': {'id': 'mp-b', 'name': 'dr. B', 'user_id': 'u-b'},
      'reason': ' Perlu spesialis ',
      'created_at': '2026-10-22T10:00:00+07:00',
    },
  ],
};

class _RecordingApi extends PatientApi {
  final referredFlags = <bool>[];

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
    referredFlags.add(includeReferred);
    return PaginatedMedicalHistory(
      data: const [],
      page: 1,
      limit: limit,
      total: 0,
      totalPages: 1,
    );
  }
}

/// Signed in as [user].
class _FakeAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _FakeAuthController(AppUser user)
    : super(AuthState.authenticated(AuthSession(token: 't', user: user)));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a visit lists its referrals with both doctors and the reason', () {
    final referrals = referralsOf(_visit);
    expect(referrals, hasLength(1));
    expect(referrals.single.fromName, 'dr. A');
    expect(referrals.single.toName, 'dr. B');
    expect(referrals.single.reason, 'Perlu spesialis');
    expect(referrals.single.createdAt, isNotNull);
    expect(referralsOf(const {}), isEmpty);
  });

  test('only the referring doctor sees the visit as referred away', () {
    expect(isReferredAway(_visit, 'u-a'), isTrue);
    expect(isReferredAway(_visit, 'u-b'), isFalse);
    expect(isReferredAway(_visit, 'u-c'), isFalse);
    expect(isReferredAway(_visit, ''), isFalse);
    // Referred back: the referring doctor is the visit's doctor again.
    final back = {
      ..._visit,
      'doctor': {'id': 'mp-a', 'name': 'dr. A', 'user_id': 'u-a'},
    };
    expect(isReferredAway(back, 'u-a'), isFalse);
  });

  test("the trip's doctors but the visit's own doctor can be picked", () {
    const doctors = [
      Doctor(id: 'mp-a', nama: 'dr. A', spesialisasi: '', online: true),
      Doctor(id: 'mp-b', nama: 'dr. B', spesialisasi: 'Gigi', online: true),
    ];
    expect(referralCandidates(doctors, 'mp-a').map((d) => d.id), ['mp-b']);
    expect(referralCandidates(doctors, null), hasLength(2));
  });

  test('the signed-in doctor is not offered either', () {
    const doctors = [
      Doctor(id: 'mp-a', nama: 'dr. A', spesialisasi: '', online: true, userId: 'u-a'),
      Doctor(id: 'mp-b', nama: 'dr. B', spesialisasi: '', online: true, userId: 'u-b'),
      Doctor(id: 'mp-c', nama: 'dr. C', spesialisasi: '', online: true),
    ];
    expect(
      referralCandidates(doctors, 'mp-b', userId: 'u-a').map((d) => d.id),
      ['mp-c'],
    );
    // No account to match: only the visit's doctor is left out.
    expect(referralCandidates(doctors, 'mp-b', userId: '').map((d) => d.id), [
      'mp-a',
      'mp-c',
    ]);
  });

  test('a trip doctor carries their login account', () {
    final doctor = SchedulePersonnelItem.fromJson(const {
      'id': 'pivot-1',
      'medical_personnel_id': 'mp-a',
      'doctor': {'id': 'mp-a', 'name': 'dr. A', 'user_id': 'u-a'},
    });
    expect(doctor.id, 'mp-a');
    expect(doctor.userId, 'u-a');
    expect(SchedulePersonnelItem.fromJson(const {'name': 'dr. X'}).userId, '');
  });

  test('the referral payload trims the reason', () {
    expect(referralRequestJson(toDoctorId: 'mp-b', reason: ' Perlu spesialis '), {
      'to_doctor_id': 'mp-b',
      'reason': 'Perlu spesialis',
    });
  });

  test("only the doctor's history asks for the visits they referred", () async {
    final api = _RecordingApi();
    final history = MedicalHistoryNotifier(
      api: api,
      autoFetch: false,
      userId: 'u-a',
      includeReferred: true,
    );
    addTearDown(history.dispose);
    await history.fetchHistory(refresh: true);
    await history.warmCache();
    expect(api.referredFlags, [true, true]);

    final queue = MedicalHistoryNotifier(api: api, autoFetch: false, userId: 'u-a');
    addTearDown(queue.dispose);
    await queue.fetchHistory(refresh: true);
    expect(api.referredFlags.last, isFalse);
  });

  testWidgets('the referred doctor sees why, and can refer on to a trip doctor', (tester) async {
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final history = MedicalHistory.fromApiJson({
      ..._visit,
      'patient_id': 'p-1',
      'patient': {'id': 'p-1', 'name': 'Siti Aminah'},
      'notes': '[Doctor - 2026-10-22 09:50]: Gigi geraham berlubang',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripDoctorsProvider.overrideWith(
            (ref) async => const [
              Doctor(id: 'mp-a', nama: 'dr. A', spesialisasi: '', online: true),
              Doctor(id: 'mp-b', nama: 'dr. B', spesialisasi: '', online: true),
              Doctor(id: 'mp-c', nama: 'dr. C', spesialisasi: 'Gigi', online: true),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ExaminationInputModal(patient: history.toPatient(), history: history),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dirujuk dari dr. A'), findsOneWidget);
    expect(find.text('Alasan rujukan: Perlu spesialis'), findsOneWidget);
    expect(
      find.text('Hasil pemeriksaan sebelumnya: Gigi geraham berlubang'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ya, Perlu Rujukan Lab'));
    await tester.pump();
    // "Perlu Rujukan" as the condition opens the referral form.
    expect(find.text('Rujuk ke Dokter Lain'), findsNothing);
    await tester.tap(find.text('Baik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perlu Rujukan').last);
    await tester.pumpAndSettle();
    expect(find.text('Rujuk ke Dokter Lain'), findsOneWidget);
    // The doctor can still examine and diagnose first: the exam form stays
    // (optional for a referral), with no toggle to hide it.
    expect(find.text('Simpan & Rujuk ke Dokter'), findsOneWidget);
    expect(find.text('Perlu Resep Obat?'), findsOneWidget);
    expect(find.text('Sembunyikan Form Pemeriksaan'), findsNothing);
    // The lab ordered earlier stays: the patient sees the lab first, then the
    // referred doctor.
    expect(find.text('Perlu Pemeriksaan Laboratorium?'), findsOneWidget);
    expect(
      find.textContaining('Hasil lab dikirim ke dokter tujuan rujukan.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Pasien diperiksa lab dulu'),
      findsOneWidget,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('dr. A'), findsWidgets);
    expect(find.text('dr. C — Gigi'), findsWidgets);
    // The visit's own doctor isn't offered.
    expect(find.text('dr. B'), findsNothing);

    // Let the ICD cache warm-up the modal starts finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets("the signed-in doctor isn't in the referral list", (tester) async {
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final history = MedicalHistory.fromApiJson({
      ..._visit,
      'patient_id': 'p-1',
      'patient': {'id': 'p-1', 'name': 'Siti Aminah'},
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => _FakeAuthController(
              const AppUser(
                id: 'u-c',
                name: 'dr. C',
                email: 'c@example.com',
                role: UserRole.dokter,
              ),
            ),
          ),
          tripDoctorsProvider.overrideWith(
            (ref) async => const [
              Doctor(id: 'mp-a', nama: 'dr. A', spesialisasi: '', online: true, userId: 'u-a'),
              Doctor(id: 'mp-b', nama: 'dr. B', spesialisasi: '', online: true, userId: 'u-b'),
              Doctor(id: 'mp-c', nama: 'dr. C', spesialisasi: 'Gigi', online: true, userId: 'u-c'),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ExaminationInputModal(patient: history.toPatient(), history: history),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Baik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perlu Rujukan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('dr. A'), findsWidgets);
    // Not themselves, nor the visit's own doctor.
    expect(find.text('dr. C — Gigi'), findsNothing);
    expect(find.text('dr. B'), findsNothing);

    // Let the ICD cache warm-up the modal starts finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
