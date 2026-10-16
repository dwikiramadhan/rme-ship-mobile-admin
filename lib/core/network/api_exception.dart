/// Uniform error surfaced by the network layer to the UI — a message that's
/// already safe/sensible to show a user, distinguished from other failures
/// only where the UI needs to branch (e.g. invalid credentials).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.isOffline = false});

  final String message;
  final int? statusCode;

  /// The request never reached the server (no connection, DNS/TLS failure,
  /// connect timeout), so it is safe to queue it and send it again later.
  final bool isOffline;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
