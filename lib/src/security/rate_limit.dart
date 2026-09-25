// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
class EdgeRateLimiter {
  EdgeRateLimiter({
    this.maxRequests = 60,
    this.window = const Duration(minutes: 1),
  });
  final int maxRequests;
  final Duration window;
  final Map<String, _Bucket> _buckets = {};
  bool allow(String key) {
    final now = DateTime.now();
    final bucket = _buckets[key];
    if (bucket == null || now.difference(bucket.startedAt) >= window) {
      _buckets[key] = _Bucket(now);
      return true;
    }
    if (bucket.count >= maxRequests) return false;
    bucket.count++;
    return true;
  }
}

class _Bucket {
  _Bucket(this.startedAt);
  final DateTime startedAt;
  int count = 1;
}
