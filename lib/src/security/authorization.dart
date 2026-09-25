// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
import '../core/types.dart';

/// Maps session roles to permissions for protected routes.
class EdgeAuthorization {
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
  bool allows(EdgeSession session, String permission) {
    final granted = _permissions[session.role] ?? const <String>{};
    return granted.contains('*') || granted.contains(permission);
  }

  void require(EdgeSession session, String permission) {
    if (!allows(session, permission)) {
      throw const AuthorizationException(
        'The session does not have this permission.',
      );
    }
  }
}

class AuthorizationException implements Exception {
  const AuthorizationException(this.message);
  final String message;
}
