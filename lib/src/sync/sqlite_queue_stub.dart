// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'offline_queue.dart';

class SqliteOfflineQueue {
  SqliteOfflineQueue(String path) {
    throw UnsupportedError('SQLite queues are unavailable on web.');
  }

  Future<EdgeQueueEntry> enqueue(
    String type,
    Map<String, dynamic> payload,
  ) =>
      throw UnsupportedError('SQLite queues are unavailable on web.');

  Future<List<EdgeQueueEntry>> pending() =>
      throw UnsupportedError('SQLite queues are unavailable on web.');

  Future<void> markSending(String id) =>
      throw UnsupportedError('SQLite queues are unavailable on web.');
  Future<void> markSent(String id) =>
      throw UnsupportedError('SQLite queues are unavailable on web.');
  Future<void> markFailed(String id) =>
      throw UnsupportedError('SQLite queues are unavailable on web.');

  void close() {}
}
