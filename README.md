# PocketEdge

Build local-first Flutter apps that keep working when the cloud disappears.

PocketEdge turns Android, Windows, macOS and Linux devices into local application servers for Flutter apps. Serve APIs and WebSockets over Wi-Fi, persist data locally, and sync to the cloud only when needed.

한국어 안내는 [doc/README.ko.md](doc/README.ko.md), 中文简体 안내는
[doc/README.zh-CN.md](doc/README.zh-CN.md)에서 확인할 수 있습니다. AI가
패키지를 사용할 때는 [llms.txt](llms.txt)와 [AI 사용 가이드](doc/AI_USAGE.md)를
먼저 읽도록 하십시오.

## Quick start

```dart
import 'package:pocketedge/pocketedge.dart';

Future<void> main() async {
  final edge = PocketEdge();
  edge.get('/api/hello', (_) async => EdgeResponse.json({'message': 'Hello from PocketEdge'}));
  await edge.start();
  print(edge.url);
}
```

The host exposes `GET /_edge/health`, `GET /_edge/status`, and `GET /_edge/join`. The join endpoint returns versioned host, port, node ID, and optional temporary pairing data for QR encoding. Local operation does not require a cloud account or internet connection.

Protected application routes can use the pairing/session flow:

```dart
edge.secureGet('/api/private', (request) async {
  final session = request.context['session'] as EdgeSession;
  return EdgeResponse.json({'deviceId': session.deviceId});
}, permission: 'room.read');

final pairToken = edge.issuePairingToken(role: 'staff');
```

Clients send `POST /_edge/pair` with `{"pairToken":"...","deviceId":"..."}` and then use the returned `sessionToken` as `Authorization: Bearer <token>`. Pairing tokens are short-lived and single-use; sessions are held in memory in this MVP.

The built-in roles are `guest`, `staff`, `manager`, and `admin`. Applications can provide their own permission map through `EdgeAuthorization`. Pairing and authenticated routes have a default in-memory rate limiter.

On Android, the Local Room example starts a foreground service alongside the host and displays a persistent notification. This keeps the hosting process active when the Flutter activity is backgrounded; it does not promise survival after force-stop or device shutdown.

Hosts can also monitor themselves with the watchdog:

```dart
final watchdog = EdgeWatchdog(edge);
watchdog.start();
```

The watchdog restarts a stopped host up to its configured limit and then disables itself to avoid crash loops.

On desktop, enabling the host sets persistent mode through `DesktopHostController`. macOS keeps the app available from a PocketEdge menu-bar item after the window closes. Windows hides the window instead of terminating while persistent mode is enabled; the native tray surface can be extended without changing the Dart API.

Cloud sync is adapter-based and optional:

```dart
final sync = SyncCoordinator(edge.queue, myCloudAdapter);
await sync.enqueue('cloud_sync', {'resourceId': 'message_1'});
await sync.flush(); // no-op while the adapter reports offline
```

PocketEdge does not ship Firebase, Supabase, or another cloud client in core. Applications provide a `PocketEdgeCloudAdapter` implementation.

For a conventional backend, the package includes a generic REST adapter:

```dart
final cloud = RestPocketEdgeCloudAdapter(
  baseUri: Uri.parse('https://api.example.com'),
  headers: {'authorization': 'Bearer backend-token'},
);
final sync = SyncCoordinator(edge.queue, cloud);
```

For queue durability across host restarts, use `SqliteOfflineQueue` as the persistent queue backend. It preserves payloads, attempts, and states in SQLite.

Use `SqliteSyncCoordinator` to flush that durable queue through the same cloud adapter:

```dart
final sync = SqliteSyncCoordinator(sqliteQueue, cloudAdapter);
await sync.flush();
```

Notifications use the same adapter boundary:

```dart
final notifications = NotificationDispatcher([
  LocalWebSocketNotification(edge),
  // FCM/SMS/email providers can be added by the application.
]);

await notifications.send(
  const EdgeNotification(type: 'message_created', resourceId: 'message_1'),
);
```

For cloud notification services, use the generic backend adapter so FCM/SMS/Kakao credentials stay server-side:

```dart
final cloudNotifications = RestNotificationProvider(
  endpoint: Uri.parse('https://api.example.com/notifications'),
  headers: {'authorization': 'Bearer backend-token'},
);
```

Connection recovery can be wired without a platform-specific connectivity package:

```dart
final monitor = EdgeConnectivityMonitor(
  probe: () => myCloudAdapter.ping(),
  onChanged: (online) => print('cloud online: $online'),
);
final scheduler = SyncScheduler(sync);
monitor.start();
scheduler.start();
```

For LAN address changes, start the network monitor so new QR/join responses advertise the current IPv4 address:

```dart
edge.startNetworkMonitoring();
// edge.joinInfo and GET /_edge/join now use the refreshed address.
// edge.stop() also stops the monitor.
```

Sensitive POST routes can enable replay protection:

```dart
edge.securePost(
  '/api/important-action',
  handler,
  replayProtected: true,
);
```

Clients must send unique `X-Request-Id`, `X-Nonce`, and a current Unix-seconds `X-Timestamp`. Authentication, pairing, permission, and replay failures are recorded in `edge.auditLog`.

File sharing can use `EdgeFileStore`, which defaults to a 10 MB limit, an allowlist of safe content types, randomized storage IDs, and no trust in client-provided filenames:

```dart
final files = EdgeFileStore(Directory('/data/pocketedge/files'));
final saved = await files.save(request.read(), contentType: 'image/png');
```

`EdgeFileStore` enforces the allowlist, size limit, and (by default) magic-byte
signatures for PNG, JPEG, WebP, and PDF uploads. Set
`validateContentSignatures: false` only when a trusted upstream decoder handles
validation. The declared MIME type is stored beside the file and restored by
PocketEdge's download endpoint.

To expose the protected upload endpoint, inject the store into `PocketEdge`. Clients then upload raw bytes to `POST /_edge/files` with a staff-or-higher session and a permitted `Content-Type`:

```dart
final edge = PocketEdge(fileStore: files);
```

The same session can use `GET /_edge/files/:id` with `files.read` or `DELETE /_edge/files/:id` with `files.write`.

The repository includes a minimal browser client at `example/web_client/index.html`. Serve it with:

```dart
edge.serveStatic(Directory('example/web_client'));
await edge.start();
```

Open the host URL from another device on the same LAN. The client connects to `/ws` and demonstrates local chat without internet access.

Configure browser middleware explicitly when the client is hosted on another origin:

```dart
edge.use(edgeCors(allowedOrigins: {'http://trusted-client.local'}));
edge.use(edgeRequestId());
```

Realtime channels are available without exposing the underlying socket set:

```dart
final orders = edge.channel('orders');
orders.listen((event) {
  print(event.data);
});

await orders.broadcast(
  event: 'created',
  data: {'id': 'order_102'},
);
```

For privileged realtime channels, require a session during the WebSocket handshake:

```dart
final edge = PocketEdge(
  config: const PocketEdgeConfig(realtimeAuthRequired: true),
);
```

Clients must then send `Authorization: Bearer <sessionToken>` when opening `/ws`.

Set `pairingRequired: true` to protect ordinary application routes globally. Health, join, and pairing bootstrap endpoints remain public so a new client can establish its session.

For hosts that need sessions to survive process restarts, use the optional `SqliteSessionManager`. The default in-memory manager remains appropriate for temporary local rooms.

```dart
final sessions = SqliteSessionManager('/data/pocketedge/sessions.sqlite');
final edge = PocketEdge(sessionStore: sessions);
```

The injected store is used by pairing, protected HTTP routes, global `pairingRequired` checks, and authenticated WebSocket handshakes.

Structured lifecycle logs can be collected without enabling telemetry:

```dart
final edge = PocketEdge(
  logger: EdgeLogger(sink: (record) => print(record.toJson())),
);
```

`GET /_edge/health` is a public lightweight probe. Detailed `GET /_edge/status` diagnostics require the `diagnostics.read` permission and report server, network, storage, realtime, and queue state.

Applications can add route-wide limits with middleware:

```dart
edge.use(edgeRateLimit(
  requests: 60,
  window: Duration(minutes: 1),
));
```

Set a global request body limit as an additional guard for upload and JSON endpoints:

```dart
edge.use(edgeBodyLimit(maxBytes: 10 * 1024 * 1024));
```

Use the error middleware to keep internal exception details out of client responses:

```dart
edge.use(edgeErrorHandler(logger: edge.logger));
```

HTTPS is optional and uses an application-provided `SecurityContext`:

```dart
final context = SecurityContext()
  ..useCertificateChain('/path/cert.pem')
  ..usePrivateKey('/path/key.pem');
final edge = PocketEdge(
  config: PocketEdgeConfig(securityContext: context),
);
```

Local self-signed certificates still require client/browser trust configuration; TLS does not automatically make a local IP certificate trusted.

When the host calls `issuePairingToken(role: 'staff')`, the token is included in `/​_edge/join`; the payload also carries the active `scheme` (`http` or `https`) so QR clients build the correct URL. The example browser client uses the token once to obtain a session and enables the protected file upload control. Pairing tokens remain short-lived and single-use.

For persistent local records, pass `SqliteEdgeStorage` into the host:

```dart
final edge = PocketEdge(storage: SqliteEdgeStorage('/path/to/pocketedge.sqlite'));
```

SQLite-backed storage, sessions, and queues are native-only because they use
`dart:ffi`. Web builds remain supported with `MemoryEdgeStorage` and the
in-memory queue; use a cloud adapter when browser persistence is required.

To serve a bundled local web app, register its build directory before starting:

```dart
edge.serveStatic(Directory('/path/to/web_build'));
await edge.start();
```

## MVP boundaries

This first package-shaped MVP includes server lifecycle, REST routing, health/status, WebSocket broadcast, memory and SQLite storage, versioned join information, QR rendering, static web serving, pairing tokens, and an offline queue. Calling `edge.stop()` also stops LAN address monitoring; injected SQLite stores remain owned by the application and should be closed by the caller. Platform background hosts and cloud adapters are isolated for later phases.

PocketEdge is infrastructure, not business logic. Orders, menus, payments, and domain permissions belong in applications built on top of it.

## 한국어 요약

PocketEdge는 인터넷이 끊겨도 같은 LAN에서 동작하는 Flutter 로컬 서버입니다.
`PocketEdge`를 만들고 `get`, `post`, `secureGet`으로 API를 등록한 뒤
`await edge.start()`로 시작합니다. 개인 데이터 API에는 pairing token과 세션
권한을 사용하고, 운영 환경에서는 `pairingRequired: true`, 명시적 CORS,
HTTPS를 설정하십시오. Web에서는 SQLite를 사용할 수 없으므로 메모리 저장소나
서버 저장소를 사용합니다. 자세한 내용은 [한국어 문서](doc/README.ko.md)를
확인하십시오.

## 中文简体摘要

PocketEdge 是一个即使断网也能在同一局域网运行的 Flutter 本地服务器。
创建 `PocketEdge` 后使用 `get`、`post` 或 `secureGet` 注册 API，再调用
`await edge.start()` 启动。私人数据必须使用 pairing token、会话和权限控制；
生产环境建议启用 `pairingRequired: true`、明确的 CORS 和 HTTPS。Web 不支持
SQLite，应使用内存存储或服务器存储。详细内容请参阅[中文文档](doc/README.zh-CN.md)。

For AI-assisted development, read [llms.txt](llms.txt) and
[doc/AI_USAGE.md](doc/AI_USAGE.md) before generating integration code.

## License

Apache-2.0. See [LICENSE](LICENSE) and [SECURITY.md](SECURITY.md).
