// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../core/types.dart';

/// A short-lived, single-use token used to bootstrap a session.
class PairingToken {
  PairingToken._(this.value, this.expiresAt, this.role);

  /// Temporary secret sent to the joining device.
  final String value;

  /// Time after which this token cannot be consumed.
  final DateTime expiresAt;

  /// Role assigned to the resulting session.
  final String role;

  /// Whether this token has expired.
  bool get expired => DateTime.now().isAfter(expiresAt);
}

/// Issues and consumes temporary pairing tokens.
class PairingManager {
  /// Creates a manager with a [ttl] for issued pairing tokens.
  PairingManager({this.ttl = const Duration(minutes: 5)});

  /// Lifetime applied to new pairing tokens.
  final Duration ttl;
  PairingToken? _active;

  /// Issues a new single-use token for [role].
  PairingToken issue({String role = 'guest'}) {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final token = PairingToken._(
      base64UrlEncode(bytes),
      DateTime.now().add(ttl),
      role,
    );
    _active = token;
    return token;
  }

  /// Consumes [value], returning false if it is invalid or already used.
  bool consume(String value) {
    final token = _active;
    if (token == null || token.expired || token.value != value) return false;
    _active = null;
    return true;
  }

  /// Validates and consumes [value], throwing on failure.
  void requireValid(String value) {
    requireToken(value);
  }

  /// Returns and consumes a valid token, or throws [PairingRejectedException].
  PairingToken requireToken(String value) {
    final token = _active;
    if (token == null || token.expired || token.value != value) {
      throw const PairingRejectedException(
        'Pairing token is invalid, expired, or already used.',
      );
    }
    _active = null;
    return token;
  }

  /// Returns a SHA-256 digest suitable for audit or comparison purposes.
  String digest(String value) => sha256.convert(utf8.encode(value)).toString();
}

/// In-memory session manager for temporary local rooms.
class SessionManager {
  /// Creates an in-memory session manager with the given session [ttl].
  SessionManager({this.ttl = const Duration(hours: 1)});

  /// Lifetime applied to newly issued sessions.
  final Duration ttl;
  final Map<String, EdgeSession> _sessions = {};

  /// Issues a session for [deviceId] with the requested [role].
  EdgeSession issue({required String deviceId, String role = 'guest'}) {
    final now = DateTime.now();
    final session = EdgeSession(
      token: _randomToken(),
      sessionId: 's_${_randomToken(length: 8)}',
      deviceId: deviceId,
      role: role,
      issuedAt: now,
      expiresAt: now.add(ttl),
    );
    _sessions[session.token] = session;
    return session;
  }

  /// Resolves a token, removing and returning null for expired sessions.
  EdgeSession? resolve(String token) {
    final session = _sessions[token];
    if (session == null) return null;
    if (session.expired) {
      _sessions.remove(token);
      return null;
    }
    return session;
  }

  /// Revokes [token] immediately.
  void revoke(String token) => _sessions.remove(token);
  static String _randomToken({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
