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

  /// Unique event identifier.
  final String id;

  /// Application-defined change type.
  final String type;

  /// JSON-compatible change payload.
  final Map<String, dynamic> payload;

  /// Creation time of the local change.
  final DateTime createdAt;
}

/// Cursor identifying the last successfully pulled cloud change.
class EdgeSyncCursor {
  /// Creates a cursor; null means the beginning of a remote stream.
  const EdgeSyncCursor([this.value]);

  /// Adapter-specific cursor value.
  final String? value;
}

/// Result returned after a sync push operation.
class SyncResult {
  const SyncResult({required this.accepted, this.cursor});

  /// Number of events accepted by the remote adapter.
  final int accepted;

  /// Cursor to use for the next pull operation.
  final EdgeSyncCursor? cursor;
}

/// Adapter contract for optional cloud synchronization.
abstract interface class PocketEdgeCloudAdapter {
  /// Checks whether the remote service is reachable.
  Future<bool> ping();

  /// Pushes local events to the remote service.
  Future<SyncResult> push(List<EdgeSyncEvent> events);

  /// Pulls remote events after [cursor].
  Future<List<EdgeSyncEvent>> pull(EdgeSyncCursor cursor);
}

/// Flushes pending in-memory queue entries when the adapter is online.
class SyncCoordinator {
  /// Coordinates an [OfflineQueue] with a cloud [adapter].
  SyncCoordinator(this.queue, this.adapter);

  /// Queue providing local-first durability.
  final OfflineQueue queue;

  /// Remote synchronization adapter.
  final PocketEdgeCloudAdapter adapter;

  /// Cursor retained between synchronization operations.
  EdgeSyncCursor cursor = const EdgeSyncCursor();

  /// Adds a local operation to the queue.
  Future<EdgeQueueEntry> enqueue(
    String type,
    Map<String, dynamic> payload,
  ) async =>
      queue.enqueue(type, payload);

  /// Pushes pending entries when the adapter is reachable.
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
