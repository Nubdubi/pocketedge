# Changelog

## 0.1.6

- Added Cloudflare Tunnel support through `PocketEdgeConfig.publicBaseUrl`.
- Added tunnel-aware WebSocket join URLs and a runnable configuration example.

## 0.1.5

- Added the root example guide and finalized pub.dev package metadata.
- Ensured the published example and changelog are discoverable by package analysis.

## 0.1.4

- Published a complete runnable example layout for package consumers.
- Corrected package metadata and changelog formatting for pub.dev analysis.

## 0.1.3

- Added API documentation comments for the core public surface.
- Improved generated API documentation coverage for pub.dev scoring.
- Updated `sqlite3_flutter_libs` to `0.6.0+eol` to remove the stale CSQLite Swift Package revision.
- Added a runnable Dart example for pub.dev package discovery.
- Updated `sqlite3` to the latest stable 3.x line.

## 0.1.2

- Include storage source files in the published package.
- Improve pub.dev documentation and AI usage guidance.

## 0.1.1

- Added conditional web stubs so the Flutter Web release build works without SQLite FFI.

## 0.1.0

- Added the initial PocketEdge public API.
- Added local Shelf HTTP server lifecycle and health/status endpoints.
- Added WebSocket broadcast envelopes.
- Added storage, pairing, and offline queue interfaces.
- Added SQLite storage and versioned local join information endpoint.
- Added QR join rendering to the Local Room example.
- Added safe static web directory serving.
- Added pairing endpoint, expiring sessions, and authenticated route helpers.
- Added role-based permissions and in-memory rate limiting.
- Added Android foreground-service bridge and persistent host notification for the example app.
- Added watchdog auto-restart with bounded crash-loop protection.
- Added desktop persistent-host channel with macOS menu-bar lifecycle and Windows close-to-hide behavior.
- Added cloud adapter interfaces and offline queue synchronization coordinator.
- Added notification provider abstraction and local WebSocket notification provider.
- Added connectivity monitor and scheduled sync recovery helpers.
- Added LAN IPv4 address monitoring and automatic join payload refresh.
- Added replay protection for sensitive routes and bounded audit logging.
- Added secure file store with MIME allowlist, size limit, randomized names, and path isolation.
- Connected the file store to authenticated `POST /_edge/files` uploads.
- Added authenticated file download and deletion endpoints.
- Added browser Local Room client and bidirectional WebSocket chat broadcast.
- Connected QR join payload pairing to the browser client and local file upload UI.
- Added configurable CORS and request ID middleware to the server pipeline.
- Added channel-based realtime API with server-side event listeners.
- Added optional Bearer authentication for WebSocket handshakes.
- Added generic REST cloud adapter for ping, push, and pull sync operations.
- Added SQLite-backed offline queue with restart recovery.
- Added SQLite sync coordinator for durable queue flushes.
- Connected `pairingRequired` to a global application-route authentication guard.
- Added optional SQLite session manager for restart recovery.
- Added generic REST notification provider for trusted backend adapters.
- Added structured logger and server lifecycle logging hooks.
- Secured detailed status diagnostics with `diagnostics.read` permission.
- Added reusable route rate-limit middleware with custom bucket keys.
- Added request body size limit middleware.
- Added JSON error middleware with internal structured logging.
- Added optional HTTPS serving through an injected `SecurityContext`.
- Integrated the SQLite session manager into pairing and all authentication paths.
- Added Local Room Flutter example.
