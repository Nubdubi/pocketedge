// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'cloud_adapter.dart';

typedef ConnectivityProbe = Future<bool> Function();
typedef ConnectivityChanged = void Function(bool online);

/// Periodically checks whether a cloud service is reachable.
class EdgeConnectivityMonitor {
  /// Creates a monitor using [probe] and an optional change callback.
  EdgeConnectivityMonitor({
    required this.probe,
    this.interval = const Duration(seconds: 15),
    this.onChanged,
  });

  /// Connectivity check function.
  final ConnectivityProbe probe;

  /// Interval between connectivity checks.
  final Duration interval;

  /// Called when connectivity changes.
  final ConnectivityChanged? onChanged;
  Timer? _timer;
  bool? _online;

  /// Whether periodic checks are active.
  bool get running => _timer != null;

  /// Last known connectivity state.
  bool? get online => _online;

  /// Starts periodic checks.
  void start() {
    if (running) return;
    _timer = Timer.periodic(interval, (_) => checkNow());
    checkNow();
  }

  /// Stops periodic checks.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Performs one immediate connectivity check.
  Future<bool> checkNow() async {
    final next = await probe();
    if (_online != next) {
      _online = next;
      onChanged?.call(next);
    }
    return next;
  }
}

class SyncScheduler {
  /// Creates a scheduler with an optional error callback.
  SyncScheduler(
    this.sync, {
    this.interval = const Duration(seconds: 30),
    this.onError,
  });

  /// Coordinator flushed by this scheduler.
  final SyncCoordinator sync;

  /// Interval between flushes.
  final Duration interval;

  /// Receives errors thrown during a flush.
  final void Function(Object error)? onError;
  Timer? _timer;

  /// Whether periodic flushing is active.
  bool get running => _timer != null;

  /// Starts periodic flushing.
  void start() {
    if (running) return;
    _timer = Timer.periodic(interval, (_) => flushNow());
    flushNow();
  }

  /// Stops periodic flushing.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Flushes the coordinator immediately.
  Future<void> flushNow() async {
    try {
      await sync.flush();
    } catch (error) {
      onError?.call(error);
    }
  }
}
