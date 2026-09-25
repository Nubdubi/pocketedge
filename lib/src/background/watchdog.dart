// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import '../core/pocketedge.dart';

typedef WatchdogLogger = void Function(String event, Map<String, dynamic> data);

class EdgeWatchdog {
  EdgeWatchdog(
    this.edge, {
    this.interval = const Duration(seconds: 10),
    this.maxRestarts = 3,
    this.logger,
  });
  final PocketEdge edge;
  final Duration interval;
  final int maxRestarts;
  final WatchdogLogger? logger;
  Timer? _timer;
  int _restartCount = 0;
  bool _checking = false;
  bool get running => _timer != null;
  int get restartCount => _restartCount;
  void start() {
    if (running) return;
    _timer = Timer.periodic(interval, (_) => _check());
    logger?.call('watchdog_started', {'intervalMs': interval.inMilliseconds});
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    logger?.call('watchdog_stopped', {});
  }

  Future<void> checkNow() => _check();
  Future<void> _check() async {
    if (_checking || !running || edge.status.running) return;
    if (_restartCount >= maxRestarts) {
      logger?.call('watchdog_restart_limit_reached', {
        'maxRestarts': maxRestarts,
      });
      stop();
      return;
    }
    _checking = true;
    try {
      await edge.start();
      _restartCount++;
      logger?.call('watchdog_restarted', {'restartCount': _restartCount});
    } catch (error) {
      _restartCount++;
      logger?.call('watchdog_restart_failed', {
        'restartCount': _restartCount,
        'error': '$error',
      });
    } finally {
      _checking = false;
    }
  }
}
