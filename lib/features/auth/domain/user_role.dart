/// The 4 clinical roles from the prototype. Values match the backend's role
/// strings exactly (perawat/dokter/pharmacy/lab), confirmed against the API spec.
enum UserRole { perawat, dokter, pharmacy, lab, adminKapal }

extension UserRoleApiValue on UserRole {
  String get apiValue => switch (this) {
        UserRole.perawat => 'perawat',
        UserRole.dokter => 'dokter',
        UserRole.pharmacy => 'pharmacy',
        UserRole.lab => 'lab',
        UserRole.adminKapal => 'admin_kapal',
      };

  String get label => switch (this) {
        UserRole.perawat => 'Perawat',
        UserRole.dokter => 'Dokter',
        UserRole.pharmacy => 'Apotek',
        UserRole.lab => 'Laboratorium',
        UserRole.adminKapal => 'Admin Kapal',
      };
}

UserRole? userRoleFromApiValue(String? value) {
  if (value == null) return null;
  final normalized = value.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
  return switch (normalized) {
    'perawat' || 'nurse' || 'nursing' => UserRole.perawat,
    'dokter' || 'doctor' || 'dr' || 'physician' || 'general practitioner' || 'gp' => UserRole.dokter,
    'pharmacist' || 'pharmacy' || 'apoteker' || 'apotek' || 'farmasi' => UserRole.pharmacy,
    'lab' || 'laboratorium' || 'laboratory' || 'analyst' || 'lab analyst' || 'laboran' => UserRole.lab,
    'admin kapal' ||
    'adminkapal' ||
    'admin' ||
    'ship admin' ||
    'shipadmin' ||
    'administrator' ||
    'superadmin' =>
      UserRole.adminKapal,
    _ when normalized.contains('pharm') || normalized.contains('apotek') || normalized.contains('farmasi') =>
      UserRole.pharmacy,
    _ when normalized.contains('dok') || normalized.contains('doc') => UserRole.dokter,
    _ when normalized.contains('perawat') || normalized.contains('nurs') => UserRole.perawat,
    _ when normalized.contains('lab') => UserRole.lab,
    _ when normalized.contains('admin') => UserRole.adminKapal,
    _ => UserRole.values.cast<UserRole?>().firstWhere(
          (role) =>
              role!.name.toLowerCase() == normalized ||
              role.apiValue.toLowerCase() == normalized ||
              role.label.toLowerCase() == normalized,
          orElse: () => null,
        ),
  };
}
