// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

/// Versioned connection data encoded in QR codes and join responses.
class EdgeJoinInfo {
  const EdgeJoinInfo({
    required this.host,
    required this.port,
    required this.nodeId,
    this.pairToken,
    this.scheme = 'http',
    this.version = 1,
  });
  final String host;
  final int port;
  final String nodeId;
  final String? pairToken;
  final String scheme;
  final int version;

  /// Builds the base URI represented by this payload.
  Uri get uri => Uri(scheme: scheme, host: host, port: port);

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

  factory EdgeJoinInfo.decode(String value) =>
      EdgeJoinInfo.fromJson(jsonDecode(value) as Map<String, dynamic>);
}
