// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:shelf/shelf.dart';

import '../security/rate_limit.dart';
import '../core/logging.dart';

Middleware edgeCors({
  Set<String> allowedOrigins = const {},
  bool allowCredentials = false,
}) =>
    (Handler handler) {
      return (Request request) async {
        final origin = request.headers['origin'];
        final allowed = origin != null && allowedOrigins.contains(origin);
        if (request.method == 'OPTIONS') {
          if (!allowed) return Response.forbidden('Origin is not allowed.');
          return Response.ok('',
              headers: _corsHeaders(origin, allowCredentials));
        }
        final response = await handler(request);
        if (!allowed) return response;
        return response.change(
          headers: {
            ...response.headers,
            ..._corsHeaders(origin, allowCredentials)
          },
        );
      };
    };
Middleware edgeRequestId() => (Handler handler) {
      return (Request request) async {
        final requestId = request.headers['x-request-id'] ??
            'req_${Random.secure().nextInt(0x7fffffff).toRadixString(16)}';
        final response = await handler(
          request.change(context: {'requestId': requestId}),
        );
        return response.change(
          headers: {...response.headers, 'x-request-id': requestId},
        );
      };
    };
Map<String, String> _corsHeaders(String? origin, bool credentials) => {
      'access-control-allow-origin': origin!,
      'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS',
      'access-control-allow-headers':
          'Authorization, Content-Type, X-Request-Id, X-Nonce, X-Timestamp',
      if (credentials) 'access-control-allow-credentials': 'true',
    };

Middleware edgeRateLimit({
  int requests = 60,
  Duration window = const Duration(minutes: 1),
  String Function(Request request)? key,
}) {
  final limiter = EdgeRateLimiter(maxRequests: requests, window: window);
  return (Handler handler) => (Request request) async {
        final bucket = key?.call(request) ??
            request.headers['x-device-id'] ??
            request.headers['authorization'] ??
            'anonymous';
        if (!limiter.allow(bucket)) {
          return Response(
            429,
            body: 'Too many requests.',
            headers: {'retry-after': window.inSeconds.toString()},
          );
        }
        return handler(request);
      };
}

Middleware edgeBodyLimit({int maxBytes = 10 * 1024 * 1024}) =>
    (Handler handler) => (Request request) async {
          final contentLength = request.headers['content-length'];
          final length =
              contentLength == null ? null : int.tryParse(contentLength);
          if (length != null && length > maxBytes) {
            return Response(
              413,
              body: 'Request body is too large.',
              headers: {'content-type': 'text/plain; charset=utf-8'},
            );
          }
          return handler(request);
        };

Middleware edgeErrorHandler({EdgeLogger? logger}) => (Handler handler) {
      return (Request request) async {
        try {
          return await handler(request);
        } catch (error) {
          logger?.error('server', 'request_failed', {
            'method': request.method,
            'path': request.requestedUri.path,
            'errorType': error.runtimeType.toString(),
          });
          return Response.internalServerError(
            body: '{"error":"Internal server error"}',
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
      };
    };
