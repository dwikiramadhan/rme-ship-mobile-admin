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
    case 'nursing':
      return UserRole.perawat;
    case 'dokter':
    case 'doctor':
    case 'dr':
    case 'physician':
    case 'general practitioner':
    case 'gp':
      return UserRole.dokter;
    case 'pharmacist':
    case 'pharmacy':
    case 'apoteker':
    case 'apotek':
    case 'farmasi':
      return UserRole.pharmacy;
    case 'lab':
    case 'laboratorium':
    case 'laboratory':
    case 'analyst':
    case 'lab analyst':
    case 'laboran':
      return UserRole.lab;
    case 'admin kapal':
    case 'adminkapal':
    case 'admin':
    case 'ship admin':
    case 'shipadmin':
    case 'administrator':
    case 'superadmin':
      return UserRole.adminKapal;
    default:
      if (normalized.contains('pharm') || normalized.contains('apotek') || normalized.contains('farmasi')) {
        return UserRole.pharmacy;
      }
      if (normalized.contains('dok') || normalized.contains('doc')) {
        return UserRole.dokter;
      }
      if (normalized.contains('perawat') || normalized.contains('nurs')) {
        return UserRole.perawat;
      }
      if (normalized.contains('lab')) {
        return UserRole.lab;
      }
      if (normalized.contains('admin')) {
        return UserRole.adminKapal;
      }
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
