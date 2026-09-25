// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import '../core/pocketedge.dart';

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

class EdgeChannel {
  EdgeChannel(this.edge, this.name);
  final PocketEdge edge;
  final String name;
  StreamSubscription<EdgeEvent> listen(void Function(EdgeEvent event) onData) =>
      edge.events.where((event) => event.channel == name).listen(onData);
  Future<void> broadcast({
    required String event,
    required Map<String, dynamic> data,
  }) =>
      edge.broadcast(channel: name, event: event, data: data);
}
