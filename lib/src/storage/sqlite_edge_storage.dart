// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../core/types.dart';
import 'edge_storage.dart';

class SqliteEdgeStorage implements EdgeStorage {
  SqliteEdgeStorage(String path) : _database = sqlite3.open(path) {
    _database.execute(
      'CREATE TABLE IF NOT EXISTS edge_records (collection TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY (collection, id))',
    );
  }
  final Database _database;

  @override
  Future<void> put(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      _database.execute(
        'INSERT OR REPLACE INTO edge_records (collection, id, data) VALUES (?, ?, ?)',
        [collection, id, jsonEncode(data)],
      );
    } catch (error) {
      throw StorageException('Could not write $collection/$id: $error');
    }
  }

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    try {
      final rows = _database.select(
        'SELECT data FROM edge_records WHERE collection = ? AND id = ?',
        [collection, id],
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(
        jsonDecode(rows.first['data'] as String) as Map,
      );
    } catch (error) {
      throw StorageException('Could not read $collection/$id: $error');
    }
  }

  @override
  Future<void> delete(String collection, String id) async {
    try {
      _database.execute(
        'DELETE FROM edge_records WHERE collection = ? AND id = ?',
        [collection, id],
      );
    } catch (error) {
      throw StorageException('Could not delete $collection/$id: $error');
    }
  }

  void close() => _database.dispose();
}
