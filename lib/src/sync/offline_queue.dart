// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
/// Lifecycle state of an offline queue entry.
enum QueueState { pending, sending, sent, failed, expired }

/// A queued operation waiting for local or cloud processing.
class EdgeQueueEntry {
  EdgeQueueEntry({required this.id, required this.type, required this.payload})
      : createdAt = DateTime.now();
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int attempts = 0;
  QueueState state = QueueState.pending;
}

/// In-memory offline queue available on every supported platform.
class OfflineQueue {
  final List<EdgeQueueEntry> _entries = [];
  List<EdgeQueueEntry> get pending => List.unmodifiable(
        _entries.where((entry) => entry.state == QueueState.pending),
      );

  /// Adds a new pending operation to the queue.
  EdgeQueueEntry enqueue(String type, Map<String, dynamic> payload) {
    final entry = EdgeQueueEntry(
      id: 'queue_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      payload: payload,
    );
    _entries.add(entry);
    return entry;
  }

  void markSending(EdgeQueueEntry entry) {
    entry.state = QueueState.sending;
    entry.attempts++;
  }

  void markSent(EdgeQueueEntry entry) => entry.state = QueueState.sent;
  void markFailed(EdgeQueueEntry entry) => entry.state = QueueState.failed;
}
