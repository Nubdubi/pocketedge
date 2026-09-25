// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
/// Minimal asynchronous key-value storage used by PocketEdge applications.
abstract interface class EdgeStorage {
  /// Stores [data] under a collection and record [id].
  Future<void> put(String collection, String id, Map<String, dynamic> data);

  /// Reads a record, or returns null when it does not exist.
  Future<Map<String, dynamic>?> get(String collection, String id);

  /// Deletes a record if it exists.
  Future<void> delete(String collection, String id);
}

/// In-memory storage suitable for tests and Web clients.
class MemoryEdgeStorage implements EdgeStorage {
  final Map<String, Map<String, Map<String, dynamic>>> _data = {};
  @override
  Future<void> put(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async =>
      (_data[collection] ??= {})[id] = Map<String, dynamic>.from(data);
  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final value = _data[collection]?[id];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<void> delete(String collection, String id) async =>
      _data[collection]?.remove(id);
}
