import '../../patients/domain/lab_order.dart';
import '../../patients/domain/patient.dart';

/// Which visits notify whom, from the visit's backend status
/// ([Patient.statusPenanganan]). Each notification is one visit.

/// The doctor's visit is back from the lab with results.
bool isLabResultForDoctor(Patient p) =>
    p.statusPenanganan == 'Menunggu Dokter' &&
    p.labOrder?.status == LabOrderStatus.selesai;

/// A visit waiting for the doctor's examination.
bool isWaitingForDoctor(Patient p) =>
    p.statusPenanganan == 'Menunggu Dokter' && !isLabResultForDoctor(p);

bool isWaitingForPharmacy(Patient p) => p.statusPenanganan == 'Menunggu Obat';

bool isWaitingForLab(Patient p) => p.statusPenanganan == 'Menunggu Lab';

/// Read marks are kept per visit, so a patient's next visit notifies again.
String notificationKey(Patient p) => p.medicalRecordId ?? p.id;
