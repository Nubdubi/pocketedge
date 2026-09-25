// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'offline_queue.dart';

/// A local change sent to a cloud synchronization adapter.
class EdgeSyncEvent {
  const EdgeSyncEvent({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
}

/// Cursor identifying the last successfully pulled cloud change.
class EdgeSyncCursor {
  const EdgeSyncCursor([this.value]);
  final String? value;
}

/// Result returned after a sync push operation.
class SyncResult {
  const SyncResult({required this.accepted, this.cursor});
  final int accepted;
  final EdgeSyncCursor? cursor;
}

/// Adapter contract for optional cloud synchronization.
abstract interface class PocketEdgeCloudAdapter {
  Future<bool> ping();
  Future<SyncResult> push(List<EdgeSyncEvent> events);
  Future<List<EdgeSyncEvent>> pull(EdgeSyncCursor cursor);
}

/// Flushes pending in-memory queue entries when the adapter is online.
class SyncCoordinator {
  SyncCoordinator(this.queue, this.adapter);
  final OfflineQueue queue;
  final PocketEdgeCloudAdapter adapter;
  EdgeSyncCursor cursor = const EdgeSyncCursor();

  Future<EdgeQueueEntry> enqueue(
    String type,
    Map<String, dynamic> payload,
  ) async =>
      queue.enqueue(type, payload);

  Future<SyncResult?> flush() async {
    if (!await adapter.ping()) return null;
    final entries = queue.pending.toList();
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
      queue.markSending(entry);
    }
    try {
      final result = await adapter.push(events);
      for (final entry in entries.take(result.accepted)) {
        queue.markSent(entry);
      }
      cursor = result.cursor ?? cursor;
      return result;
    } catch (_) {
      for (final entry in entries) {
        queue.markFailed(entry);
      }
      rethrow;
    }
  }
}
