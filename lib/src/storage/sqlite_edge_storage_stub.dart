// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'edge_storage.dart';

class SqliteEdgeStorage implements EdgeStorage {
  SqliteEdgeStorage(String path) {
    throw UnsupportedError('SQLite storage is unavailable on web.');
  }

  @override
  Future<void> put(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) =>
      throw UnsupportedError('SQLite storage is unavailable on web.');

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) =>
      throw UnsupportedError('SQLite storage is unavailable on web.');

  @override
  Future<void> delete(String collection, String id) =>
      throw UnsupportedError('SQLite storage is unavailable on web.');

  void close() {}
}
