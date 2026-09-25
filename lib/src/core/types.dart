// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

typedef EdgeHandler = Future<Response> Function(Request request);

/// Creates JSON responses for PocketEdge routes.
class EdgeResponse {
  const EdgeResponse._();

  /// Encodes [value] as a JSON response with the given HTTP [status].
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
    this.publicBaseUrl,
  });
  final int port;
  final String bindAddress;
  final String nodeName;
  final bool pairingRequired;
  final bool realtime;
  final bool realtimeAuthRequired;
  final SecurityContext? securityContext;

  /// Public origin advertised in QR codes and join responses.
  ///
  /// Set this to a Cloudflare Tunnel hostname when the host is reachable
  /// through `cloudflared`, for example `https://edge.example.com`. The
  /// PocketEdge listener still binds to [bindAddress] and [port].
  final Uri? publicBaseUrl;
}

/// Runtime information about a PocketEdge host.
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

  /// Returns the best URL that clients can use to reach the host.
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

  /// Whether this session has passed its expiration time.
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

/// Raised when the configured listening port cannot be opened.
class PortUnavailableException extends PocketEdgeException {
  const PortUnavailableException(super.message);
}

/// Raised when a pairing request is invalid or already consumed.
class PairingRejectedException extends PocketEdgeException {
  const PairingRejectedException(super.message);
}

/// Raised when a local storage operation fails.
class StorageException extends PocketEdgeException {
  const StorageException(super.message);
}
