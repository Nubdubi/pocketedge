// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

typedef EdgeHandler = Future<Response> Function(Request request);

class EdgeResponse {
  const EdgeResponse._();
  static Response json(Map<String, dynamic> value, {int status = 200}) =>
      Response(
        status,
        body: jsonEncode(value),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
  static Response ok([Map<String, dynamic> value = const {}]) => json(value);
}

class PocketEdgeConfig {
  const PocketEdgeConfig({
    this.port = 8080,
    this.bindAddress = '0.0.0.0',
    this.nodeName = 'PocketEdge Host',
    this.pairingRequired = false,
    this.realtime = true,
    this.realtimeAuthRequired = false,
    this.securityContext,
  });
  final int port;
  final String bindAddress;
  final String nodeName;
  final bool pairingRequired;
  final bool realtime;
  final bool realtimeAuthRequired;
  final SecurityContext? securityContext;
}

class EdgeStatus {
  const EdgeStatus({
    required this.running,
    required this.port,
    required this.localAddress,
    required this.connectedClients,
    required this.uptime,
    required this.queuePending,
    this.scheme = 'http',
  });
  final bool running;
  final int port;
  final String? localAddress;
  final int connectedClients;
  final Duration uptime;
  final int queuePending;
  final String scheme;
  String get url => localAddress == null
      ? '$scheme://localhost:$port'
      : '$scheme://$localAddress:$port';
}

class EdgeSession {
  const EdgeSession({
    required this.token,
    required this.sessionId,
    required this.deviceId,
    required this.role,
    required this.issuedAt,
    required this.expiresAt,
  });
  final String token;
  final String sessionId;
  final String deviceId;
  final String role;
  final DateTime issuedAt;
  final DateTime expiresAt;
  bool get expired => DateTime.now().isAfter(expiresAt);
  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'deviceId': deviceId,
        'role': role,
        'issuedAt': issuedAt.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      };
}

sealed class PocketEdgeException implements Exception {
  const PocketEdgeException(this.message);
  final String message;
  @override
  String toString() => 'PocketEdgeException: $message';
}

class PortUnavailableException extends PocketEdgeException {
  const PortUnavailableException(super.message);
}

class PairingRejectedException extends PocketEdgeException {
  const PairingRejectedException(super.message);
}

class StorageException extends PocketEdgeException {
  const StorageException(super.message);
}
