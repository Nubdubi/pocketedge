// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import '../core/pocketedge.dart';

/// A realtime event delivered to a channel subscriber.
class EdgeEvent {
  const EdgeEvent({
    required this.id,
    required this.channel,
    required this.event,
    required this.timestamp,
    required this.data,
  });

  /// Unique event identifier.
  final String id;

  /// Channel that produced this event.
  final String channel;

  /// Application-defined event name.
  final String event;

  /// Time at which the event was created.
  final DateTime timestamp;

  /// JSON-compatible event payload.
  final Map<String, dynamic> data;
}

/// Namespaced realtime events for a [PocketEdge] host.
class EdgeChannel {
  /// Creates a namespaced channel attached to [edge].
  EdgeChannel(this.edge, this.name);

  /// Host that owns this channel.
  final PocketEdge edge;

  /// Channel name used to filter and publish events.
  final String name;

  /// Listens only to events whose channel matches this channel name.
  StreamSubscription<EdgeEvent> listen(void Function(EdgeEvent event) onData) =>
      edge.events.where((event) => event.channel == name).listen(onData);

  /// Broadcasts an event through this channel.
  Future<void> broadcast({
    required String event,
    required Map<String, dynamic> data,
  }) =>
      edge.broadcast(channel: name, event: event, data: data);
}
