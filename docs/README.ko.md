# PocketEdge 사용 안내

PocketEdge는 인터넷이나 클라우드가 끊겨도 같은 LAN에서 동작하는 Flutter용 로컬 서버 프레임워크입니다. HTTP API, WebSocket, QR 연결, SQLite 저장소, 파일 공유, 오프라인 큐와 선택적 클라우드 동기화를 제공합니다.

## 시작하기

```bash
flutter pub get
flutter analyze
flutter test
```

기본 호스트:

```dart
import 'package:pocketedge/pocketedge.dart';

final edge = PocketEdge();
edge.get('/api/hello', (_) async =>
    EdgeResponse.json({'message': '안녕하세요'}));
await edge.start();
print(edge.url);
```

호스트를 종료할 때는 `await edge.stop()`을 호출합니다. QR 연결 정보는 `edge.joinInfo` 또는 `GET /_edge/join`으로 가져옵니다.

## 보안 사용법

권한이 필요한 API는 pairing token으로 세션을 만든 뒤 사용합니다.

```dart
final token = edge.issuePairingToken(role: 'staff');
```

클라이언트는 `POST /_edge/pair`에 `pairToken`과 `deviceId`를 보내고, 응답의 세션 토큰을 `Authorization: Bearer <token>`으로 전송합니다. 운영 환경에서는 `pairingRequired: true`, 명시적 CORS origin, HTTPS, `realtimeAuthRequired: true`를 검토하십시오.

비밀값과 인증서는 `.env`, `*.pem`, `*.key`, `*.p12`, Android keystore 등에 저장하며 Git에 커밋하지 않습니다. 이미 커밋된 비밀값은 `.gitignore`만으로 삭제되지 않으므로 즉시 폐기하고 교체해야 합니다.

## 파일 공유

`EdgeFileStore`는 파일 크기, MIME allowlist, PNG/JPEG/WebP/PDF 시그니처를 검사합니다. 업로드 파일은 악성코드 검사와 썸네일 검사를 별도로 적용하십시오.

## 배포

```bash
flutter build apk --release
flutter build appbundle --release
flutter build macos --release
flutter build web --release --no-wasm-dry-run
```

Android Play Store는 release keystore와 `.aab`가 필요하고, macOS 배포는 Developer ID 서명과 공증이 필요합니다. Web은 `build/web` 전체를 정적 호스팅에 업로드합니다.

## Web 제한사항

SQLite는 `dart:ffi` 기반이므로 Web에서 사용할 수 없습니다. Web에서는 기본 메모리 저장소와 메모리 큐를 사용하고, 영속성이 필요하면 서버 또는 클라우드 adapter를 사용하십시오.
