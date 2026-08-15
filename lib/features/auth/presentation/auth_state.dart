import 'package:equatable/equatable.dart';

import '../domain/app_user.dart';

enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState._({required this.status, this.session, this.errorMessage});

  const AuthState.unknown() : this._(status: AuthStatus.unknown);
  const AuthState.authenticating() : this._(status: AuthStatus.authenticating);
  const AuthState.authenticated(AuthSession session) : this._(status: AuthStatus.authenticated, session: session);
  const AuthState.unauthenticated({String? errorMessage})
      : this._(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated && session != null;

  @override
  List<Object?> get props => [status, session, errorMessage];
}
