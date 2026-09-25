// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'cloud_adapter.dart';
import 'offline_queue.dart';
import 'sqlite_queue_stub.dart';

class SqliteSyncCoordinator {
  SqliteSyncCoordinator(
      SqliteOfflineQueue queue, PocketEdgeCloudAdapter adapter) {
    throw UnsupportedError('SQLite sync is unavailable on web.');
  }

  Future<EdgeQueueEntry> enqueue(String type, Map<String, dynamic> payload) =>
      throw UnsupportedError('SQLite sync is unavailable on web.');

  Future<SyncResult?> flush() =>
      throw UnsupportedError('SQLite sync is unavailable on web.');
}
