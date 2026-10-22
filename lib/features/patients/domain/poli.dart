/// Poli Umum needs no assigned doctor: every doctor on the ongoing trip is
/// told, and the first one to examine the patient becomes their doctor.
const String poliUmumCode = 'UMUM';

bool isPoliUmum(String? code) => code?.trim().toUpperCase() == poliUmumCode;
