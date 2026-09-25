// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
/// Lifecycle state of an offline queue entry.
enum QueueState { pending, sending, sent, failed, expired }

/// A queued operation waiting for local or cloud processing.
class EdgeQueueEntry {
  /// Creates a queue entry with a pending state and current timestamp.
  EdgeQueueEntry({required this.id, required this.type, required this.payload})
      : createdAt = DateTime.now();

  /// Unique local queue identifier.
  final String id;

  /// Application-defined operation type.
  final String type;

  /// JSON-compatible operation payload.
  final Map<String, dynamic> payload;

  /// Time when this entry was created.
  final DateTime createdAt;

  /// Number of send attempts made for this entry.
  int attempts = 0;

  /// Current lifecycle state.
  QueueState state = QueueState.pending;
}

/// In-memory offline queue available on every supported platform.
class OfflineQueue {
  final List<EdgeQueueEntry> _entries = [];

  /// Pending entries that have not yet been sent.
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

  /// Marks [entry] as being sent and increments its attempt count.
  void markSending(EdgeQueueEntry entry) {
    entry.state = QueueState.sending;
    entry.attempts++;
  }

  /// Marks [entry] as successfully sent.
  void markSent(EdgeQueueEntry entry) => entry.state = QueueState.sent;

  /// Marks [entry] as failed so an application can retry or inspect it.
  void markFailed(EdgeQueueEntry entry) => entry.state = QueueState.failed;
}
