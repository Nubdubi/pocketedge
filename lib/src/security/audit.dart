// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
class EdgeAuditEvent {
  const EdgeAuditEvent({
    required this.type,
    required this.time,
    this.subject,
    this.data = const {},
  });
  final String type;
  final DateTime time;
  final String? subject;
  final Map<String, dynamic> data;
  Map<String, dynamic> toJson() => {
        'type': type,
        'time': time.toIso8601String(),
        if (subject != null) 'subject': subject,
        'data': data,
      };
}

class EdgeAuditLog {
  EdgeAuditLog({this.maxEntries = 1000});
  final int maxEntries;
  final List<EdgeAuditEvent> _events = [];
  List<EdgeAuditEvent> get events => List.unmodifiable(_events);
  void record(
    String type, {
    String? subject,
    Map<String, dynamic> data = const {},
  }) {
    _events.add(
      EdgeAuditEvent(
        type: type,
        time: DateTime.now().toUtc(),
        subject: subject,
        data: data,
      ),
    );
    if (_events.length > maxEntries) _events.removeAt(0);
  }

  void clear() => _events.clear();
}

class EdgeReplayGuard {
  EdgeReplayGuard({this.maxAge = const Duration(minutes: 5)});
  final Duration maxAge;
  final Map<String, DateTime> _seen = {};
  bool accept({
    required String requestId,
    required String nonce,
    required DateTime timestamp,
  }) {
    final now = DateTime.now().toUtc();
    if (now.difference(timestamp).abs() > maxAge) return false;
    final key = '$requestId:$nonce';
    if (_seen.containsKey(key)) return false;
    _seen[key] = now;
    _seen.removeWhere((_, time) => now.difference(time) > maxAge);
    return true;
  }
}
