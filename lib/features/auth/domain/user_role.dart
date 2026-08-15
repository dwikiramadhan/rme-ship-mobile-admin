/// The 4 clinical roles from the prototype. Values match the backend's role
/// strings exactly (perawat/dokter/pharmacy/lab), confirmed against the API spec.
enum UserRole { perawat, dokter, pharmacy, lab }

extension UserRoleApiValue on UserRole {
  String get apiValue => switch (this) {
        UserRole.perawat => 'perawat',
        UserRole.dokter => 'dokter',
        UserRole.pharmacy => 'pharmacy',
        UserRole.lab => 'lab',
      };

  String get label => switch (this) {
        UserRole.perawat => 'Perawat',
        UserRole.dokter => 'Dokter',
        UserRole.pharmacy => 'Apotek',
        UserRole.lab => 'Laboratorium',
      };
}

UserRole? userRoleFromApiValue(String? value) {
  for (final role in UserRole.values) {
    if (role.apiValue == value) return role;
  }
  return null;
}
