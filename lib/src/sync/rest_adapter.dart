// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'cloud_adapter.dart';

class RestPocketEdgeCloudAdapter implements PocketEdgeCloudAdapter {
  RestPocketEdgeCloudAdapter({
    required this.baseUri,
    this.headers = const {},
    HttpClient? client,
  }) : _client = client ?? HttpClient();
  final Uri baseUri;
  final Map<String, String> headers;
  final HttpClient _client;

  @override
  Future<bool> ping() async {
    final response = await _request('GET', '/health');
    response.drain<void>();
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  @override
  Future<SyncResult> push(List<EdgeSyncEvent> events) async {
    final response = await _request(
      'POST',
      '/sync/push',
      body: {
        'events': events
            .map(
              (event) => {
                'id': event.id,
                'type': event.type,
                'payload': event.payload,
                'createdAt': event.createdAt.toIso8601String(),
              },
            )
            .toList(),
      },
    );
    final json = await _json(response);
    _checkStatus(json, response.statusCode);
    return SyncResult(
      accepted: (json['accepted'] as num?)?.toInt() ?? events.length,
      cursor: json['cursor'] == null
          ? null
          : EdgeSyncCursor(json['cursor'] as String),
    );
  }

  @override
  Future<List<EdgeSyncEvent>> pull(EdgeSyncCursor cursor) async {
    final uri = baseUri.resolve(
      '/sync/pull${cursor.value == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor.value!)}'}',
    );
    final request = await _client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close();
    final json = await _json(response);
    _checkStatus(json, response.statusCode);
    final events = (json['events'] as List<dynamic>? ?? const []);
    return events.map((item) {
      final value = item as Map<String, dynamic>;
      return EdgeSyncEvent(
        id: value['id'] as String,
        type: value['type'] as String,
        payload: Map<String, dynamic>.from(value['payload'] as Map),
        createdAt: DateTime.parse(value['createdAt'] as String),
      );
    }).toList();
  }

  Future<HttpClientResponse> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = await _client.openUrl(method, baseUri.resolve(path));
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    return request.close();
  }

  static Future<Map<String, dynamic>> _json(
    HttpClientResponse response,
  ) async =>
      jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;
  static void _checkStatus(Map<String, dynamic> body, int status) {
    if (status < 200 || status >= 300) {
      throw HttpException(
        body['error']?.toString() ?? 'Cloud adapter request failed ($status)',
      );
    }
  }
}
