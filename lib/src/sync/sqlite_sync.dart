// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'cloud_adapter.dart';
import 'offline_queue.dart';
import 'sqlite_queue.dart';

class SqliteSyncCoordinator {
  SqliteSyncCoordinator(this.queue, this.adapter);
  final SqliteOfflineQueue queue;
  final PocketEdgeCloudAdapter adapter;
  EdgeSyncCursor cursor = const EdgeSyncCursor();

  Future<EdgeQueueEntry> enqueue(String type, Map<String, dynamic> payload) =>
      queue.enqueue(type, payload);

  Future<SyncResult?> flush() async {
    if (!await adapter.ping()) return null;
    final entries = await queue.pending();
    if (entries.isEmpty) return const SyncResult(accepted: 0);
    final events = entries
        .map(
          (entry) => EdgeSyncEvent(
            id: entry.id,
            type: entry.type,
            payload: entry.payload,
            createdAt: entry.createdAt,
          ),
        )
        .toList();
    for (final entry in entries) {
      await queue.markSending(entry.id);
    }
    try {
      final result = await adapter.push(events);
      for (final entry in entries.take(result.accepted)) {
        await queue.markSent(entry.id);
      }
      cursor = result.cursor ?? cursor;
      return result;
    } catch (_) {
      for (final entry in entries) {
        await queue.markFailed(entry.id);
      }
      rethrow;
    }
  }
}
