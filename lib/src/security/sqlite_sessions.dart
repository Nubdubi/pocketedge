// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../core/types.dart';

class SqliteSessionManager {
  SqliteSessionManager(String path, {this.ttl = const Duration(hours: 1)})
      : _database = sqlite3.open(path) {
    _database.execute(
      'CREATE TABLE IF NOT EXISTS edge_sessions (token TEXT PRIMARY KEY, session_id TEXT NOT NULL, device_id TEXT NOT NULL, role TEXT NOT NULL, issued_at TEXT NOT NULL, expires_at TEXT NOT NULL)',
    );
  }
  final Database _database;
  final Duration ttl;

  Future<EdgeSession> issue({
    required String deviceId,
    String role = 'guest',
  }) async {
    final now = DateTime.now().toUtc();
    final session = EdgeSession(
      token: _token(),
      sessionId: 's_${_token(length: 8)}',
      deviceId: deviceId,
      role: role,
      issuedAt: now,
      expiresAt: now.add(ttl),
    );
    _database.execute(
      'INSERT INTO edge_sessions (token, session_id, device_id, role, issued_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)',
      [
        session.token,
        session.sessionId,
        session.deviceId,
        session.role,
        session.issuedAt.toIso8601String(),
        session.expiresAt.toIso8601String(),
      ],
    );
    return session;
  }

  Future<EdgeSession?> resolve(String token) async {
    final rows = _database.select(
      'SELECT * FROM edge_sessions WHERE token = ?',
      [token],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final session = EdgeSession(
      token: row['token'] as String,
      sessionId: row['session_id'] as String,
      deviceId: row['device_id'] as String,
      role: row['role'] as String,
      issuedAt: DateTime.parse(row['issued_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
    if (session.expired) {
      await revoke(token);
      return null;
    }
    return session;
  }

  Future<void> revoke(String token) async =>
      _database.execute('DELETE FROM edge_sessions WHERE token = ?', [token]);
  void close() => _database.dispose();
  static String _token({int length = 32}) {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
