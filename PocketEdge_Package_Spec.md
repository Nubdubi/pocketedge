# PocketEdge Package Specification

> **PocketEdge** — A local-first edge server framework for Flutter.
>
> Turn Android, Windows, macOS, and Linux devices into secure local application servers that can continue operating without an internet connection.

---

## 1. Project Overview

PocketEdge is an open-source Flutter/Dart package that provides reusable local-server infrastructure for applications that need to keep working even when the internet is unavailable.

PocketEdge is **not** a POS, kiosk, chat app, or table-order app by itself.

It is the reusable infrastructure layer that those services can be built on top of.

Examples:

- QR table ordering
- Kiosk systems
- Local POS
- Event photo sharing
- Local chat
- Classroom tools
- Disaster communication boards
- Local live streaming control
- Warehouse tools
- IoT gateways
- Offline forms
- On-site inventory
- Local AI gateways
- Device-to-device sync

The package should follow a **Local-first / Cloud-optional** philosophy.

```text
Application
    │
    ▼
PocketEdge
    │
    ├── Local HTTP Server
    ├── WebSocket
    ├── Local Storage
    ├── Discovery
    ├── Security
    ├── Background Runtime
    ├── Offline Queue
    └── Cloud Adapter
```

---

# 2. License

PocketEdge Core is licensed under:

**Apache License 2.0**

SPDX identifier:

```text
Apache-2.0
```

Recommended repository files:

```text
LICENSE
NOTICE
README.md
CONTRIBUTING.md
SECURITY.md
CODE_OF_CONDUCT.md
```

Every source file may optionally contain:

```dart
// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
```

## 2.1 Open-source boundary

The following should remain open source:

```text
pocketedge_core
pocketedge_server
pocketedge_realtime
pocketedge_storage
pocketedge_discovery
pocketedge_security
pocketedge_background
pocketedge_sync
pocketedge_notifications
```

Commercial products may be built on top of PocketEdge.

Examples:

```text
PocketEdge Cloud
PocketEdge Enterprise
PocketEdge Table
PocketEdge POS
PocketEdge Franchise
Managed Hosting
Premium Analytics
Enterprise Connectors
```

Apache-2.0 allows third parties to use PocketEdge in commercial products while preserving license notices and applicable attribution requirements.

---

# 3. Core Design Principles

PocketEdge must follow these principles.

## 3.1 Local-first

The application must continue working without cloud connectivity.

```text
User Action
    ↓
Local DB
    ↓
Local Event
    ↓
UI Updated

Internet available?
    ├── YES → Cloud Sync
    └── NO  → Queue
```

Cloud APIs must never be required for normal local operations.

---

## 3.2 Cloud-optional

PocketEdge Core must not depend on:

- Firebase
- Supabase
- AWS
- Google Cloud
- Azure
- PocketEdge Cloud

Cloud services must be adapters/plugins.

---

## 3.3 Framework, not business logic

PocketEdge must NOT contain application-specific APIs such as:

```dart
createOrder();
addMenu();
callWaiter();
checkout();
```

PocketEdge should expose infrastructure APIs such as:

```dart
edge.route();
edge.channel();
edge.storage();
edge.broadcast();
edge.sync();
edge.notify();
```

Business applications implement their own domain logic.

---

## 3.4 Multi-platform

Target platforms:

| Platform | Host Server | Client | Background Host |
|---|---:|---:|---:|
| Android | Yes | Yes | Yes, using foreground service |
| Windows | Yes | Yes | Yes |
| macOS | Yes | Yes | Yes |
| Linux | Yes | Yes | Yes |
| iOS | Limited | Yes | Not recommended for persistent host |
| Web | No | Yes | No |

Flutter Web is treated primarily as a browser client.

---

# 4. MVP Scope

Version:

```text
PocketEdge v0.1.0
```

The first release should prove one thing:

> A Flutter application can turn a device into a local server that nearby browsers and apps can use without an internet connection.

Initial MVP features:

1. Local HTTP server
2. REST routing
3. WebSocket channels
4. Static web serving
5. Local storage
6. QR join information
7. Device status
8. Basic pairing
9. Offline event queue
10. Android background hosting
11. Windows/macOS persistent hosting
12. Example local-room application

Do NOT include in v0.1:

- distributed leader election
- automatic server handoff
- mesh routing
- WebRTC live broadcasting
- FCM implementation
- SMS implementation
- Kakao Alimtalk implementation
- payment processing
- NFC payments
- complex cloud sync
- AI inference

These belong in later versions.

---

# 5. Package Layout

During the MVP, maintain a single public package:

```text
package:pocketedge
```

Repository structure:

```text
pocketedge/
│
├── lib/
│   ├── pocketedge.dart
│   │
│   └── src/
│       ├── core/
│       ├── server/
│       ├── realtime/
│       ├── storage/
│       ├── security/
│       ├── discovery/
│       ├── background/
│       ├── sync/
│       └── notifications/
│
├── android/
├── windows/
├── macos/
├── linux/
│
├── example/
│   ├── host_app/
│   └── web_client/
│
├── test/
├── integration_test/
│
├── README.md
├── CHANGELOG.md
├── LICENSE
├── NOTICE
├── SECURITY.md
└── pubspec.yaml
```

After the API stabilizes, packages may be separated:

```text
pocketedge_core
pocketedge_server
pocketedge_realtime
pocketedge_storage
pocketedge_security
pocketedge_discovery
pocketedge_background
pocketedge_sync
pocketedge_notifications
```

Do not split prematurely.

---

# 6. Main Public API

Desired developer experience:

```dart
final edge = PocketEdge(
  config: PocketEdgeConfig(
    port: 8080,
    storage: true,
    realtime: true,
  ),
);

await edge.start();
```

Status:

```dart
final status = edge.status;

print(status.running);
print(status.port);
print(status.localAddress);
print(status.connectedClients);
```

Stop:

```dart
await edge.stop();
```

---

# 7. Server Layer

Use:

```text
shelf
shelf_router
shelf_web_socket
shelf_static
```

Do NOT use the discontinued:

```text
package:http_server
```

The actual low-level server remains based on:

```text
dart:io HttpServer
```

through `shelf_io`.

Example:

```dart
edge.get('/api/status', (request) async {
  return EdgeResponse.json({
    'running': true,
    'nodeId': edge.nodeId,
  });
});
```

POST:

```dart
edge.post('/api/message', (request) async {
  final body = await request.json();

  await edge.storage.put(
    'messages',
    body['id'],
    body,
  );

  return EdgeResponse.ok();
});
```

---

# 8. Static Web Client

PocketEdge Host must be able to serve a bundled web application.

Example:

```text
/
├── index.html
├── flutter.js
├── main.dart.js
└── assets/
```

Routes:

```text
/api/*
/ws/*
/
```

Meaning:

```text
/api/*
→ REST API

/ws
→ WebSocket

/
→ Flutter Web / static UI
```

This enables:

```text
QR scan
   ↓
Browser
   ↓
Local PocketEdge Host
```

No app installation is required for guests.

All static resources must be bundled locally.

Avoid required CDN dependencies for offline mode.

---

# 9. Local Networking

PocketEdge must support ordinary LAN operation first.

Example:

```text
Wi-Fi Router
    │
    ├── PocketEdge Host
    ├── Android client
    ├── iPhone client
    └── Laptop
```

Internet connectivity is optional.

Later Android releases may support:

```text
LocalOnlyHotspot
Hotspot assistance
Wi-Fi Direct
BLE discovery
mDNS
```

MVP should not depend on automatic hotspot creation.

---

# 10. Discovery

Initial discovery methods:

## 10.1 QR

Preferred MVP method.

QR payload:

```json
{
  "version": 1,
  "host": "192.168.0.15",
  "port": 8080,
  "nodeId": "edge_a3f9",
  "pairToken": "temporary-random-token"
}
```

Sensitive long-term credentials must not be stored in permanent printed QR codes.

---

## 10.2 Manual URL

Example:

```text
http://192.168.0.15:8080
```

---

## 10.3 Future discovery

Later:

```text
mDNS
NSD
BLE advertisements
LAN broadcast
Wi-Fi Direct
```

---

# 11. Realtime Layer

Use WebSocket for:

- orders
- chat
- staff call
- inventory changes
- kiosk events
- device status
- notifications
- presence

Concept:

```dart
final channel = edge.channel('orders');

channel.listen((event) {
  print(event.data);
});
```

Broadcast:

```dart
await edge.broadcast(
  channel: 'orders',
  event: 'created',
  data: {
    'id': 'order_102',
  },
);
```

Message envelope:

```json
{
  "id": "evt_0192",
  "channel": "orders",
  "event": "created",
  "timestamp": 1780000000,
  "data": {}
}
```

---

# 12. Local Storage

Initial recommendation:

```text
SQLite / Drift
```

Storage interface:

```dart
abstract interface class EdgeStorage {
  Future<void> put(
    String collection,
    String id,
    Map<String, dynamic> data,
  );

  Future<Map<String, dynamic>?> get(
    String collection,
    String id,
  );

  Future<void> delete(
    String collection,
    String id,
  );
}
```

Default implementation:

```text
SQLiteEdgeStorage
```

Possible future implementations:

```text
MemoryEdgeStorage
IsarEdgeStorage
HiveEdgeStorage
CustomEdgeStorage
```

PocketEdge Core must not hard-code domain database schemas.

---

# 13. Offline Queue

Every cloud-bound event should be queueable.

State example:

```text
pending
sending
sent
failed
expired
```

Queue entry:

```json
{
  "id": "queue_8812",
  "type": "cloud_sync",
  "createdAt": 1780000000,
  "attempts": 0,
  "payload": {}
}
```

Retry:

```text
1 sec
5 sec
30 sec
2 min
10 min
```

Add jitter in production.

Avoid infinite aggressive retry loops.

---

# 14. Security

Security must be built into the architecture from the beginning.

PocketEdge must not assume:

> Local network = trusted network.

Required security layers:

```text
Network
  ↓
Pairing
  ↓
Session Authentication
  ↓
Authorization
  ↓
Replay Protection
  ↓
Storage Protection
```

---

## 14.1 Pairing

Suggested flow:

```text
Host creates temporary token
        ↓
QR generated
        ↓
Client scans
        ↓
POST /pair
        ↓
temporary token validated
        ↓
session credential issued
```

Pair tokens:

- random
- short-lived
- single-use when possible

---

## 14.2 Session Token

Each client receives a session token.

Example claims:

```json
{
  "sessionId": "s_82ba",
  "deviceId": "device_b22",
  "role": "staff",
  "issuedAt": 1780000000,
  "expiresAt": 1780003600
}
```

---

## 14.3 Role-based permissions

Example:

```text
guest
staff
manager
admin
```

Application code defines permissions.

PocketEdge supplies middleware.

Example:

```dart
edge.authorize(
  permission: 'inventory.write',
);
```

---

## 14.4 Replay protection

Sensitive requests may include:

```text
requestId
timestamp
nonce
signature
```

Repeated request IDs should be rejected.

---

## 14.5 TLS

PocketEdge may support HTTPS using `SecurityContext`.

However, local IP addresses create certificate trust challenges for browsers.

Therefore TLS support is optional in the MVP.

Do NOT pretend that a self-signed certificate automatically produces a trusted browser experience.

---

## 14.6 Application-level encryption

Future optional module:

```text
ECDH key exchange
+
AES-GCM or ChaCha20-Poly1305
```

This can protect sensitive payloads independently of transport.

Do not implement custom cryptographic algorithms.

Use established libraries.

---

# 15. Background Runtime

PocketEdge Host must be independent from the Flutter screen lifecycle.

## Android

Use a native Android foreground service for persistent hosting.

Expected UX:

```text
PocketEdge server running
Clients: 7
Pending sync: 3

[Open]
[Stop]
```

Server lifecycle should survive:

```text
Flutter UI backgrounded
Screen off
Activity recreated
```

Do not promise survival after force-stop.

---

## Windows

Support:

```text
System Tray
Start with Windows
Run when UI window closes
```

Closing the window should optionally minimize to tray rather than terminate the server.

---

## macOS

Support:

```text
Menu bar / background application
Launch at login
Persistent host process
```

---

## iOS

iOS should primarily be treated as a client platform.

Persistent background Shelf hosting is not a core supported production scenario.

---

# 16. Watchdog

Host runtime should monitor:

```text
HTTP server state
WebSocket state
local IP changes
database health
cloud connectivity
queue length
storage space
```

Possible behavior:

```text
Shelf server stopped unexpectedly
        ↓
restart

IP changed
        ↓
update advertised address

Internet restored
        ↓
resume cloud queue
```

Avoid endless crash loops.

---

# 17. Notification Architecture

PocketEdge must use a provider interface.

```dart
abstract interface class NotificationProvider {
  Future<NotificationResult> send(
    EdgeNotification notification,
  );
}
```

Providers:

```text
LocalWebSocketNotification
LocalDeviceNotification
FcmNotification
SmsNotification
KakaoAlimtalkNotification
EmailNotification
```

Only local providers belong in the initial fully offline path.

Cloud providers require internet.

---

# 18. FCM Integration

FCM should be implemented as an adapter.

Architecture:

```text
PocketEdge Host
    ↓
Notification Queue
    ↓
PocketEdge Cloud / trusted backend
    ↓
FCM HTTP v1
    ↓
Android / iPhone
```

Never embed Firebase service-account private credentials in a distributed client app.

Push payload should contain minimal data.

Prefer:

```json
{
  "type": "order_ready",
  "resourceId": "order_102"
}
```

instead of transmitting sensitive order details directly.

---

# 19. SMS / Kakao Alimtalk

These are cloud notification adapters.

Example:

```text
Local Event
    ↓
Notification Queue
    ↓
Internet unavailable
    ↓
Pending

Internet restored
    ↓
Cloud Adapter
    ↓
SMS / Alimtalk
```

Provider credentials must stay on the trusted backend.

---

# 20. Cloud Adapter

PocketEdge Core must define a generic cloud interface.

```dart
abstract interface class PocketEdgeCloudAdapter {
  Future<bool> ping();

  Future<SyncResult> push(
    List<EdgeSyncEvent> events,
  );

  Future<List<EdgeSyncEvent>> pull(
    EdgeSyncCursor cursor,
  );
}
```

Possible implementations:

```text
SupabasePocketEdgeAdapter
FirebasePocketEdgeAdapter
PocketEdgeCloudAdapter
CustomRestAdapter
```

---

# 21. Supabase Example

Recommended optional architecture:

```text
PocketEdge Local
│
├── SQLite
├── Shelf
├── WebSocket
└── Sync Queue
        ↓
Supabase
├── Postgres
├── Auth
├── Storage
├── Realtime
└── Edge Functions
```

Important:

```text
Local database = operational source
Cloud = sync / backup / remote management
```

A local order must not wait for Supabase before succeeding.

---

# 22. Node Identity

Every PocketEdge host gets a persistent node ID.

Example:

```text
edge_01J8TZ4XZ...
```

Node properties:

```json
{
  "id": "edge_01J8TZ",
  "name": "Front Counter",
  "platform": "windows",
  "version": "0.1.0"
}
```

Future versions may use cryptographic device identity.

---

# 23. Health API

Required endpoint:

```text
GET /_edge/health
```

Example response:

```json
{
  "status": "ok",
  "version": "0.1.0",
  "nodeId": "edge_01J8TZ",
  "uptime": 12543,
  "clients": 8,
  "queuePending": 3
}
```

Detailed diagnostics should require authorization.

---

# 24. Admin Status API

Example:

```text
GET /_edge/status
```

Possible fields:

```json
{
  "server": {
    "running": true,
    "port": 8080
  },
  "network": {
    "address": "192.168.0.15",
    "internet": false
  },
  "storage": {
    "usedBytes": 12345678
  },
  "realtime": {
    "clients": 12
  }
}
```

---

# 25. Example App: Local Room

The first example app should demonstrate PocketEdge without domain complexity.

Features:

```text
QR join
Chat
File upload
Image sharing
Presence
Offline operation
```

Scenario:

```text
Android / Windows host
        ↓
PocketEdge
        ↓
same Wi-Fi
        ↓
QR scan
        ↓
browser
        ↓
chat + file sharing
```

Success criteria:

> Internet can be disabled and the application still works.

---

# 26. Example App: PocketEdge Table

Second reference application.

Features:

```text
menu
table QR
cart
order
kitchen view
staff call
admin menu editor
```

Example URLs:

```text
/t/1
/t/2
/t/3

/kitchen
/staff
/admin
```

PocketEdge itself must remain unaware of what an "order" or "table" means.

---

# 27. Kiosk Support

PocketEdge can power kiosk applications.

Architecture:

```text
PocketEdge Host
        │
  ┌─────┼─────┐
  │     │     │
Kiosk TableQR Staff
```

Possible host:

```text
Windows
macOS
Android
Linux
```

Possible clients:

```text
Flutter native
browser
Flutter Web
```

---

# 28. Future Media Layer

Do not include video broadcasting in MVP.

Future module:

```text
pocketedge_media
```

Possible technologies:

```text
WebRTC
HLS
local relay
native multicast experiments
```

Shelf should handle:

```text
authentication
signaling
session management
metadata
```

Media transport should be separate.

---

# 29. Future Device Gateway

Future module:

```text
pocketedge_devices
```

Possible adapters:

```text
NFC
BLE
USB
Serial
Barcode
Printer
Scale
Camera
```

Example conceptual API:

```dart
final scale = edge.devices.get('scale_1');

final weight = await scale.read();
```

PocketEdge must not implement regulated payment-card processing itself.

Payment integrations should use certified payment-provider SDKs.

---

# 30. Future Server Handoff

Later milestone:

```text
Host A
   ↓
state replication
   ↓
Host B

A unavailable
   ↓
B becomes leader
```

Required research:

```text
leader election
state replication
conflict resolution
node authentication
session migration
service discovery
```

Not MVP.

---

# 31. Future DelaySync

Store-and-forward synchronization:

```text
Node A
  ↓
Node B
  ↓
Node C
  ↓
Internet
  ↓
Cloud
```

Use cases:

```text
disaster response
field work
remote sites
events
ships
construction sites
```

Not MVP.

---

# 32. Logging

PocketEdge must provide structured logs.

Levels:

```text
trace
debug
info
warning
error
critical
```

Example:

```json
{
  "time": "2026-09-25T04:00:00Z",
  "level": "info",
  "module": "server",
  "event": "client_connected",
  "clientId": "device_b21"
}
```

Do not log secrets or raw credentials.

---

# 33. Privacy

Default rules:

- collect minimum data
- no telemetry by default
- no hidden cloud calls
- local-first by default
- explicit opt-in for analytics
- avoid logging personal information
- allow local data deletion
- document what leaves the device

The open-source package must work without a PocketEdge account.

---

# 34. Error Handling

Use typed errors.

Example:

```dart
sealed class PocketEdgeException implements Exception {}

class PortUnavailableException extends PocketEdgeException {}

class PairingRejectedException extends PocketEdgeException {}

class StorageException extends PocketEdgeException {}
```

Do not expose raw platform exceptions directly as the primary API.

---

# 35. Configuration

Example:

```dart
final edge = PocketEdge(
  config: PocketEdgeConfig(
    port: 8080,
    bindAddress: '0.0.0.0',

    server: const EdgeServerConfig(
      staticFiles: true,
    ),

    realtime: const EdgeRealtimeConfig(
      enabled: true,
    ),

    storage: const EdgeStorageConfig(
      enabled: true,
    ),

    security: const EdgeSecurityConfig(
      pairingRequired: true,
    ),
  ),
);
```

Defaults should be safe.

---

# 36. Suggested pubspec

Initial dependencies should remain minimal.

Conceptual example:

```yaml
dependencies:
  flutter:
    sdk: flutter

  shelf:
  shelf_router:
  shelf_web_socket:
  shelf_static:

  path:
  crypto:
  meta:

  drift:
  sqlite3_flutter_libs:

dev_dependencies:
  flutter_test:
    sdk: flutter

  test:
  lints:
```

Always verify current package versions before publishing.

Do not add dependencies without a clear need.

---

# 37. API Stability

Before v1.0:

```text
0.x
```

Breaking changes are allowed but must be documented.

After:

```text
1.0.0
```

follow semantic versioning.

Public API changes require:

```text
CHANGELOG
migration guide
deprecation period when practical
```

---

# 38. Testing Strategy

Required:

## Unit tests

```text
routing
queue
auth
serialization
storage
```

## Integration tests

```text
start server
connect client
REST request
WebSocket
restart
offline queue
```

## Platform tests

At minimum:

```text
Android
Windows
macOS
```

before stable release.

---

# 39. Security Testing

Before v1.0 test:

```text
unauthorized access
expired tokens
reused pairing token
replay request
large payload
path traversal
malformed JSON
WebSocket flooding
file upload validation
rate limiting
```

Create:

```text
SECURITY.md
```

with vulnerability reporting instructions.

---

# 40. File Upload Security

Default protections:

```text
maximum file size
allowed MIME types
randomized storage names
path normalization
no executable interpretation
metadata sanitization where appropriate
```

Never trust user-provided filenames.

---

# 41. Rate Limiting

Provide middleware support.

Example:

```dart
edge.use(
  EdgeRateLimit(
    requests: 60,
    window: Duration(minutes: 1),
  ),
);
```

Pairing and authentication endpoints should be more restrictive.

---

# 42. CORS

Local browser applications may require CORS handling.

Default:

```text
deny unrestricted wildcard behavior for privileged APIs
```

Allow applications to configure trusted origins.

---

# 43. Developer Experience

Target experience:

```dart
import 'package:pocketedge/pocketedge.dart';

Future<void> main() async {
  final edge = PocketEdge();

  edge.get('/hello', (_) {
    return EdgeResponse.json({
      'message': 'Hello from PocketEdge',
    });
  });

  await edge.start();

  print(edge.url);
}
```

PocketEdge should hide unnecessary Shelf boilerplate while still allowing access to lower-level primitives when required.

---

# 44. Middleware

Support:

```text
logging
authentication
authorization
rate limiting
request ID
CORS
compression
error handling
custom middleware
```

Example:

```dart
edge.use(
  EdgeMiddleware.auth(),
);
```

Advanced developers should be able to provide native Shelf middleware.

---

# 45. Extension System

Future extension API:

```dart
abstract class PocketEdgePlugin {
  String get id;

  Future<void> onRegister(
    PocketEdge edge,
  );

  Future<void> onStart();

  Future<void> onStop();
}
```

Example plugins:

```text
PocketEdgeFcmPlugin
PocketEdgeSupabasePlugin
PocketEdgePrinterPlugin
PocketEdgeWebRtcPlugin
PocketEdgeBlePlugin
```

---

# 46. Open-source vs Commercial Strategy

Recommended model:

```text
PocketEdge Core
Apache-2.0
FREE

        ↓

Developers / Companies
build local-first apps

        ↓ optional

PocketEdge Cloud
Commercial SaaS
```

PocketEdge Cloud may provide:

```text
remote management
multi-site management
cloud backup
remote menu/config updates
analytics
alerts
FCM
SMS
Kakao Alimtalk
central device registry
remote diagnostics
audit logs
enterprise APIs
```

---

# 47. Business Model

Core principle:

> Local operation is free. Connectivity and centralized management are paid.

Potential plans:

```text
Community
Free
- PocketEdge Core
- local hosting
- community support

Cloud
Paid per site
- cloud sync
- backup
- remote management
- notifications

Business
Paid
- multi-store
- analytics
- team permissions
- API

Enterprise
Custom
- SSO
- white label
- SLA
- private cloud
- custom integration
```

Do not cripple the open-source version artificially.

Commercial value should come from operational convenience.

---

# 48. Example Product Ecosystem

```text
PocketEdge
   │
   ├── PocketEdge Table
   │     QR ordering
   │
   ├── PocketEdge Kiosk
   │
   ├── PocketEdge POS
   │
   ├── PocketEdge Event
   │
   ├── PocketEdge Live
   │
   ├── PocketEdge Field
   │
   └── PocketEdge IoT
```

All products reuse the same core.

---

# 49. Development Roadmap

## Phase 1 — Core MVP

```text
PocketEdge lifecycle
Shelf server
Router
WebSocket
Static files
SQLite
QR join
status API
basic pairing
```

Goal:

```text
Internet OFF
        ↓
Host running
        ↓
Browser joins
        ↓
chat/file example works
```

---

## Phase 2 — Runtime

```text
Android foreground service
Windows tray
macOS menu bar/background
watchdog
network change handling
```

---

## Phase 3 — Security

```text
session tokens
roles
permissions
rate limiting
replay protection
secure storage
audit events
```

---

## Phase 4 — Sync

```text
offline queue
generic cloud adapter
Supabase example
conflict rules
```

---

## Phase 5 — Notifications

```text
notification abstraction
local notifications
FCM adapter
SMS adapter
Kakao Alimtalk adapter
```

---

## Phase 6 — Discovery

```text
mDNS
Android NSD
BLE discovery
optional local hotspot helpers
```

---

## Phase 7 — Advanced Edge

```text
node-to-node sync
server handoff
DelaySync
distributed storage experiments
```

---

## Phase 8 — Media / Devices

```text
WebRTC
camera
printer
barcode
USB
BLE devices
NFC
IoT gateway
```

---

# 50. MVP Acceptance Criteria

PocketEdge v0.1 is ready when:

- [ ] Android host can start PocketEdge
- [ ] Windows host can start PocketEdge
- [ ] macOS host can start PocketEdge
- [ ] HTTP endpoint works
- [ ] WebSocket works
- [ ] static web app can be served
- [ ] another phone can join over the same Wi-Fi
- [ ] internet can be disabled
- [ ] local application still works
- [ ] QR contains local join information
- [ ] SQLite storage persists after restart
- [ ] pairing token exists
- [ ] unauthorized privileged API access is blocked
- [ ] Android can continue host operation when UI is backgrounded using supported foreground-service behavior
- [ ] server status is visible
- [ ] example app demonstrates chat and file/image sharing
- [ ] Apache-2.0 LICENSE exists
- [ ] README contains setup instructions
- [ ] SECURITY.md exists
- [ ] tests pass

---

# 51. Non-goals

PocketEdge Core is NOT:

```text
a payment processor
a payment card reader implementation
a cloud-only backend
a Firebase replacement
a Supabase replacement
a router firmware
a VPN
a general-purpose operating system
a guaranteed iOS background server
```

PocketEdge integrates with other systems through adapters.

---

# 52. Initial README Positioning

Suggested headline:

> **PocketEdge**
>
> Build local-first Flutter apps that keep working when the cloud disappears.

Suggested short description:

> PocketEdge turns Android, Windows, macOS and Linux devices into local application servers for Flutter apps. Serve APIs, WebSockets and local web interfaces over Wi-Fi, persist data locally, and sync to the cloud only when needed.

---

# 53. Repository Description

```text
Local-first edge server framework for Flutter.
Build offline-capable LAN apps with HTTP, WebSocket, local storage, pairing and optional cloud sync.
```

---

# 54. Initial Keywords

```text
flutter
dart
local-first
offline-first
edge
edge-server
shelf
websocket
local-network
lan
kiosk
pos
qr-order
iot
offline
self-hosted
```

---

# 55. Coding Rules

1. Keep PocketEdge domain-neutral.
2. No hidden cloud dependency.
3. No telemetry by default.
4. Keep public API small.
5. Prefer interfaces around external services.
6. Platform-specific code stays behind platform adapters.
7. Do not put service credentials in distributed apps.
8. Secure defaults.
9. Offline operation must remain first-class.
10. Every major feature needs an example.
11. Avoid premature package splitting.
12. Avoid unnecessary dependencies.
13. All public APIs require documentation.
14. Keep Android lifecycle separate from Flutter UI lifecycle.
15. Never claim security properties that have not been implemented and tested.

---

# 56. Suggested First Implementation Order

Codex/agent should implement in this order:

```text
STEP 1
Create Flutter package structure.

STEP 2
Implement PocketEdge.start() / stop().

STEP 3
Wrap Shelf and shelf_router.

STEP 4
Add /_edge/health.

STEP 5
Add WebSocket channels.

STEP 6
Add static file serving.

STEP 7
Add SQLite storage abstraction.

STEP 8
Build Local Room example.

STEP 9
Add QR join payload.

STEP 10
Add temporary pairing token.

STEP 11
Implement Android foreground host.

STEP 12
Implement Windows/macOS host lifecycle.

STEP 13
Add offline queue.

STEP 14
Add cloud adapter interface.

STEP 15
Write tests and documentation.
```

Do not start the next step until the current step compiles and tests pass.

---

# 57. Definition of Success

PocketEdge succeeds if another Flutter developer can write:

```dart
final edge = PocketEdge();

await edge.start();

edge.get('/api/data', (_) {
  return EdgeResponse.json({
    'hello': 'world',
  });
});
```

and then open the local server from another phone or browser on the same network without needing:

```text
AWS
Firebase
Supabase
Vercel
Cloudflare
or any public internet connection
```

Cloud services remain optional enhancements.

---

# 58. Long-term Vision

PocketEdge should become:

> A reusable local edge runtime for Flutter applications.

The long-term ecosystem may allow developers to build:

```text
offline kiosks
table ordering systems
field systems
local collaboration tools
disaster systems
event systems
local media systems
IoT gateways
temporary networks
private local applications
```

using one common open-source foundation.

---

## License Notice

PocketEdge Core is intended to be released under the **Apache License, Version 2.0**.

The repository should include the complete official Apache-2.0 license text in a top-level `LICENSE` file.

Project documentation should identify the license using:

```text
SPDX-License-Identifier: Apache-2.0
```

Commercial cloud services, hosted services, enterprise plugins, and separately distributed proprietary applications may use separate commercial terms, provided they comply with the Apache-2.0 obligations applicable to PocketEdge-derived or bundled open-source components.
