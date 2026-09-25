// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import '../core/pocketedge.dart';

import 'dart:convert';
import 'dart:io';

class EdgeNotification {
  const EdgeNotification({
    required this.type,
    required this.resourceId,
    this.data = const {},
  });
  final String type;
  final String resourceId;
  final Map<String, dynamic> data;
}

class NotificationResult {
  const NotificationResult({required this.sent, this.provider, this.error});
  final bool sent;
  final String? provider;
  final Object? error;
}

abstract interface class NotificationProvider {
  String get id;
  Future<NotificationResult> send(EdgeNotification notification);
}

class LocalWebSocketNotification implements NotificationProvider {
  LocalWebSocketNotification(this.edge, {this.channel = 'notifications'});
  final PocketEdge edge;
  final String channel;
  @override
  String get id => 'local_websocket';
  @override
  Future<NotificationResult> send(EdgeNotification notification) async {
    await edge.broadcast(
      channel: channel,
      event: notification.type,
      data: {'resourceId': notification.resourceId, ...notification.data},
    );
    return NotificationResult(sent: true, provider: id);
  }
}

class NotificationDispatcher {
  NotificationDispatcher([Iterable<NotificationProvider> providers = const []])
      : providers = List.unmodifiable(providers);
  final List<NotificationProvider> providers;
  Future<NotificationResult> send(EdgeNotification notification) async {
    Object? lastError;
    for (final provider in providers) {
      try {
        final result = await provider.send(notification);
        if (result.sent) return result;
        lastError = result.error;
      } catch (error) {
        lastError = error;
      }
    }
    return NotificationResult(sent: false, error: lastError);
  }
}

class RestNotificationProvider implements NotificationProvider {
  RestNotificationProvider({
    required this.endpoint,
    this.headers = const {},
    HttpClient? client,
  }) : _client = client ?? HttpClient();
  final Uri endpoint;
  final Map<String, String> headers;
  final HttpClient _client;
  @override
  String get id => 'rest_notification';
  @override
  Future<NotificationResult> send(EdgeNotification notification) async {
    try {
      final request = await _client.postUrl(endpoint);
      headers.forEach(request.headers.set);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'type': notification.type,
          'resourceId': notification.resourceId,
          'data': notification.data,
        }),
      );
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return NotificationResult(
          sent: false,
          provider: id,
          error: HttpException(
            'Notification backend returned ${response.statusCode}',
          ),
        );
      }
      return NotificationResult(sent: true, provider: id);
    } catch (error) {
      return NotificationResult(sent: false, provider: id, error: error);
    }
  }
}
