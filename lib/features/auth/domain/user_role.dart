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
  switch (normalized) {
    case 'perawat':
    case 'nurse':
      return UserRole.perawat;
    case 'dokter':
    case 'doctor':
    case 'dr':
      return UserRole.dokter;
    case 'pharmacy':
    case 'apoteker':
    case 'apotek':
    case 'farmasi':
      return UserRole.pharmacy;
    case 'lab':
    case 'laboratorium':
    case 'analyst':
      return UserRole.lab;
    case 'admin kapal':
    case 'adminkapal':
    case 'admin':
    case 'ship admin':
    case 'administrator':
      return UserRole.adminKapal;
    default:
      for (final role in UserRole.values) {
        if (role.name.toLowerCase() == normalized ||
            role.apiValue.toLowerCase() == normalized ||
            role.label.toLowerCase() == normalized) {
          return role;
        }
      }
      return null;
  }
}
