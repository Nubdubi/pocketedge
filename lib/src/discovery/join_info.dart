// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

/// Versioned connection data encoded in QR codes and join responses.
class EdgeJoinInfo {
  /// Creates versioned connection data for QR or manual pairing.
  const EdgeJoinInfo({
    required this.host,
    required this.port,
    required this.nodeId,
    this.pairToken,
    this.scheme = 'http',
    this.version = 1,
  });

  /// Hostname or IP address advertised to the joining device.
  final String host;

  /// Port advertised to the joining device.
  final int port;

  /// Stable identifier of the PocketEdge host.
  final String nodeId;

  /// Optional single-use pairing token.
  final String? pairToken;

  /// Transport scheme, normally `http` or `https`.
  final String scheme;

  /// Payload format version.
  final int version;

  /// Builds the base URI represented by this payload.
  Uri get uri => Uri(scheme: scheme, host: host, port: port);

  /// Builds the WebSocket URI for the default realtime endpoint.
  Uri get webSocketUri => uri.replace(
        scheme: scheme == 'https' ? 'wss' : 'ws',
        path: '/ws',
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'host': host,
        'port': port,
        'nodeId': nodeId,
        'scheme': scheme,
        if (pairToken != null) 'pairToken': pairToken,
      };

  /// Encodes this payload for a QR code.
  String encode() => jsonEncode(toJson());

  factory EdgeJoinInfo.fromJson(Map<String, dynamic> json) => EdgeJoinInfo(
        version: (json['version'] as num?)?.toInt() ?? 1,
        host: json['host'] as String,
        port: (json['port'] as num).toInt(),
        nodeId: json['nodeId'] as String,
        pairToken: json['pairToken'] as String?,
        scheme: json['scheme'] as String? ?? 'http',
      );

  /// Decodes a JSON string produced by [encode].
  factory EdgeJoinInfo.decode(String value) =>
      EdgeJoinInfo.fromJson(jsonDecode(value) as Map<String, dynamic>);
}
