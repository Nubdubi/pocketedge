# PocketEdge 使用说明

PocketEdge 是一个面向 Flutter 的本地优先边缘服务器框架。即使互联网或云服务中断，只要设备处于同一局域网，仍可使用 HTTP API、WebSocket、二维码配对、SQLite、本地文件共享、离线队列和可选的云同步。

## 快速开始

```bash
flutter pub get
flutter analyze
flutter test
```

基本主机示例：

```dart
import 'package:pocketedge/pocketedge.dart';

final edge = PocketEdge();
edge.get('/api/hello', (_) async =>
    EdgeResponse.json({'message': '你好，PocketEdge'}));
await edge.start();
print(edge.url);
```

结束主机时调用 `await edge.stop()`。二维码连接信息可通过 `edge.joinInfo` 或 `GET /_edge/join` 获取。

## 安全使用

需要权限的 API 应先通过 pairing token 创建会话：

```dart
final token = edge.issuePairingToken(role: 'staff');
```

客户端向 `POST /_edge/pair` 发送 `pairToken` 和 `deviceId`，然后使用响应中的会话令牌：`Authorization: Bearer <token>`。生产环境建议启用 `pairingRequired: true`、明确的 CORS origin、HTTPS 和 `realtimeAuthRequired: true`。

密钥和证书（如 `.env`、`*.pem`、`*.key`、`*.p12`、Android keystore）不得提交到 Git。`.gitignore` 只能阻止未来跟踪，不能移除已经提交的秘密；如果发生泄漏，应立即吊销并更换。

## 文件共享

`EdgeFileStore` 会检查文件大小、MIME allowlist，以及 PNG/JPEG/WebP/PDF 文件签名。正式环境仍应额外进行恶意软件扫描和缩略图检查。

## 构建与发布

```bash
flutter build apk --release
flutter build appbundle --release
flutter build macos --release
flutter build web --release --no-wasm-dry-run
```

Google Play 发布需要 release keystore 和 `.aab`；macOS 发布需要 Developer ID 签名和公证；Web 发布时上传整个 `build/web` 目录到静态托管服务。

## Web 限制

SQLite 依赖 `dart:ffi`，不能在 Web 中使用。Web 应使用内存存储和内存队列；如需持久化，请使用服务器端存储或云端 adapter。
