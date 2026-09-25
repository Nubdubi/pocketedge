// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
import '../core/types.dart';

/// Maps session roles to permissions for protected routes.
class EdgeAuthorization {
  /// Creates role permissions, optionally replacing the defaults.
  EdgeAuthorization({Map<String, Set<String>>? permissions})
      : _permissions = permissions ??
            {
              'guest': <String>{},
              'staff': {'room.read', 'room.write', 'files.read', 'files.write'},
              'manager': {
                'room.read',
                'room.write',
                'files.read',
                'files.write',
                'diagnostics.read',
                'inventory.read',
                'inventory.write',
              },
              'admin': {'*'},
            };
  final Map<String, Set<String>> _permissions;

  /// Returns whether [session] has [permission].
  bool allows(EdgeSession session, String permission) {
    final granted = _permissions[session.role] ?? const <String>{};
    return granted.contains('*') || granted.contains(permission);
  }

  /// Requires [session] to have [permission], otherwise throws.
  void require(EdgeSession session, String permission) {
    if (!allows(session, permission)) {
      throw const AuthorizationException(
        'The session does not have this permission.',
      );
    }
  }
}

class AuthorizationException implements Exception {
  /// Creates an authorization failure with [message].
  const AuthorizationException(this.message);

  /// Human-readable authorization failure.
  final String message;
}
