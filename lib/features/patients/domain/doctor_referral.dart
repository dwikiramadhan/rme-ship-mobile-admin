/// A doctor referring the patient to another doctor on the ship's ongoing
/// trip. The other doctor becomes the visit's doctor (back to "Menunggu
/// Dokter"); the referring doctor can still see the visit in their history.
library;

import 'doctor.dart';

/// One referral in a visit's `referrals`, oldest first.
class DoctorReferral {
  const DoctorReferral({
    required this.fromName,
    required this.toName,
    required this.reason,
    this.createdAt,
  });

  final String fromName;
  final String toName;
  final String reason;
  final DateTime? createdAt;

  factory DoctorReferral.fromJson(Map<String, dynamic> json) {
    String name(dynamic doctor) =>
        doctor is Map && '${doctor['name'] ?? ''}'.trim().isNotEmpty
        ? '${doctor['name']}'.trim()
        : 'Dokter';
    return DoctorReferral(
      fromName: name(json['from_doctor']),
      toName: name(json['to_doctor']),
      reason: '${json['reason'] ?? ''}'.trim(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}

/// The referrals of a visit (its raw `/medical-history` JSON).
List<DoctorReferral> referralsOf(Map<String, dynamic> raw) => [
  if (raw['referrals'] is List)
    for (final r in raw['referrals'] as List)
      if (r is Map) DoctorReferral.fromJson(Map<String, dynamic>.from(r)),
];

/// The visit was referred away by the doctor logged in as [userId]: they
/// only see it now, they don't examine it again.
bool isReferredAway(Map<String, dynamic> raw, String userId) {
  if (userId.isEmpty) return false;
  final doctor = raw['doctor'];
  if (doctor is Map && doctor['user_id']?.toString() == userId) return false;
  final referrals = raw['referrals'];
  if (referrals is! List) return false;
  return referrals.any(
    (r) =>
        r is Map &&
        r['from_doctor'] is Map &&
        (r['from_doctor'] as Map)['user_id']?.toString() == userId,
  );
}

/// The doctors a visit can be referred to: the trip's doctors but the
/// visit's own doctor and the signed-in doctor ([userId]).
List<Doctor> referralCandidates(
  List<Doctor> tripDoctors,
  String? doctorId, {
  String? userId,
}) => [
  for (final d in tripDoctors)
    if (d.id != doctorId && ((userId ?? '').isEmpty || d.userId != userId)) d,
];

/// `referral` payload for PATCH /patients/:id/medical-records/:recordId.
Map<String, dynamic> referralRequestJson({
  required String toDoctorId,
  required String reason,
}) => {'to_doctor_id': toDoctorId, 'reason': reason.trim()};
