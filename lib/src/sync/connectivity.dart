// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'cloud_adapter.dart';

typedef ConnectivityProbe = Future<bool> Function();
typedef ConnectivityChanged = void Function(bool online);

class EdgeConnectivityMonitor {
  EdgeConnectivityMonitor({
    required this.probe,
    this.interval = const Duration(seconds: 15),
    this.onChanged,
  });
  final ConnectivityProbe probe;
  final Duration interval;
  final ConnectivityChanged? onChanged;
  Timer? _timer;
  bool? _online;
  bool get running => _timer != null;
  bool? get online => _online;

  void start() {
    if (running) return;
    _timer = Timer.periodic(interval, (_) => checkNow());
    checkNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

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
  SyncScheduler(
    this.sync, {
    this.interval = const Duration(seconds: 30),
    this.onError,
  });
  final SyncCoordinator sync;
  final Duration interval;
  final void Function(Object error)? onError;
  Timer? _timer;
  bool get running => _timer != null;
  void start() {
    if (running) return;
    _timer = Timer.periodic(interval, (_) => flushNow());
    flushNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> flushNow() async {
    try {
      await sync.flush();
    } catch (error) {
      onError?.call(error);
    }
  }
}
