// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DesktopHostController {
  static const _channel = MethodChannel('pocketedge/desktop');

  Future<void> setPersistent(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setPersistent', enabled);
    } on MissingPluginException {
      // Native desktop support is optional for package consumers.
    }
  }
}
