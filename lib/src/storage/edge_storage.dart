// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
abstract interface class EdgeStorage {
  Future<void> put(String collection, String id, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> get(String collection, String id);
  Future<void> delete(String collection, String id);
}

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
