/// Uniform error surfaced by the network layer to the UI — a message that's
/// already safe/sensible to show a user, distinguished from other failures
/// only where the UI needs to branch (e.g. invalid credentials).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
