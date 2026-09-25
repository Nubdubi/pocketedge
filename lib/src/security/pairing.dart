// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../core/types.dart';

/// A short-lived, single-use token used to bootstrap a session.
class PairingToken {
  PairingToken._(this.value, this.expiresAt, this.role);
  final String value;
  final DateTime expiresAt;
  final String role;
  bool get expired => DateTime.now().isAfter(expiresAt);
}

/// Issues and consumes temporary pairing tokens.
class PairingManager {
  PairingManager({this.ttl = const Duration(minutes: 5)});
  final Duration ttl;
  PairingToken? _active;
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

  bool consume(String value) {
    final token = _active;
    if (token == null || token.expired || token.value != value) return false;
    _active = null;
    return true;
  }

  void requireValid(String value) {
    requireToken(value);
  }

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

  String digest(String value) => sha256.convert(utf8.encode(value)).toString();
}

/// In-memory session manager for temporary local rooms.
class SessionManager {
  SessionManager({this.ttl = const Duration(hours: 1)});
  final Duration ttl;
  final Map<String, EdgeSession> _sessions = {};
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

  EdgeSession? resolve(String token) {
    final session = _sessions[token];
    if (session == null) return null;
    if (session.expired) {
      _sessions.remove(token);
      return null;
    }
    return session;
  }

  void revoke(String token) => _sessions.remove(token);
  static String _randomToken({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
