import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketedge/pocketedge.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('memory storage round trips values', () async {
    final storage = MemoryEdgeStorage();
    await storage.put('messages', 'one', {'text': 'hello'});
    expect(await storage.get('messages', 'one'), {'text': 'hello'});
    await storage.delete('messages', 'one');
    expect(await storage.get('messages', 'one'), isNull);
  });

  test('pairing tokens are single use', () {
    final pairing = PairingManager();
    final token = pairing.issue();
    expect(pairing.consume(token.value), isTrue);
    expect(pairing.consume(token.value), isFalse);
  });

  test('offline queue tracks pending entries', () {
    final queue = OfflineQueue();
    final entry = queue.enqueue('cloud_sync', {'id': 'one'});
    expect(queue.pending, contains(entry));
    queue.markSending(entry);
    queue.markSent(entry);
    expect(queue.pending, isEmpty);
  });

  test('join information round trips through JSON', () {
    const info = EdgeJoinInfo(
      host: '192.168.0.15',
      port: 8080,
      nodeId: 'edge_test',
      pairToken: 'temporary-token',
    );
    expect(EdgeJoinInfo.decode(info.encode()).toJson(), info.toJson());
    expect(info.uri.toString(), 'http://192.168.0.15:8080');
    expect(info.webSocketUri.toString(), 'ws://192.168.0.15:8080/ws');
  });

  test('secure join information preserves HTTPS scheme', () {
    const info = EdgeJoinInfo(
      host: '192.168.0.15',
      port: 8443,
      nodeId: 'edge_secure',
      scheme: 'https',
    );
    expect(
      EdgeJoinInfo.decode(info.encode()).uri.toString(),
      'https://192.168.0.15:8443',
    );
  });

  test('issued pairing token is included in join information', () {
    final edge = PocketEdge();
    expect(edge.joinInfo.pairToken, isNull);
    edge.issuePairingToken();
    expect(edge.joinInfo.pairToken, isNotNull);
  });

  test('public base URL is advertised for tunnel clients', () {
    final edge = PocketEdge(
      config: PocketEdgeConfig(
        port: 8080,
        bindAddress: '127.0.0.1',
        publicBaseUrl: Uri.parse('https://edge.example.com'),
      ),
    );

    expect(edge.joinInfo.uri.toString(), 'https://edge.example.com');
    expect(edge.joinInfo.webSocketUri.toString(), 'wss://edge.example.com/ws');
  });

  test('Cloudflare Tunnel YAML points to the local origin', () {
    const config = CloudflareTunnelConfig(
      tunnelId: '12345678-1234-1234-1234-123456789abc',
      tunnelName: 'pocketedge',
      hostname: 'edge.example.com',
      localPort: 8080,
    );
    expect(config.toYaml(), contains('service: http://127.0.0.1:8080'));
    expect(config.toYaml(), contains('service: http_status:404'));
  });

  test('stopping the host also stops network monitoring', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    edge.startNetworkMonitoring();
    expect(edge.networkMonitor.running, isTrue);
    await edge.stop();
    expect(edge.networkMonitor.running, isFalse);
  });

  test('sqlite storage persists records', () async {
    final storage = SqliteEdgeStorage(':memory:');
    await storage.put('messages', 'one', {'text': 'hello'});
    expect(await storage.get('messages', 'one'), {'text': 'hello'});
    await storage.delete('messages', 'one');
    expect(await storage.get('messages', 'one'), isNull);
    storage.close();
  });

  test('health endpoint is available over HTTP', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    await edge.start();
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/health'),
      );
      final response = await request.close();
      final body = jsonDecode(
        await response.transform(utf8.decoder).join(),
      ) as Map<String, dynamic>;
      expect(response.statusCode, HttpStatus.ok);
      expect(body['status'], 'ok');
      expect(body['nodeId'], startsWith('edge_'));
      client.close();
    } finally {
      await edge.stop();
    }
  });

  test('join endpoint returns scannable local connection data', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    await edge.start();
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/join'),
      );
      final response = await request.close();
      final body = jsonDecode(
        await response.transform(utf8.decoder).join(),
      ) as Map<String, dynamic>;
      expect(response.statusCode, HttpStatus.ok);
      expect(body['version'], 1);
      expect(body['port'], edge.status.port);
      expect(body['nodeId'], edge.nodeId);
      expect(body['host'], isNot(anyOf('0.0.0.0', '::')));
      client.close();
    } finally {
      await edge.stop();
    }
  });

  test('static web files are served locally', () async {
    final directory = await Directory.systemTemp.createTemp('pocketedge_web_');
    await File('${directory.path}/index.html')
        .writeAsString('<h1>Local Room</h1>');
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    edge.serveStatic(directory);
    await edge.start();
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, HttpStatus.ok);
      expect(body, contains('Local Room'));
      client.close();
    } finally {
      await edge.stop();
      await directory.delete(recursive: true);
    }
  });

  test('pairing endpoint issues a session and secures routes', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    edge.secureGet('/private', (request) async {
      final session = request.context['session'] as EdgeSession;
      return EdgeResponse.json({'deviceId': session.deviceId});
    });
    final pairToken = edge.issuePairingToken();
    await edge.start();
    final client = HttpClient();
    try {
      Future<HttpClientResponse> getPrivate({String? token}) async {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${edge.status.port}/private'),
        );
        if (token != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }
        return request.close();
      }

      final rejected = await getPrivate();
      expect(rejected.statusCode, HttpStatus.unauthorized);
      await rejected.drain<void>();

      final pairRequest = await client.postUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/pair'),
      );
      pairRequest.headers.contentType = ContentType.json;
      pairRequest.write(
        jsonEncode({'pairToken': pairToken, 'deviceId': 'phone_1'}),
      );
      final pairResponse = await pairRequest.close();
      final pairBody = jsonDecode(
        await pairResponse.transform(utf8.decoder).join(),
      ) as Map<String, dynamic>;
      expect(pairResponse.statusCode, HttpStatus.ok);
      final sessionToken = pairBody['sessionToken'] as String;

      final accepted = await getPrivate(token: sessionToken);
      expect(accepted.statusCode, HttpStatus.ok);
      expect(
        jsonDecode(await accepted.transform(utf8.decoder).join())['deviceId'],
        'phone_1',
      );

      final reusedRequest = await client.postUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/pair'),
      );
      reusedRequest.headers.contentType = ContentType.json;
      reusedRequest.write(
        jsonEncode({'pairToken': pairToken, 'deviceId': 'phone_2'}),
      );
      final reused = await reusedRequest.close();
      expect(reused.statusCode, HttpStatus.unauthorized);
      await reused.drain<void>();
    } finally {
      client.close();
      await edge.stop();
    }
  });

  test('permissions and rate limits are enforced', () async {
    final authorization = EdgeAuthorization();
    final session = SessionManager().issue(deviceId: 'guest_1');
    expect(authorization.allows(session, 'room.read'), isFalse);
    expect(authorization.allows(session, 'anything'), isFalse);

    final limiter = EdgeRateLimiter(
      maxRequests: 2,
      window: const Duration(minutes: 1),
    );
    expect(limiter.allow('client'), isTrue);
    expect(limiter.allow('client'), isTrue);
    expect(limiter.allow('client'), isFalse);
  });

  test('watchdog restarts a stopped host', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    await edge.start();
    final watchdog = EdgeWatchdog(
      edge,
      interval: const Duration(milliseconds: 10),
      maxRestarts: 2,
    );
    watchdog.start();
    await edge.stop();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(edge.status.running, isTrue);
    expect(watchdog.restartCount, 1);
    watchdog.stop();
    await edge.stop();
  });

  test(
    'sync coordinator queues locally and flushes through an adapter',
    () async {
      final adapter = _FakeCloudAdapter();
      final coordinator = SyncCoordinator(OfflineQueue(), adapter);
      await coordinator.enqueue('cloud_sync', {'id': 'one'});
      expect(coordinator.queue.pending, hasLength(1));
      final result = await coordinator.flush();
      expect(result?.accepted, 1);
      expect(adapter.pushed.single.payload, {'id': 'one'});
      expect(coordinator.queue.pending, isEmpty);
    },
  );

  test('notification dispatcher uses the first successful provider', () async {
    final dispatcher = NotificationDispatcher([
      _FakeNotificationProvider('offline', false),
      _FakeNotificationProvider('local', true),
    ]);
    final result = await dispatcher.send(
      const EdgeNotification(type: 'message_created', resourceId: 'message_1'),
    );
    expect(result.sent, isTrue);
    expect(result.provider, 'local');
  });

  test('connectivity monitor reports state changes', () async {
    var online = false;
    final states = <bool>[];
    final monitor = EdgeConnectivityMonitor(
      probe: () async => online,
      onChanged: states.add,
    );
    expect(await monitor.checkNow(), isFalse);
    online = true;
    expect(await monitor.checkNow(), isTrue);
    expect(states, [false, true]);
  });

  test('sync scheduler flushes queued work', () async {
    final adapter = _FakeCloudAdapter();
    final sync = SyncCoordinator(OfflineQueue(), adapter);
    await sync.enqueue('cloud_sync', {'id': 'scheduled'});
    final scheduler = SyncScheduler(sync);
    await scheduler.flushNow();
    expect(adapter.pushed.single.payload, {'id': 'scheduled'});
    scheduler.stop();
  });

  test('network monitor reports changed advertised addresses', () async {
    String? address = '192.168.0.10';
    final changes = <String?>[];
    final monitor = EdgeNetworkMonitor(
      probe: () async => address,
      onChanged: changes.add,
    );
    expect(await monitor.checkNow(), '192.168.0.10');
    address = '192.168.0.11';
    expect(await monitor.checkNow(), '192.168.0.11');
    expect(changes, ['192.168.0.10', '192.168.0.11']);
  });

  test('replay guard rejects reused and stale requests', () {
    final guard = EdgeReplayGuard(maxAge: const Duration(minutes: 1));
    final now = DateTime.now().toUtc();
    expect(guard.accept(requestId: 'r1', nonce: 'n1', timestamp: now), isTrue);
    expect(guard.accept(requestId: 'r1', nonce: 'n1', timestamp: now), isFalse);
    expect(
      guard.accept(
        requestId: 'r2',
        nonce: 'n2',
        timestamp: now.subtract(const Duration(minutes: 2)),
      ),
      isFalse,
    );
  });

  test('audit log is bounded and serializable', () {
    final log = EdgeAuditLog(maxEntries: 1);
    log.record('first');
    log.record('second', subject: 'device_1');
    expect(log.events, hasLength(1));
    expect(log.events.single.toJson()['type'], 'second');
  });

  test('file store enforces safe content types and size limits', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pocketedge_files_',
    );
    final store = EdgeFileStore(directory, maxBytes: 16);
    try {
      final result = await store.save(
        Stream<List<int>>.value([137, 80, 78, 71, 13, 10, 26, 10, 1]),
        contentType: 'image/png',
      );
      expect(result.bytes, 9);
      expect(
        (await store.open(result.id)).readAsBytes(),
        completion([137, 80, 78, 71, 13, 10, 26, 10, 1]),
      );
      expect(await store.contentType(result.id), 'image/png');
      await expectLater(
        store.save(
          Stream<List<int>>.value([1, 2, 3]),
          contentType: 'image/png',
        ),
        throwsA(isA<FileUploadException>()),
      );
      await expectLater(
        store.save(
          Stream<List<int>>.value([1]),
          contentType: 'application/x-executable',
        ),
        throwsA(isA<FileUploadException>()),
      );
      await expectLater(
        store.save(
          Stream<List<int>>.value(List<int>.filled(17, 1)),
          contentType: 'image/png',
        ),
        throwsA(isA<FileUploadException>()),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('file upload endpoint requires configured storage', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    await edge.start();
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/files'),
      );
      request.headers.contentType = ContentType('image', 'png');
      request.add([1, 2, 3]);
      final response = await request.close();
      expect(response.statusCode, HttpStatus.unauthorized);
      await response.drain<void>();
    } finally {
      client.close();
      await edge.stop();
    }
  });

  test('file store opens and deletes uploaded IDs only', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pocketedge_download_',
    );
    final store = EdgeFileStore(directory);
    try {
      final saved = await store.save(
        Stream<List<int>>.value([137, 80, 78, 71, 13, 10, 26, 10]),
        contentType: 'image/png',
      );
      expect(await (await store.open(saved.id)).readAsBytes(), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
      await store.delete(saved.id);
      expect(store.open(saved.id), throwsA(isA<FileUploadException>()));
      await expectLater(
        store.contentType(saved.id),
        throwsA(isA<FileUploadException>()),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'websocket client messages are broadcast to connected clients',
    () async {
      final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
      await edge.start();
      final first = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:${edge.status.port}/ws'),
      );
      final second = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:${edge.status.port}/ws'),
      );
      try {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        first.sink.add(
          jsonEncode({
            'channel': 'room',
            'event': 'message',
            'data': {'text': 'hello'},
          }),
        );
        final event = await second.stream.first.timeout(
          const Duration(seconds: 2),
        );
        expect(jsonDecode(event as String)['data']['text'], 'hello');
      } finally {
        await first.sink.close();
        await second.sink.close();
        await edge.stop();
      }
    },
  );

  test('CORS and request ID middleware protect browser responses', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    edge.use(edgeCors(allowedOrigins: {'http://local.test'}));
    edge.use(edgeRequestId());
    await edge.start();
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/health'),
      );
      request.headers.set('Origin', 'http://local.test');
      final response = await request.close();
      expect(
        response.headers.value('access-control-allow-origin'),
        'http://local.test',
      );
      expect(response.headers.value('x-request-id'), startsWith('req_'));
      await response.drain<void>();

      final preflight = await client.openUrl(
        'OPTIONS',
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/files'),
      );
      preflight.headers.set('Origin', 'http://local.test');
      preflight.headers.set('Access-Control-Request-Method', 'POST');
      preflight.headers.set(
        'Access-Control-Request-Headers',
        'Authorization, Content-Type, X-Request-Id',
      );
      final preflightResponse = await preflight.close();
      expect(preflightResponse.statusCode, HttpStatus.ok);
      expect(
        preflightResponse.headers.value('access-control-allow-methods'),
        contains('POST'),
      );
      expect(
        preflightResponse.headers.value('access-control-allow-headers'),
        contains('Authorization'),
      );
      await preflightResponse.drain<void>();
    } finally {
      client.close();
      await edge.stop();
    }
  });

  test('channel API filters server-side events by channel', () async {
    final edge = PocketEdge();
    final received = <EdgeEvent>[];
    final subscription = edge.channel('orders').listen(received.add);
    await edge
        .channel('orders')
        .broadcast(event: 'created', data: {'id': 'order_1'});
    await Future<void>.delayed(Duration.zero);
    expect(received.single.data['id'], 'order_1');
    await subscription.cancel();
    await edge.stop();
  });

  test('realtime authentication can be required by configuration', () async {
    final edge = PocketEdge(
      config: const PocketEdgeConfig(port: 0, realtimeAuthRequired: true),
    );
    await edge.start();
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/ws'),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.unauthorized);
      await response.drain<void>();
    } finally {
      client.close();
      await edge.stop();
    }
  });

  test('sqlite offline queue survives a new queue instance', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pocketedge_queue_',
    );
    final path = '${directory.path}/queue.sqlite';
    final first = SqliteOfflineQueue(path);
    final entry = await first.enqueue('cloud_sync', {'id': 'persisted'});
    first.close();
    final second = SqliteOfflineQueue(path);
    try {
      final pending = await second.pending();
      expect(pending.single.payload['id'], 'persisted');
      await second.markSending(entry.id);
      await second.markSent(entry.id);
      expect(await second.pending(), isEmpty);
    } finally {
      second.close();
      await directory.delete(recursive: true);
    }
  });

  test('sqlite sync coordinator flushes recovered events', () async {
    final directory = await Directory.systemTemp.createTemp('pocketedge_sync_');
    final path = '${directory.path}/queue.sqlite';
    final queue = SqliteOfflineQueue(path);
    final adapter = _FakeCloudAdapter();
    final sync = SqliteSyncCoordinator(queue, adapter);
    try {
      await sync.enqueue('cloud_sync', {'id': 'durable'});
      final result = await sync.flush();
      expect(result?.accepted, 1);
      expect(adapter.pushed.single.payload['id'], 'durable');
      expect(await queue.pending(), isEmpty);
    } finally {
      queue.close();
      await directory.delete(recursive: true);
    }
  });

  test('pairingRequired protects ordinary application routes', () async {
    final edge = PocketEdge(
      config: const PocketEdgeConfig(port: 0, pairingRequired: true),
    );
    edge.get('/public-in-app', (_) async => EdgeResponse.ok({'ok': true}));
    await edge.start();
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/public-in-app'),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.unauthorized);
      await response.drain<void>();
    } finally {
      client.close();
      await edge.stop();
    }
  });

  test('sqlite session manager restores unexpired sessions', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pocketedge_sessions_',
    );
    final path = '${directory.path}/sessions.sqlite';
    final first = SqliteSessionManager(path);
    final session = await first.issue(deviceId: 'device_1', role: 'staff');
    first.close();
    final second = SqliteSessionManager(path);
    try {
      final restored = await second.resolve(session.token);
      expect(restored?.deviceId, 'device_1');
      expect(restored?.role, 'staff');
      await second.revoke(session.token);
      expect(await second.resolve(session.token), isNull);
    } finally {
      second.close();
      await directory.delete(recursive: true);
    }
  });

  test('structured logger emits serializable records', () {
    final records = <EdgeLogRecord>[];
    final logger = EdgeLogger(sink: records.add);
    logger.info('server', 'started', {'port': 8080});
    expect(records.single.toJson()['event'], 'started');
    expect(records.single.toJson()['data']['port'], 8080);
  });

  test('detailed status requires diagnostics permission', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    final token = edge.issuePairingToken(role: 'manager');
    await edge.start();
    final client = HttpClient();
    try {
      final pair = await client.postUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/pair'),
      );
      pair.headers.contentType = ContentType.json;
      pair.write(jsonEncode({'pairToken': token, 'deviceId': 'manager_1'}));
      final pairResponse = await pair.close();
      final session = jsonDecode(
        await pairResponse.transform(utf8.decoder).join(),
      )['sessionToken'] as String;
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/status'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $session');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(
        jsonDecode(
          await response.transform(utf8.decoder).join(),
        )['server']['running'],
        isTrue,
      );
    } finally {
      client.close();
      await edge.stop();
    }
  });

  test('route rate limit middleware returns 429 after its budget', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    edge.use(edgeRateLimit(requests: 1, key: (_) => 'test'));
    await edge.start();
    final client = HttpClient();
    try {
      Future<HttpClientResponse> request() async {
        final value = await client.getUrl(
          Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/health'),
        );
        return value.close();
      }

      final first = await request();
      expect(first.statusCode, HttpStatus.ok);
      await first.drain<void>();
      final second = await request();
      expect(second.statusCode, HttpStatus.tooManyRequests);
      await second.drain<void>();
    } finally {
      client.close();
      await edge.stop();
    }
  });

  test('body limit middleware rejects oversized requests early', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    edge.use(edgeBodyLimit(maxBytes: 2));
    await edge.start();
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/_edge/pair'),
      );
      request.headers.contentLength = 3;
      request.add([1, 2, 3]);
      final response = await request.close();
      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
      await response.drain<void>();
    } finally {
      client.close();
      await edge.stop();
    }
  });

  test('error middleware hides raw route exceptions', () async {
    final edge = PocketEdge(config: const PocketEdgeConfig(port: 0));
    final records = <EdgeLogRecord>[];
    edge.use(edgeErrorHandler(logger: EdgeLogger(sink: records.add)));
    edge.get(
      '/explode',
      (_) async => throw StateError('secret internal detail'),
    );
    await edge.start();
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${edge.status.port}/explode'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, HttpStatus.internalServerError);
      expect(body, contains('Internal server error'));
      expect(body, isNot(contains('secret internal detail')));
      expect(records.single.event, 'request_failed');
    } finally {
      client.close();
      await edge.stop();
    }
  });

  test('status URL uses HTTPS when a security context is configured', () {
    final context = SecurityContext();
    final edge = PocketEdge(config: PocketEdgeConfig(securityContext: context));
    expect(edge.status.url, startsWith('https://'));
  });
}

class _FakeCloudAdapter implements PocketEdgeCloudAdapter {
  final pushed = <EdgeSyncEvent>[];
  @override
  Future<bool> ping() async => true;
  @override
  Future<SyncResult> push(List<EdgeSyncEvent> events) async {
    pushed.addAll(events);
    return SyncResult(
      accepted: events.length,
      cursor: const EdgeSyncCursor('cursor_1'),
    );
  }

  @override
  Future<List<EdgeSyncEvent>> pull(EdgeSyncCursor cursor) async => const [];
}

class _FakeNotificationProvider implements NotificationProvider {
  _FakeNotificationProvider(this.id, this.success);
  @override
  final String id;
  final bool success;
  @override
  Future<NotificationResult> send(EdgeNotification notification) async =>
      NotificationResult(sent: success, provider: id);
}
