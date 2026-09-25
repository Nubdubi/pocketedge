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
  final String id;
  final String channel;
  final String event;
  final DateTime timestamp;
  final Map<String, dynamic> data;
}

/// Namespaced realtime events for a [PocketEdge] host.
class EdgeChannel {
  EdgeChannel(this.edge, this.name);
  final PocketEdge edge;
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
