// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

typedef NetworkAddressProbe = Future<String?> Function();
typedef NetworkAddressChanged = void Function(String? address);

/// Tracks the local IPv4 address advertised in join information.
class EdgeNetworkMonitor {
  /// Creates a monitor with an optional custom probe and callback.
  EdgeNetworkMonitor({
    NetworkAddressProbe? probe,
    this.interval = const Duration(seconds: 15),
    this.onChanged,
  }) : probe = probe ?? discoverLocalAddress;

  /// Function used to discover the current address.
  final NetworkAddressProbe probe;

  /// Interval between automatic checks.
  final Duration interval;

  /// Called when the discovered address changes.
  final NetworkAddressChanged? onChanged;
  Timer? _timer;
  String? _address;

  /// Whether periodic monitoring is active.
  bool get running => _timer != null;

  /// Last discovered address.
  String? get address => _address;

  /// Starts periodic address checks.
  void start() {
    if (running) return;
    _timer = Timer.periodic(interval, (_) => checkNow());
    checkNow();
  }

  /// Stops periodic address checks.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Performs an immediate address check.
  Future<String?> checkNow() async {
    final next = await probe();
    if (_address != next) {
      _address = next;
      onChanged?.call(next);
    }
    return next;
  }

  /// Finds the first non-loopback IPv4 address on the machine.
  static Future<String?> discoverLocalAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
    return null;
  }
}
