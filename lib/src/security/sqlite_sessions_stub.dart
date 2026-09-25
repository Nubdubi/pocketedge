// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import '../core/types.dart';

class SqliteSessionManager {
  SqliteSessionManager(String path, {this.ttl = const Duration(hours: 1)}) {
    throw UnsupportedError('SQLite sessions are unavailable on web.');
  }

  final Duration ttl;

  Future<EdgeSession> issue(
          {required String deviceId, String role = 'guest'}) =>
      throw UnsupportedError('SQLite sessions are unavailable on web.');

  Future<EdgeSession?> resolve(String token) =>
      throw UnsupportedError('SQLite sessions are unavailable on web.');

  Future<void> revoke(String token) =>
      throw UnsupportedError('SQLite sessions are unavailable on web.');

  void close() {}
}
