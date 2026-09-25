// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'offline_queue.dart';

class SqliteOfflineQueue {
  SqliteOfflineQueue(String path) : _database = sqlite3.open(path) {
    _database.execute(
      'CREATE TABLE IF NOT EXISTS edge_queue (id TEXT PRIMARY KEY, type TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, state TEXT NOT NULL)',
    );
  }
  final Database _database;

  Future<EdgeQueueEntry> enqueue(
    String type,
    Map<String, dynamic> payload,
  ) async {
    final entry = EdgeQueueEntry(
      id: 'queue_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      payload: payload,
    );
    _database.execute(
      'INSERT INTO edge_queue (id, type, payload, created_at, attempts, state) VALUES (?, ?, ?, ?, ?, ?)',
      [
        entry.id,
        entry.type,
        jsonEncode(entry.payload),
        entry.createdAt.toIso8601String(),
        entry.attempts,
        entry.state.name,
      ],
    );
    return entry;
  }

  Future<List<EdgeQueueEntry>> pending() async {
    final rows = _database.select(
      "SELECT * FROM edge_queue WHERE state = 'pending' ORDER BY created_at ASC",
    );
    return rows.map(_entry).toList();
  }

  Future<void> markSending(String id) async =>
      _update(id, QueueState.sending, incrementAttempts: true);
  Future<void> markSent(String id) async => _update(id, QueueState.sent);
  Future<void> markFailed(String id) async => _update(id, QueueState.failed);

  Future<void> _update(
    String id,
    QueueState state, {
    bool incrementAttempts = false,
  }) async {
    _database.execute(
      'UPDATE edge_queue SET state = ?, attempts = attempts + ? WHERE id = ?',
      [state.name, incrementAttempts ? 1 : 0, id],
    );
  }

  EdgeQueueEntry _entry(Row row) {
    final entry = EdgeQueueEntry(
      id: row['id'] as String,
      type: row['type'] as String,
      payload: Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String) as Map,
      ),
    );
    entry.attempts = row['attempts'] as int;
    entry.state = QueueState.values.byName(row['state'] as String);
    return entry;
  }

  void close() => _database.dispose();
}
