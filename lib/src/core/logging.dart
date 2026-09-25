// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
enum EdgeLogLevel { trace, debug, info, warning, error, critical }

class EdgeLogRecord {
  const EdgeLogRecord({
    required this.time,
    required this.level,
    required this.module,
    required this.event,
    this.data = const {},
  });
  final DateTime time;
  final EdgeLogLevel level;
  final String module;
  final String event;
  final Map<String, dynamic> data;
  Map<String, dynamic> toJson() => {
        'time': time.toUtc().toIso8601String(),
        'level': level.name,
        'module': module,
        'event': event,
        'data': data,
      };
}

typedef EdgeLogSink = void Function(EdgeLogRecord record);

class EdgeLogger {
  EdgeLogger({this.sink});
  final EdgeLogSink? sink;
  void log(
    EdgeLogLevel level,
    String module,
    String event, [
    Map<String, dynamic> data = const {},
  ]) =>
      sink?.call(
        EdgeLogRecord(
          time: DateTime.now(),
          level: level,
          module: module,
          event: event,
          data: data,
        ),
      );
  void info(
    String module,
    String event, [
    Map<String, dynamic> data = const {},
  ]) =>
      log(EdgeLogLevel.info, module, event, data);
  void warning(
    String module,
    String event, [
    Map<String, dynamic> data = const {},
  ]) =>
      log(EdgeLogLevel.warning, module, event, data);
  void error(
    String module,
    String event, [
    Map<String, dynamic> data = const {},
  ]) =>
      log(EdgeLogLevel.error, module, event, data);
}
