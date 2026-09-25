// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../discovery/join_info.dart';
import '../discovery/network_monitor.dart';
import '../realtime/channel.dart';
import '../security/pairing.dart';
import '../security/authorization.dart';
import '../security/rate_limit.dart';
import '../security/audit.dart';
import '../security/sqlite_sessions_stub.dart'
    if (dart.library.io) '../security/sqlite_sessions.dart';
import '../storage/edge_storage.dart';
import '../storage/file_store.dart';
import '../sync/offline_queue.dart';
import 'types.dart';
import 'logging.dart';

/// A local HTTP and WebSocket application host for Flutter apps.
class PocketEdge {
  PocketEdge({
    PocketEdgeConfig? config,
    EdgeStorage? storage,
    this.fileStore,
    this.sessionStore,
    EdgeLogger? logger,
  })  : config = config ?? const PocketEdgeConfig(),
        storage = storage ?? MemoryEdgeStorage(),
        nodeId = _nodeId(),
        logger = logger ?? EdgeLogger();
  final PocketEdgeConfig config;
  final EdgeStorage storage;
  final EdgeFileStore? fileStore;
  final SqliteSessionManager? sessionStore;
  final EdgeLogger logger;
  final String nodeId;
  final OfflineQueue queue = OfflineQueue();
  final PairingManager pairing = PairingManager();
  final SessionManager sessions = SessionManager();
  final EdgeAuthorization authorization = EdgeAuthorization();
  final EdgeRateLimiter rateLimiter = EdgeRateLimiter();
  final EdgeAuditLog auditLog = EdgeAuditLog();
  final EdgeReplayGuard replayGuard = EdgeReplayGuard();
  late final EdgeNetworkMonitor networkMonitor = EdgeNetworkMonitor(
    onChanged: (address) => _advertisedHost = address,
  );
  final Router _router = Router();
  final List<Middleware> _middlewares = [];
  final Set<WebSocketChannel> _clients = <WebSocketChannel>{};
  final StreamController<EdgeEvent> _events =
      StreamController<EdgeEvent>.broadcast();
  Handler? _staticHandler;
  String? _advertisedHost;
  String? _pairToken;
  HttpServer? _server;
  DateTime? _startedAt;
  EdgeStatus get status => EdgeStatus(
        running: _server != null,
        port: _server?.port ?? config.port,
        localAddress: _usableAddress(_server?.address.address),
        connectedClients: _clients.length,
        uptime: _startedAt == null
            ? Duration.zero
            : DateTime.now().difference(_startedAt!),
        queuePending: queue.pending.length,
        scheme: config.securityContext == null ? 'http' : 'https',
      );
  String get url => status.url;
  EdgeJoinInfo get joinInfo {
    final publicUrl = config.publicBaseUrl;
    final advertisedScheme = publicUrl?.scheme ?? status.scheme;
    final advertisedHost = publicUrl?.host ??
        _advertisedHost ??
        status.localAddress ??
        '127.0.0.1';
    final advertisedPort = publicUrl == null || publicUrl.hasPort
        ? publicUrl?.port ?? status.port
        : advertisedScheme == 'https'
            ? 443
            : 80;

    return EdgeJoinInfo(
      host: advertisedHost,
      port: advertisedPort,
      nodeId: nodeId,
      pairToken: _pairToken,
      scheme: advertisedScheme,
    );
  }

  /// Registers a public GET route.
  void get(String path, EdgeHandler handler) => _router.get(path, handler);

  /// Registers a public POST route.
  void post(String path, EdgeHandler handler) => _router.post(path, handler);

  /// Stream of events broadcast by realtime channels.
  Stream<EdgeEvent> get events => _events.stream;

  /// Returns a named realtime channel.
  EdgeChannel channel(String name) => EdgeChannel(this, name);

  /// Adds middleware to the host request pipeline.
  void use(Middleware middleware) => _middlewares.add(middleware);

  /// Registers a session-protected GET route.
  void secureGet(String path, EdgeHandler handler, {String? permission}) =>
      _router.get(
        path,
        (request) => _authenticated(request, handler, permission: permission),
      );
  void securePost(
    String path,
    EdgeHandler handler, {
    String? permission,
    bool replayProtected = false,
  }) =>
      _router.post(
        path,
        (request) => _authenticated(
          request,
          handler,
          permission: permission,
          replayProtected: replayProtected,
        ),
      );

  /// Registers a session-protected DELETE route.
  void secureDelete(String path, EdgeHandler handler, {String? permission}) =>
      _router.delete(
        path,
        (request) => _authenticated(request, handler, permission: permission),
      );

  /// Issues a short-lived, single-use pairing token for [role].
  String issuePairingToken({String role = 'guest'}) {
    _pairToken = pairing.issue(role: role).value;
    return _pairToken!;
  }

  /// Refreshes the advertised LAN address used in join information.
  Future<String?> refreshNetworkAddress() => networkMonitor.checkNow();

  /// Starts periodic LAN address monitoring.
  void startNetworkMonitoring() => networkMonitor.start();

  /// Stops periodic LAN address monitoring.
  void stopNetworkMonitoring() => networkMonitor.stop();

  /// Serves an application's local Flutter Web build after API routes.
  void serveStatic(
    Directory directory, {
    String defaultDocument = 'index.html',
  }) {
    _staticHandler = createStaticHandler(
      directory.path,
      defaultDocument: defaultDocument,
      serveFilesOutsidePath: false,
    );
  }

  /// Starts the local HTTP/WebSocket host.
  Future<void> start() async {
    if (_server != null) return;
    _router.get(
      '/_edge/health',
      (_) async => EdgeResponse.json({
        'status': 'ok',
        'version': '0.1.0',
        'nodeId': nodeId,
        'uptime': status.uptime.inSeconds,
        'clients': _clients.length,
        'queuePending': queue.pending.length,
      }),
    );
    secureGet('/_edge/status', _status, permission: 'diagnostics.read');
    _router.get(
      '/_edge/join',
      (_) async => EdgeResponse.json(joinInfo.toJson()),
    );
    _router.post('/_edge/pair', _pair);
    securePost('/_edge/files', _uploadFile, permission: 'files.write');
    secureGet('/_edge/files/<id>', _downloadFile, permission: 'files.read');
    secureDelete('/_edge/files/<id>', _deleteFile, permission: 'files.write');
    if (config.realtime) _router.get('/ws', _webSocket);
    try {
      _server = await shelf_io.serve(
        _handler,
        config.bindAddress,
        config.port,
        securityContext: config.securityContext,
      );
      _startedAt = DateTime.now();
      logger.info('server', 'started', {
        'port': _server!.port,
        'nodeId': nodeId,
      });
    } on SocketException catch (error) {
      throw PortUnavailableException(error.message);
    }
  }

  /// Stops the host, connected WebSocket clients, and address monitor.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    _startedAt = null;
    networkMonitor.stop();
    for (final client in _clients.toList()) {
      await client.sink.close();
    }
    _clients.clear();
    await server?.close(force: true);
    logger.info('server', 'stopped', {'nodeId': nodeId});
  }

  /// Broadcasts an event to listeners and connected WebSocket clients.
  Future<void> broadcast({
    required String channel,
    required String event,
    required Map<String, dynamic> data,
  }) async {
    _events.add(
      EdgeEvent(
        id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
        channel: channel,
        event: event,
        timestamp: DateTime.now().toUtc(),
        data: data,
      ),
    );
    final envelope = jsonEncode({
      'id': 'evt_${DateTime.now().microsecondsSinceEpoch}',
      'channel': channel,
      'event': event,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
    for (final client in _clients.toList()) {
      client.sink.add(envelope);
    }
  }

  Future<Response> _webSocket(Request request) async {
    if (config.realtimeAuthRequired) {
      final header = request.headers['authorization'];
      final token = header != null && header.startsWith('Bearer ')
          ? header.substring(7).trim()
          : null;
      if (token == null || await _resolveSession(token) == null) {
        auditLog.record('websocket_authentication_rejected');
        return Response.unauthorized('Authentication required.');
      }
    }
    return webSocketHandler((WebSocketChannel channel, String? protocol) {
      _clients.add(channel);
      channel.stream.listen((message) {
        if (message is! String) return;
        try {
          final value = jsonDecode(message) as Map<String, dynamic>;
          final channelName = value['channel'] as String?;
          final event = value['event'] as String?;
          final data = value['data'];
          if (channelName != null &&
              event != null &&
              data is Map<String, dynamic>) {
            broadcast(channel: channelName, event: event, data: data);
          }
        } on FormatException {
          // Ignore malformed client frames.
        }
      }, onDone: () => _clients.remove(channel));
    })(request);
  }

  Future<Response> _handler(Request request) async {
    if (config.pairingRequired && _requiresGlobalAuth(request)) {
      final header = request.headers['authorization'];
      final token = header != null && header.startsWith('Bearer ')
          ? header.substring(7).trim()
          : null;
      if (token == null || await _resolveSession(token) == null) {
        auditLog.record(
          'global_authentication_rejected',
          data: {'path': request.requestedUri.path},
        );
        return EdgeResponse.json({
          'error': 'Pairing authentication required',
        }, status: 401);
      }
    }
    final baseHandler = _staticHandler == null
        ? _router.call
        : Cascade().add(_router.call).add(_staticHandler!).handler;
    var pipeline = const Pipeline().addMiddleware(logRequests());
    for (final middleware in _middlewares) {
      pipeline = pipeline.addMiddleware(middleware);
    }
    return await pipeline.addHandler(baseHandler)(request);
  }

  bool _requiresGlobalAuth(Request request) {
    final path = request.requestedUri.path;
    if (path == '/_edge/health' ||
        path == '/_edge/join' ||
        path == '/_edge/pair') {
      return false;
    }
    return true;
  }

  Future<Response> _pair(Request request) async {
    if (!rateLimiter.allow(
      'pair:${request.headers['x-device-id'] ?? 'unknown'}',
    )) {
      return EdgeResponse.json({
        'error': 'Too many pairing attempts',
      }, status: 429);
    }
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final token = body['pairToken'] as String?;
      final deviceId = body['deviceId'] as String?;
      if (token == null || deviceId == null || deviceId.trim().isEmpty) {
        return EdgeResponse.json({
          'error': 'pairToken and deviceId are required',
        }, status: 400);
      }
      final pairingToken = pairing.requireToken(token);
      if (token == _pairToken) _pairToken = null;
      final session = sessionStore == null
          ? sessions.issue(deviceId: deviceId, role: pairingToken.role)
          : await sessionStore!.issue(
              deviceId: deviceId,
              role: pairingToken.role,
            );
      auditLog.record(
        'pairing_succeeded',
        subject: deviceId,
        data: {'role': session.role},
      );
      return EdgeResponse.json({
        'sessionToken': session.token,
        ...session.toJson(),
      });
    } on FormatException {
      return EdgeResponse.json({
        'error': 'Request body must be valid JSON',
      }, status: 400);
    } on PairingRejectedException catch (error) {
      auditLog.record('pairing_rejected');
      return EdgeResponse.json({'error': error.message}, status: 401);
    }
  }

  Future<Response> _status(Request request) async => EdgeResponse.json({
        'server': {
          'running': status.running,
          'port': status.port,
          'uptime': status.uptime.inSeconds,
        },
        'network': {
          'address': _advertisedHost ?? status.localAddress,
          'internet': false,
        },
        'storage': {'configured': storage is! MemoryEdgeStorage},
        'realtime': {'clients': status.connectedClients},
        'queue': {'pending': queue.pending.length},
      });

  Future<Response> _uploadFile(Request request) async {
    final store = fileStore;
    if (store == null) {
      return EdgeResponse.json({
        'error': 'File storage is not configured',
      }, status: 503);
    }
    try {
      final saved = await store.save(
        request.read(),
        contentType: request.headers['content-type']?.split(';').first,
      );
      return EdgeResponse.json({
        'id': saved.id,
        'bytes': saved.bytes,
        'contentType': saved.contentType,
      }, status: 201);
    } on FileUploadException catch (error) {
      return EdgeResponse.json({'error': error.message}, status: 413);
    }
  }

  Future<Response> _downloadFile(Request request) async {
    final store = fileStore;
    if (store == null) {
      return EdgeResponse.json({
        'error': 'File storage is not configured',
      }, status: 503);
    }
    try {
      final file = await store.open(request.params['id']!);
      final contentType = await store.contentType(request.params['id']!);
      return Response.ok(
        file.openRead(),
        headers: {'content-type': contentType ?? 'application/octet-stream'},
      );
    } on FileUploadException catch (error) {
      return EdgeResponse.json({'error': error.message}, status: 404);
    }
  }

  Future<Response> _deleteFile(Request request) async {
    final store = fileStore;
    if (store == null) {
      return EdgeResponse.json({
        'error': 'File storage is not configured',
      }, status: 503);
    }
    try {
      await store.delete(request.params['id']!);
      return EdgeResponse.ok();
    } on FileUploadException catch (error) {
      return EdgeResponse.json({'error': error.message}, status: 404);
    }
  }

  Future<Response> _authenticated(
    Request request,
    EdgeHandler handler, {
    String? permission,
    bool replayProtected = false,
  }) async {
    final rateKey = request.headers['x-device-id'] ??
        request.headers['authorization'] ??
        'unknown';
    if (!rateLimiter.allow(rateKey)) {
      return EdgeResponse.json({'error': 'Too many requests'}, status: 429);
    }
    final header = request.headers['authorization'];
    final token = header != null && header.startsWith('Bearer ')
        ? header.substring(7).trim()
        : null;
    final session = token == null ? null : await _resolveSession(token);
    if (session == null) {
      auditLog.record(
        'authentication_rejected',
        data: {'path': request.requestedUri.path},
      );
      return EdgeResponse.json({
        'error': 'Authentication required',
      }, status: 401);
    }
    if (permission != null && !authorization.allows(session, permission)) {
      auditLog.record(
        'permission_denied',
        subject: session.deviceId,
        data: {'permission': permission, 'path': request.requestedUri.path},
      );
      return EdgeResponse.json({'error': 'Permission denied'}, status: 403);
    }
    if (replayProtected) {
      final requestId = request.headers['x-request-id'];
      final nonce = request.headers['x-nonce'];
      final timestamp = int.tryParse(request.headers['x-timestamp'] ?? '');
      final accepted = requestId != null &&
          nonce != null &&
          timestamp != null &&
          replayGuard.accept(
            requestId: requestId,
            nonce: nonce,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              timestamp * 1000,
              isUtc: true,
            ),
          );
      if (!accepted) {
        auditLog.record(
          'replay_rejected',
          subject: session.deviceId,
          data: {'path': request.requestedUri.path},
        );
        return EdgeResponse.json({
          'error': 'Replay protection rejected the request',
        }, status: 409);
      }
    }
    return handler(request.change(context: {'session': session}));
  }

  Future<EdgeSession?> _resolveSession(String token) async {
    final persistent = sessionStore;
    if (persistent == null) return sessions.resolve(token);
    return await persistent.resolve(token);
  }

  static String _nodeId() =>
      'edge_${Random.secure().nextInt(0x7fffffff).toRadixString(16)}';

  static String? _usableAddress(String? address) =>
      address == null || address == '0.0.0.0' || address == '::'
          ? null
          : address;
}
