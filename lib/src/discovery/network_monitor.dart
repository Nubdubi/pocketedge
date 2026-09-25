// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

typedef NetworkAddressProbe = Future<String?> Function();
typedef NetworkAddressChanged = void Function(String? address);

class EdgeNetworkMonitor {
  EdgeNetworkMonitor({
    NetworkAddressProbe? probe,
    this.interval = const Duration(seconds: 15),
    this.onChanged,
  }) : probe = probe ?? discoverLocalAddress;
  final NetworkAddressProbe probe;
  final Duration interval;
  final NetworkAddressChanged? onChanged;
  Timer? _timer;
  String? _address;
  bool get running => _timer != null;
  String? get address => _address;
  void start() {
    if (running) return;
    _timer = Timer.periodic(interval, (_) => checkNow());
    checkNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<String?> checkNow() async {
    final next = await probe();
    if (_address != next) {
      _address = next;
      onChanged?.call(next);
    }
    return next;
  }

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
