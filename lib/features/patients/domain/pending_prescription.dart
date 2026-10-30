/// A prescription given together with a lab referral goes to the pharmacy
/// right away, without waiting for the lab results. So part of a visit's
/// prescription may already be dispensed, and the pharmacy queue isn't only
/// the visits at "Menunggu Obat".
library;

/// The visit statuses of the doctor–lab–pharmacy flow. "Diperiksa" and
/// "Selesai" visits never wait for the pharmacy.
const _pharmacyFlow = {'Menunggu Obat', 'Menunggu Lab', 'Menunggu Dokter'};

/// Whether a visit at [statusPenanganan] can still have medicine to dispense.
bool inPharmacyFlow(String? statusPenanganan) =>
    _pharmacyFlow.contains(statusPenanganan?.trim());

/// A prescription line (API JSON) the pharmacy already dispensed.
bool isDispensedPrescription(Map<dynamic, dynamic> prescription) {
  final dispenses = prescription['dispenses'];
  return dispenses is List && dispenses.isNotEmpty;
}

/// The examining doctor (logged in as [userId]) can still change the exam
/// while the pharmacy hasn't dispensed anything: their "Menunggu Obat" visit
/// (API JSON) with no dispensed medicine. Same rule as the backend.
bool canEditExam(Map<String, dynamic> record, String userId) {
  if (userId.isEmpty) return false;
  final doctor = record['doctor'];
  if (doctor is! Map || doctor['user_id']?.toString() != userId) return false;
  if ('${record['status_penanganan'] ?? ''}'.trim() != 'Menunggu Obat') {
    return false;
  }
  final prescriptions = record['prescriptions'];
  return prescriptions is! List ||
      !prescriptions.whereType<Map>().any(isDispensedPrescription);
}

/// Whether the visit (API JSON) still has medicine the pharmacy hasn't
/// dispensed. Uses the backend's `prescription_pending`; works it out from
/// the prescriptions when it's missing (older backend, offline data).
bool hasPendingPrescription(Map<String, dynamic> record) {
  final flag = record['prescription_pending'];
  if (flag is bool) return flag;
  if (!inPharmacyFlow(record['status_penanganan']?.toString())) return false;
  final prescriptions = record['prescriptions'];
  return prescriptions is List &&
      prescriptions.whereType<Map>().any((p) => !isDispensedPrescription(p));
}

/// The pharmacy's "Menunggu Obat" queue also lists the visits with medicine
/// still to dispense (`include_pending_prescriptions=true`).
bool includesPharmacyQueue(String? statusPenanganan) =>
    (statusPenanganan ?? '').contains('Menunggu Obat');
