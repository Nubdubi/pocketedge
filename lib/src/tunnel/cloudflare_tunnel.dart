// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

/// Generates a local-origin Cloudflare Tunnel configuration.
class CloudflareTunnelConfig {
  const CloudflareTunnelConfig({
    required this.tunnelId,
    required this.tunnelName,
    required this.hostname,
    this.localHost = '127.0.0.1',
    this.localPort = 8080,
    this.credentialsFile,
  });

  final String tunnelId;
  final String tunnelName;
  final String hostname;
  final String localHost;
  final int localPort;
  final String? credentialsFile;

  /// Returns YAML accepted by `cloudflared tunnel run`.
  String toYaml() {
    final credentials = credentialsFile ??
        '${Platform.environment['HOME'] ?? '.'}/.cloudflared/$tunnelId.json';
    return '''tunnel: $tunnelId
credentials-file: $credentials

ingress:
  - hostname: $hostname
    service: http://$localHost:$localPort
  - service: http_status:404
''';
  }

  /// Writes the configuration file and creates its parent directory.
  Future<File> writeTo(File file) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(toYaml());
    return file;
  }
}
