// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import '../core/pocketedge.dart';

import 'dart:convert';
import 'dart:io';

/// A domain notification delivered through an application provider.
class EdgeNotification {
  const EdgeNotification({
    required this.type,
    required this.resourceId,
    this.data = const {},
  });

  /// Application-defined notification type.
  final String type;

  /// Resource associated with this notification.
  final String resourceId;

  /// Additional JSON-compatible notification data.
  final Map<String, dynamic> data;
}

/// Outcome of sending a notification.
class NotificationResult {
  const NotificationResult({required this.sent, this.provider, this.error});

  /// Whether a provider accepted the notification.
  final bool sent;

  /// Identifier of the provider that handled the notification.
  final String? provider;

  /// Error returned when delivery failed.
  final Object? error;
}

/// Provider contract for local or backend notification delivery.
abstract interface class NotificationProvider {
  /// Stable provider identifier used in [NotificationResult].
  String get id;

  /// Sends [notification] through this provider.
  Future<NotificationResult> send(EdgeNotification notification);
}

/// Delivers notifications to PocketEdge realtime clients.
class LocalWebSocketNotification implements NotificationProvider {
  /// Creates a provider that publishes through [edge] and [channel].
  LocalWebSocketNotification(this.edge, {this.channel = 'notifications'});

  /// Host used for realtime delivery.
  final PocketEdge edge;

  /// Realtime channel receiving notifications.
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

/// Tries notification providers until one succeeds.
class NotificationDispatcher {
  /// Tries providers in order until one successfully sends a notification.
  NotificationDispatcher([Iterable<NotificationProvider> providers = const []])
      : providers = List.unmodifiable(providers);

  /// Providers attempted in order.
  final List<NotificationProvider> providers;

  /// Sends [notification] using the first successful provider.
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

/// Sends notifications to an HTTP JSON endpoint.
class RestNotificationProvider implements NotificationProvider {
  RestNotificationProvider({
    required this.endpoint,
    this.headers = const {},
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  /// HTTP endpoint receiving notification JSON.
  final Uri endpoint;

  /// Headers added to each request.
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
